import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UUIDs of the firmware's session-sync characteristics.
/// Must match `src/bluetooth_manager.cpp` exactly.
const String _kSessionDataUuid = '0000aa01-0000-1000-8000-00805f9b34fb';
const String _kSessionAckUuid = '0000aa02-0000-1000-8000-00805f9b34fb';

/// Progress snapshot emitted by [BleSessionSync.progress] for UI feedback.
class SyncProgress {
  const SyncProgress({
    required this.sent,
    required this.total,
    required this.complete,
    this.error,
  });

  final int sent;
  final int total;
  final bool complete;
  final Object? error;
}

/// Pulls unsent posture/therapy sessions off the Aligneye wearable over BLE,
/// uploads each one to Supabase, and ACKs the device only once the insert
/// succeeds so failed rows retry on the next connection.
///
/// Packet format — 20 bytes, must match firmware `_sendNextSession()`:
///   byte 0:      session index (position in unsent list)
///   byte 1:      type (1=posture, 2=therapy)
///   bytes 2-5:   start_ts uint32 LE
///   bytes 6-7:   duration_sec uint16 LE
///   bytes 8-9:   wrong_count uint16 LE
///   bytes 10-11: wrong_dur_sec uint16 LE
///   byte 12:     therapy_pattern uint8
///   byte 13:     ts_synced uint8
///   bytes 14-19: reserved zeros
class BleSessionSync {
  BleSessionSync(this._device, {SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final BluetoothDevice _device;
  final SupabaseClient _supabase;

  final _progressController = StreamController<SyncProgress>.broadcast();

  BluetoothCharacteristic? _dataChar;
  BluetoothCharacteristic? _ackChar;
  StreamSubscription<List<int>>? _notifySub;

  /// Total sessions observed this run. Best-effort — the firmware doesn't
  /// send a total up-front, so we grow this as packets arrive and mark the
  /// stream `complete` when the notify stream goes idle for [_idleTimeout].
  int _sentCount = 0;
  int _observedMax = 0;
  Timer? _idleTimer;
  bool _complete = false;
  bool _running = false;

  static const Duration _idleTimeout = Duration(seconds: 4);

  Stream<SyncProgress> get progress => _progressController.stream;

  /// Discover the sync characteristics, subscribe to notifications, and
  /// begin receiving sessions. Safe to call multiple times on the same
  /// instance; later calls are no-ops while a sync is still in flight.
  Future<void> startSync() async {
    if (_running) {
      debugPrint('BleSessionSync: startSync() called while already running');
      return;
    }
    _running = true;
    _complete = false;
    _sentCount = 0;
    _observedMax = 0;
    debugPrint('[SESSION] ── Sync started ── device=${_device.remoteId}');

    try {
      final services = await _device.discoverServices();
      for (final service in services) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == _kSessionDataUuid) _dataChar = char;
          if (uuid == _kSessionAckUuid) _ackChar = char;
        }
      }

      if (_dataChar == null || _ackChar == null) {
        debugPrint(
          'BleSessionSync: sync characteristics not found (data=${_dataChar != null}, ack=${_ackChar != null})',
        );
        _emitComplete();
        return;
      }

      await _dataChar!.setNotifyValue(true);
      _notifySub = _dataChar!.lastValueStream.listen(
        _onPacket,
        onError: (Object e) {
          debugPrint('BleSessionSync: notify error: $e');
          _emitError(e);
        },
      );

      // Firmware sends the first packet on its own right after the app
      // subscribes, so we just wait. If nothing arrives within
      // `_idleTimeout` we assume the device had no unsent sessions.
      _armIdleTimer();
      _emitProgress();
    } catch (e) {
      debugPrint('BleSessionSync: startSync failed: $e');
      _emitError(e);
    }
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    await _notifySub?.cancel();
    _notifySub = null;
    if (!_progressController.isClosed) {
      await _progressController.close();
    }
    _running = false;
  }

  // ── packet handling ────────────────────────────────────────────────────────

  Future<void> _onPacket(List<int> data) async {
    if (data.length < 20) {
      debugPrint(
        'BleSessionSync: short packet (${data.length} bytes), ignoring',
      );
      return;
    }

    final bytes = Uint8List.fromList(data);
    final bd = ByteData.sublistView(bytes);

    final index = bytes[0];
    final type = bytes[1];
    final startTsEpoch = bd.getUint32(2, Endian.little);
    final durationSec = bd.getUint16(6, Endian.little);
    final wrongCount = bd.getUint16(8, Endian.little);
    final wrongDurSec = bd.getUint16(10, Endian.little);
    final therapyPatt = bytes[12];
    final tsSynced = bytes[13] == 1;

    _observedMax = index + 1 > _observedMax ? index + 1 : _observedMax;
    _armIdleTimer();

    final typeStr = type == 1 ? 'posture' : (type == 2 ? 'therapy' : null);
    if (typeStr == null) {
      debugPrint('BleSessionSync: unknown type byte=$type, skipping');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('BleSessionSync: no authenticated user, cannot insert');
      _emitError(StateError('No authenticated Supabase user'));
      return;
    }

    // ── [SESSION RECEIVED VIA BLE] ──────────────────────────────────────────
    debugPrint(
      '[SESSION] Received via BLE │ idx=$index  type=$typeStr  '
      'duration=${durationSec}s  wrongCount=$wrongCount  '
      'wrongDur=${wrongDurSec}s  therapyPatt=$therapyPatt  '
      'tsSynced=$tsSynced  startTsEpoch=$startTsEpoch',
    );

    final startTsStr = (tsSynced && startTsEpoch > 0)
        ? DateTime.fromMillisecondsSinceEpoch(
            startTsEpoch * 1000,
            isUtc: true,
          ).toIso8601String()
        : null;

    final row = <String, dynamic>{
      'user_id': user.id,
      'type': typeStr,
      // Firmware sends 0 when it never saw a valid wall clock; store null
      // in that case so Supabase doesn't show "1970-01-01" rows.
      'start_ts': startTsStr,
      'duration_sec': durationSec,
      'wrong_count': typeStr == 'posture' ? wrongCount : null,
      'wrong_dur_sec': typeStr == 'posture' ? wrongDurSec : null,
      'therapy_pattern': typeStr == 'therapy' ? therapyPatt : null,
      'ts_synced': tsSynced,
    };

    // ── [SESSION SAVING] ────────────────────────────────────────────────────
    debugPrint('[SESSION] Saving to Supabase │ idx=$index  row=$row');

    try {
      await _supabase.from('sessions').insert(row);
      // ── [SESSION SAVED] ──────────────────────────────────────────────────
      debugPrint(
        '[SESSION] Saved to Supabase ✓ │ idx=$index  type=$typeStr  '
        'start_ts=$startTsStr  duration=${durationSec}s',
      );
    } catch (e) {
      // On failure: DO NOT ack, so the device retries this record on the
      // next connection.
      debugPrint('[SESSION] Save FAILED ✗ │ idx=$index  error=$e');
      _emitError(e);
      return;
    }

    try {
      // ── [SESSION ACK SENT VIA BLE] ────────────────────────────────────────
      debugPrint('[SESSION] Sending BLE ACK │ idx=$index');
      await _ackChar!.write([
        index,
      ], withoutResponse: _ackChar!.properties.writeWithoutResponse);
      debugPrint(
        '[SESSION] BLE ACK sent ✓ │ idx=$index  total_synced=${_sentCount + 1}',
      );
      _sentCount++;
      _emitProgress();
    } catch (e) {
      debugPrint('[SESSION] BLE ACK FAILED ✗ │ idx=$index  error=$e');
      _emitError(e);
    }
  }

  // Idle = no new notifications for `_idleTimeout`. That's our signal the
  // firmware has nothing else to stream this connection (it doesn't send
  // an explicit "done" packet).
  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _emitComplete);
  }

  void _emitProgress() {
    if (_progressController.isClosed) return;
    final total = _observedMax > _sentCount ? _observedMax : _sentCount;
    _progressController.add(
      SyncProgress(sent: _sentCount, total: total, complete: _complete),
    );
  }

  void _emitComplete() {
    if (_complete) return;
    _complete = true;
    _running = false;
    _idleTimer?.cancel();
    _idleTimer = null;
    debugPrint('[SESSION] ── Sync complete ── total_saved=$_sentCount');
    if (_progressController.isClosed) return;
    _progressController.add(
      SyncProgress(sent: _sentCount, total: _sentCount, complete: true),
    );
  }

  void _emitError(Object error) {
    if (_progressController.isClosed) return;
    _progressController.add(
      SyncProgress(
        sent: _sentCount,
        total: _observedMax,
        complete: false,
        error: error,
      ),
    );
  }
}

/// Derive the "good posture" % shown in Analytics from the raw BLE fields.
/// Exposed as a top-level helper so UI code can stay in sync with the
/// canonical formula used by [SessionRepository].
int goodPostureScore({required int durationSec, required int wrongDurSec}) {
  if (durationSec <= 0) return 100;
  return (100 - (wrongDurSec / durationSec * 100)).round().clamp(0, 100);
}
