import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:correctv1/services/ble_session_sync.dart';
import 'package:correctv1/services/live_session_recorder.dart';

/// App-wide glue between the Bluetooth layer and the session-sync layer.
///
/// On every BLE (re)connect we spin up a [BleSessionSync] for the connected
/// device, watch its progress, and notify listeners (Analytics) when the
/// sync finishes so they can reload the session list from Supabase.
///
/// Singleton: the BLE connection itself is a singleton (via
/// [BluetoothServiceManager]), so this coordinator follows suit.
class DeviceManager {
  DeviceManager._internal();

  static final DeviceManager _instance = DeviceManager._internal();
  factory DeviceManager() => _instance;

  final BluetoothServiceManager _btManager = BluetoothServiceManager();

  /// True while a sync is in progress. AnalyticsScreen watches this to show
  /// the "Syncing..." banner.
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  /// Latest progress snapshot, or null if no sync has started yet.
  final ValueNotifier<SyncProgress?> lastProgress =
      ValueNotifier<SyncProgress?>(null);

  /// Bumps on every sync completion or live-session change; pages can watch
  /// this to trigger a reload of the session list.
  final ValueNotifier<int> syncCompletedTick = ValueNotifier<int>(0);
  final ValueNotifier<String?> activeSessionId = ValueNotifier<String?>(null);

  BleSessionSync? _activeSync;
  LiveSessionRecorder? _liveSessionRecorder;

  /// True if the connection landed (or stayed) while a live session was
  /// in progress. We defer the BLE backlog sync until the session ends so
  /// the live posture/therapy stream doesn't have to share airtime with
  /// bulk session transfers. Cleared once a sync actually runs.
  bool _syncDeferredForLiveSession = false;

  /// Forwarded to [LiveSessionRecorder.primeTherapyContext]. Called by the
  /// therapy page right before firing the BLE command so the recorded row
  /// mirrors the user's target point / intensity / planned duration.
  void primeTherapyContext({
    String? targetPoint,
    int? intensityLevel,
    int? plannedDurationMinutes,
  }) {
    _liveSessionRecorder?.primeTherapyContext(
      targetPoint: targetPoint,
      intensityLevel: intensityLevel,
      plannedDurationMinutes: plannedDurationMinutes,
    );
  }
  StreamSubscription<SyncProgress>? _progressSub;
  bool _wired = false;
  bool _lastConnected = false;

  /// Call once after BluetoothServiceManager.initialize(). Idempotent.
  void init() {
    if (_wired) return;
    _wired = true;
    _btManager.deviceService.connectionStatus.addListener(_onStatusChanged);
    _liveSessionRecorder = LiveSessionRecorder(
      deviceService: _btManager.deviceService,
      activeSessionId: activeSessionId,
      onSessionChanged: _onLiveSessionChanged,
    )..start();

    // If already connected when init() runs (e.g. fast auto-reconnect
    // completed before this wiring), kick off the sync flow now. The live
    // recorder stays enabled — BLE sync is read-only for sessions that
    // already exist locally (it can only insert new rows).
    if (_btManager.deviceService.connectionStatus.value ==
        DeviceConnectionStatus.connected) {
      debugPrint('DeviceManager: already connected at init');
      _lastConnected = true;
      _liveSessionRecorder?.setEnabled(true);
      if (activeSessionId.value != null) {
        _syncDeferredForLiveSession = true;
        debugPrint(
          'DeviceManager: live session active at init, deferring BLE sync',
        );
      } else {
        unawaited(_startSync());
      }
    }
  }

  void _onLiveSessionChanged() {
    syncCompletedTick.value++;
    debugPrint('DeviceManager: live session changed, tick=${syncCompletedTick.value}');

    // Only drain the BLE backlog when the device is idle. If a session is
    // still in progress (live recorder currently owns one) we keep the link
    // clear so readings aren't interleaved with bulk session transfers; the
    // sync will fire on the next session-end tick instead.
    final hasLiveSession = activeSessionId.value != null;
    if (_btManager.deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      return;
    }
    if (hasLiveSession) {
      _syncDeferredForLiveSession = true;
      debugPrint(
        'DeviceManager: live session active, deferring BLE sync until it ends',
      );
      return;
    }
    if (_syncDeferredForLiveSession) {
      debugPrint('DeviceManager: live session ended, draining deferred sync');
      _syncDeferredForLiveSession = false;
    }
    _scheduleResync();
  }

  Timer? _resyncTimer;

  void _scheduleResync() {
    _resyncTimer?.cancel();
    _resyncTimer = Timer(const Duration(seconds: 2), () {
      if (_btManager.deviceService.connectionStatus.value ==
          DeviceConnectionStatus.connected) {
        debugPrint('DeviceManager: re-syncing after live session change');
        unawaited(_startSync());
      }
    });
  }

  void _onStatusChanged() {
    final status = _btManager.deviceService.connectionStatus.value;
    final isConnected = status == DeviceConnectionStatus.connected;
    final wasConnected = _lastConnected;
    _lastConnected = isConnected;

    if (isConnected && !wasConnected) {
      debugPrint('DeviceManager: BLE connected');
      // Keep the live recorder enabled: BLE sync runs on a separate
      // characteristic and will never overwrite existing local rows, so live
      // readings can flow into the recorder in parallel.
      _liveSessionRecorder?.setEnabled(true);

      // Defer the backlog pull when a live session is already active at the
      // moment we (re)connect — e.g. BT dropped mid-session and recovered.
      // Bulk transfers share the same link and cause the live stream to
      // stutter, so we wait for the session-end tick instead.
      if (activeSessionId.value != null) {
        _syncDeferredForLiveSession = true;
        debugPrint(
          'DeviceManager: live session already active on reconnect, '
          'deferring BLE sync until it ends',
        );
      } else {
        unawaited(_startSync());
      }
    } else if (!isConnected && wasConnected) {
      debugPrint('DeviceManager: BLE disconnected');
      // Leave the recorder enabled. It gates itself on connection status and
      // will simply skip readings until BLE comes back. Keeping it enabled
      // means the in-memory _LiveSession survives the drop and resumes on
      // reconnect with no duplicate row.
      _teardownSync();
    }
  }

  Future<void> _startSync() async {
    await _teardownSync();

    final device = _btManager.deviceService.device;
    if (device == null) {
      debugPrint('DeviceManager: connected but no BluetoothDevice handle');
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (_btManager.deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      debugPrint('DeviceManager: disconnected during delay, aborting sync');
      return;
    }

    final sync = BleSessionSync(device);
    _activeSync = sync;
    isSyncing.value = true;

    _progressSub = sync.progress.listen(
      (p) {
        lastProgress.value = p;
        if (p.complete) {
          debugPrint('DeviceManager: sync complete');
          isSyncing.value = false;
          syncCompletedTick.value++;
        } else if (p.error != null) {
          debugPrint('DeviceManager: sync error: ${p.error}');
          isSyncing.value = false;
        }
      },
      onError: (Object e) {
        debugPrint('DeviceManager: sync stream error: $e');
        isSyncing.value = false;
      },
      onDone: () {
        if (isSyncing.value) {
          debugPrint('DeviceManager: sync stream done while still syncing');
          isSyncing.value = false;
        }
      },
    );

    try {
      await sync.startSync();
    } catch (e) {
      debugPrint('DeviceManager: startSync threw: $e');
      isSyncing.value = false;
    }
  }

  Future<void> _teardownSync() async {
    _resyncTimer?.cancel();
    _resyncTimer = null;
    await _progressSub?.cancel();
    _progressSub = null;
    final s = _activeSync;
    _activeSync = null;
    if (s != null) {
      await s.dispose();
    }
    if (isSyncing.value) {
      isSyncing.value = false;
    }
  }

  Future<void> dispose() async {
    if (_wired) {
      _btManager.deviceService.connectionStatus.removeListener(
        _onStatusChanged,
      );
      _wired = false;
    }
    await _teardownSync();
    await _liveSessionRecorder?.dispose();
    _liveSessionRecorder = null;
  }
}
