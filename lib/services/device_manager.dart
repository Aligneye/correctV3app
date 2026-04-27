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
    // completed before this wiring), kick off the sync flow now.
    if (_btManager.deviceService.connectionStatus.value ==
        DeviceConnectionStatus.connected) {
      debugPrint('DeviceManager: already connected at init — starting sync');
      _lastConnected = true;
      _liveSessionRecorder?.setEnabled(false);
      unawaited(_startSync());
    }
  }

  void _onLiveSessionChanged() {
    syncCompletedTick.value++;
    debugPrint('DeviceManager: live session changed, tick=${syncCompletedTick.value}');

    // When a live session ends (mode switches from TRAINING/THERAPY to
    // something else), the firmware stores the completed session to flash.
    // Re-run sync so the app picks it up immediately instead of waiting
    // for the next BLE reconnect.
    if (_btManager.deviceService.connectionStatus.value ==
        DeviceConnectionStatus.connected) {
      _scheduleResync();
    }
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
      debugPrint('DeviceManager: BLE connected — starting sync');
      _liveSessionRecorder?.setEnabled(false);
      unawaited(_startSync());
    } else if (!isConnected && wasConnected) {
      debugPrint('DeviceManager: BLE disconnected');
      _liveSessionRecorder?.setEnabled(false);
      _teardownSync();
    }
  }

  Future<void> _startSync() async {
    await _teardownSync();

    final device = _btManager.deviceService.device;
    if (device == null) {
      debugPrint('DeviceManager: connected but no BluetoothDevice handle');
      _liveSessionRecorder?.setEnabled(true);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (_btManager.deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      debugPrint('DeviceManager: disconnected during delay, aborting sync — enabling live recorder');
      _liveSessionRecorder?.setEnabled(true);
      return;
    }

    final sync = BleSessionSync(device);
    _activeSync = sync;
    isSyncing.value = true;

    _progressSub = sync.progress.listen(
      (p) {
        lastProgress.value = p;
        if (p.complete) {
          debugPrint('DeviceManager: sync complete — enabling live recorder');
          isSyncing.value = false;
          syncCompletedTick.value++;
          _liveSessionRecorder?.setEnabled(true);
        } else if (p.error != null) {
          debugPrint('DeviceManager: sync error: ${p.error} — enabling live recorder');
          isSyncing.value = false;
          _liveSessionRecorder?.setEnabled(true);
        }
      },
      onError: (Object e) {
        debugPrint('DeviceManager: sync stream error: $e — enabling live recorder');
        isSyncing.value = false;
        _liveSessionRecorder?.setEnabled(true);
      },
      onDone: () {
        if (isSyncing.value) {
          debugPrint('DeviceManager: sync stream done while still syncing — enabling live recorder');
          isSyncing.value = false;
          _liveSessionRecorder?.setEnabled(true);
        }
      },
    );

    try {
      await sync.startSync();
    } catch (e) {
      debugPrint('DeviceManager: startSync threw: $e — enabling live recorder');
      isSyncing.value = false;
      _liveSessionRecorder?.setEnabled(true);
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
