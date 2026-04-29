import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/services/session_database.dart';
import 'package:correctv1/services/session_sync_service.dart';

/// UUIDs of the firmware's session-sync characteristics.
/// Must match `src/bluetooth_manager.cpp` exactly.
const String _kSessionDataUuid = '0000aa01-0000-1000-8000-00805f9b34fb';
const String _kSessionAckUuid = '0000aa02-0000-1000-8000-00805f9b34fb';

/// Protocol bytes — must match firmware.
const int _kSessionSyncStart = 0xFF;
const int _kExtensionMarker = 0xEE;

bool _matchesBleUuid(Guid uuid, String expected) {
  final actual = uuid.toString().toLowerCase();
  final normalizedExpected = expected.toLowerCase();
  return actual == normalizedExpected ||
      actual == normalizedExpected.substring(4, 8) ||
      (actual.length == 4 && normalizedExpected.startsWith('0000$actual-'));
}

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

/// Buffer that accumulates a session summary plus its extension packets
/// (event timeline) before being upserted into Supabase.
class _PendingSession {
  _PendingSession({
    required this.index,
    required this.type,
    required this.startTsEpoch,
    required this.startTsIso,
    required this.durationSec,
    required this.wrongCount,
    required this.wrongDurSec,
    required this.therapyPattern,
    required this.tsSynced,
    required this.expectedExtPackets,
    required this.totalEvents,
  });

  final int index;
  final String type; // 'posture' or 'therapy'
  final int startTsEpoch;
  final String? startTsIso;
  final int durationSec;
  final int wrongCount;
  final int wrongDurSec;
  final int therapyPattern;
  final bool tsSynced;
  final int expectedExtPackets;
  final int totalEvents;
  int receivedExtPackets = 0;

  // Accumulated events.
  final List<Map<String, int>> postureEvents = <Map<String, int>>[];
  final List<int> therapyPatterns = <int>[];

  bool get hasExtensions => expectedExtPackets > 0;
  bool get extensionsComplete => receivedExtPackets >= expectedExtPackets;
}

/// Pulls unsent posture/therapy sessions off the Aligneye wearable over BLE,
/// uploads each one to Supabase, and ACKs the device only once the insert
/// succeeds so failed rows retry on the next connection.
///
/// Two-stage protocol (matches firmware `src/bluetooth_manager.cpp`):
///
/// **Summary packet** (20 bytes, sent first for each session):
///   byte 0:      sync index
///   byte 1:      type (1=posture, 2=therapy)
///   bytes 2-5:   start_ts uint32 LE
///   bytes 6-7:   duration_sec uint16 LE
///   bytes 8-9:   wrong_count uint16 LE
///   bytes 10-11: wrong_dur_sec uint16 LE
///   byte 12:     therapy_pattern uint8
///   byte 13:     ts_synced uint8
///   byte 14:     event count (posture pairs or therapy patterns)
///   byte 15:     extension packet count
///   bytes 16-19: reserved zeros
///
/// **Extension packet** (20 bytes, sent after summary if event count > 0):
///   byte 0:      0xEE (extension marker)
///   byte 1:      extension sub-index (0-based)
///   bytes 2-19:  payload — for posture, up to 4 (slouch_u16, correction_u16)
///                pairs; for therapy, up to 18 pattern_u8 indices.
///
/// The device only marks a session sent after the *last* extension packet is
/// ACK'd (or, when there are no extensions, after the summary itself is
/// ACK'd). Failed Supabase upserts therefore leave the record on flash for
/// the next reconnect.
class BleSessionSync {
  BleSessionSync(this._device, {SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final BluetoothDevice _device;
  final SupabaseClient _supabase;

  final _progressController = StreamController<SyncProgress>.broadcast();

  BluetoothCharacteristic? _dataChar;
  BluetoothCharacteristic? _ackChar;
  StreamSubscription<List<int>>? _notifySub;

  int _sentCount = 0;
  int _observedMax = 0;
  Timer? _idleTimer;
  bool _complete = false;
  bool _running = false;

  _PendingSession? _pending;

  /// Bumps inactivity-based completion when the device stops streaming.
  /// 4s gives the firmware ample time between sessions on a busy link.
  static const Duration _idleTimeout = Duration(seconds: 4);

  /// ±10s window for stitching an offline-sync row onto an existing live
  /// session row (e.g. BT dropped mid-session and the firmware rebroadcasts
  /// the full session on reconnect).
  static const Duration _dedupeWindow = Duration(seconds: 10);

  Stream<SyncProgress> get progress => _progressController.stream;

  Future<void> startSync() async {
    if (_running) {
      debugPrint('BleSessionSync: startSync() called while already running');
      return;
    }
    _running = true;
    _complete = false;
    _sentCount = 0;
    _observedMax = 0;
    _pending = null;
    debugPrint('[SESSION] ── Sync started ── device=${_device.remoteId}');

    try {
      // Use the already-discovered service list from the active connection.
      // AlignEyeDeviceService.connect() already calls discoverServices(),
      // so calling it again can cause BLE stack errors on some platforms.
      final services = _device.servicesList;
      void scanServices(List<BluetoothService> serviceList) {
        for (final service in serviceList) {
          for (final char in service.characteristics) {
            if (_matchesBleUuid(char.uuid, _kSessionDataUuid)) {
              _dataChar = char;
            }
            if (_matchesBleUuid(char.uuid, _kSessionAckUuid)) {
              _ackChar = char;
            }
          }
        }
      }

      if (services.isEmpty) {
        debugPrint(
          'BleSessionSync: no cached services, falling back to discovery',
        );
        final discovered = await _device.discoverServices();
        scanServices(discovered);
      } else {
        scanServices(services);
      }

      if (_dataChar == null || _ackChar == null) {
        debugPrint(
          '[SESSION] ⚠️ Sync characteristics NOT found on device — '
          'firmware may not support offline session sync '
          '(data=${_dataChar != null}, ack=${_ackChar != null})',
        );
        _emitComplete();
        return;
      }
      debugPrint('[SESSION] Found sync characteristics (data + ack)');

      // Subscribe BEFORE enabling notifications to avoid missing the first
      // packet if it arrives between setNotifyValue() completing and listen().
      _notifySub = _dataChar!.lastValueStream.listen(
        _onPacket,
        onError: (Object e) {
          debugPrint('BleSessionSync: notify error: $e');
          _emitError(e);
        },
      );
      await _dataChar!.setNotifyValue(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await _writeAck(_kSessionSyncStart);
      debugPrint('[SESSION] Sync start requested over BLE');

      _armIdleTimer();
      _emitProgress();
    } catch (e) {
      debugPrint('BleSessionSync: startSync failed: $e');
      _emitError(e);
      _emitComplete();
    }
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    await _notifySub?.cancel();
    _notifySub = null;
    try {
      await _dataChar?.setNotifyValue(false);
    } catch (_) {
      // Best effort cleanup; disconnects can make CCCD writes fail.
    }
    if (!_progressController.isClosed) {
      await _progressController.close();
    }
    _running = false;
  }

  // ── packet handling ────────────────────────────────────────────────────────

  Future<void> _onPacket(List<int> data) async {
    if (data.length < 20) {
      if (data.isNotEmpty) {
        debugPrint(
          'BleSessionSync: short packet (${data.length} bytes), ignoring',
        );
      }
      return;
    }

    // Ignore all-zero packets (initial cached value from the characteristic).
    if (data.every((b) => b == 0)) return;

    _armIdleTimer();
    final bytes = Uint8List.fromList(data);

    // Extension packets are tagged with 0xEE in byte 0; everything else is a
    // session summary.
    if (bytes[0] == _kExtensionMarker) {
      await _handleExtensionPacket(bytes);
    } else {
      await _handleSummaryPacket(bytes);
    }
  }

  Future<void> _handleSummaryPacket(Uint8List bytes) async {
    final bd = ByteData.sublistView(bytes);

    final index = bytes[0];
    final type = bytes[1];
    final startTsEpoch = bd.getUint32(2, Endian.little);
    final durationSec = bd.getUint16(6, Endian.little);
    final wrongCount = bd.getUint16(8, Endian.little);
    final wrongDurSec = bd.getUint16(10, Endian.little);
    final therapyPatt = bytes[12];
    final tsSynced = bytes[13] == 1;
    final eventCount = bytes[14];
    final extPackets = bytes[15];

    _observedMax = index + 1 > _observedMax ? index + 1 : _observedMax;

    final typeStr = type == 1 ? 'posture' : (type == 2 ? 'therapy' : null);
    if (typeStr == null) {
      debugPrint('BleSessionSync: unknown type byte=$type, skipping');
      return;
    }

    final startTsIso = startTsEpoch > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            startTsEpoch * 1000,
            isUtc: true,
          ).toIso8601String()
        : null;

    debugPrint(
      '[SESSION] Summary │ idx=$index  type=$typeStr  '
      'duration=${durationSec}s  wrongCount=$wrongCount  '
      'wrongDur=${wrongDurSec}s  therapyPatt=$therapyPatt  '
      'tsSynced=$tsSynced  events=$eventCount  extPackets=$extPackets',
    );

    _pending = _PendingSession(
      index: index,
      type: typeStr,
      startTsEpoch: startTsEpoch,
      startTsIso: startTsIso,
      durationSec: durationSec,
      wrongCount: wrongCount,
      wrongDurSec: wrongDurSec,
      therapyPattern: therapyPatt,
      tsSynced: tsSynced,
      expectedExtPackets: extPackets,
      totalEvents: eventCount,
    );

    if (_pending!.hasExtensions) {
      // ACK the summary index — this triggers the firmware to start streaming
      // extension packets. Upsert happens after the last extension lands.
      await _writeAck(index);
      return;
    }

    // No extensions; persist the summary and ACK with index to advance.
    final ok = await _persistPending();
    if (ok) {
      await _writeAck(index);
      _sentCount++;
      _emitProgress();
    }
  }

  Future<void> _handleExtensionPacket(Uint8List bytes) async {
    final pending = _pending;
    if (pending == null) {
      debugPrint('BleSessionSync: extension packet with no pending summary');
      return;
    }

    final subIndex = bytes[1];
    final bd = ByteData.sublistView(bytes);

    if (pending.type == 'posture') {
      // Up to 4 (uint16 slouch, uint16 correction) pairs in bytes 2..19.
      final remaining = pending.totalEvents - pending.postureEvents.length;
      final pairsInPacket = remaining > 4 ? 4 : remaining;
      for (var i = 0; i < pairsInPacket; i++) {
        final s = bd.getUint16(2 + i * 4, Endian.little);
        final c = bd.getUint16(2 + i * 4 + 2, Endian.little);
        pending.postureEvents.add({'s': s, 'c': c});
      }
    } else {
      // Therapy: up to 18 pattern bytes in bytes 2..19.
      final remaining = pending.totalEvents - pending.therapyPatterns.length;
      final countInPacket = remaining > 18 ? 18 : remaining;
      for (var i = 0; i < countInPacket; i++) {
        pending.therapyPatterns.add(bytes[2 + i]);
      }
    }

    pending.receivedExtPackets++;
    debugPrint(
      '[SESSION] Ext │ sub=$subIndex  ${pending.receivedExtPackets}/'
      '${pending.expectedExtPackets}',
    );

    if (!pending.extensionsComplete) {
      // More extensions still to come — ACK this one to request the next.
      await _writeAck(_kExtensionMarker);
      return;
    }

    // Last extension landed — persist now, then ACK so the device advances
    // and marks the session sent. Skipping the ACK on failure leaves the
    // record on flash for the next reconnect.
    final ok = await _persistPending();
    if (ok) {
      await _writeAck(_kExtensionMarker);
      _sentCount++;
      _emitProgress();
    }
  }

  Future<bool> _persistPending() async {
    final pending = _pending;
    if (pending == null) return false;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('BleSessionSync: no authenticated user, cannot upsert');
      _emitError(StateError('No authenticated Supabase user'));
      return false;
    }

    final effectiveStartTs =
        pending.startTsIso ?? DateTime.now().toUtc().toIso8601String();

    final row = <String, dynamic>{
      'user_id': user.id,
      'type': pending.type,
      'start_ts': effectiveStartTs,
      'duration_sec': pending.durationSec,
      'wrong_count': pending.type == 'posture' ? pending.wrongCount : null,
      'wrong_dur_sec': pending.type == 'posture' ? pending.wrongDurSec : null,
      'therapy_pattern': pending.type == 'therapy'
          ? pending.therapyPattern
          : null,
      'ts_synced': pending.tsSynced,
      'posture_events':
          pending.type == 'posture' && pending.postureEvents.isNotEmpty
          ? pending.postureEvents
          : null,
      'therapy_patterns':
          pending.type == 'therapy' && pending.therapyPatterns.isNotEmpty
          ? pending.therapyPatterns
          : null,
    };

    try {
      final db = SessionDatabase.instance;
      final existingId = await _findExistingRowId(pending);
      if (existingId != null) {
        await db.updateSession(existingId, row);
        debugPrint(
          '[SESSION] Local upsert (update) ✓ │ idx=${pending.index} '
          'id=$existingId type=${pending.type}',
        );
      } else {
        final id = await db.insertSession({...row, 'sync_status': 0});
        debugPrint(
          '[SESSION] Local upsert (insert) ✓ │ idx=${pending.index} '
          'id=$id type=${pending.type}',
        );
      }
      _pending = null;
      SessionSyncService.instance.triggerSync();
      return true;
    } catch (e) {
      debugPrint(
        '[SESSION] Local upsert FAILED ✗ │ idx=${pending.index}  error=$e',
      );
      _emitError(e);
      return false;
    }
  }

  Future<String?> _findExistingRowId(_PendingSession pending) async {
    final iso = pending.startTsIso;
    if (iso == null) return null;

    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      return await SessionDatabase.instance.findExistingByStartTs(
        user.id,
        pending.type,
        DateTime.parse(iso),
        _dedupeWindow,
      );
    } catch (e) {
      debugPrint('BleSessionSync: dedupe lookup failed: $e');
      return null;
    }
  }

  Future<void> _writeAck(int byte) async {
    final char = _ackChar;
    if (char == null) return;
    try {
      await char.write(
        [byte],
        withoutResponse:
            !char.properties.write && char.properties.writeWithoutResponse,
      );
    } catch (e) {
      debugPrint('BleSessionSync: ACK write failed (byte=$byte): $e');
      _emitError(e);
    }
  }

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
