import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:correctv1/services/ble_session_sync.dart';

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

  /// Bumps on every sync completion; pages can watch this to trigger a
  /// reload of the session list without holding onto a subscription.
  final ValueNotifier<int> syncCompletedTick = ValueNotifier<int>(0);

  BleSessionSync? _activeSync;
  StreamSubscription<SyncProgress>? _progressSub;
  bool _wired = false;

  /// Call once after BluetoothServiceManager.initialize(). Idempotent.
  void init() {
    if (_wired) return;
    _wired = true;
    _btManager.deviceService.connectionStatus.addListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    final status = _btManager.deviceService.connectionStatus.value;
    if (status == DeviceConnectionStatus.connected) {
      unawaited(_startSync());
    } else if (status == DeviceConnectionStatus.disconnected) {
      _teardownSync();
    }
  }

  Future<void> _startSync() async {
    // Nuke any previous sync session before starting a new one. This
    // handles the "reconnect after a drop mid-sync" path cleanly.
    await _teardownSync();

    final device = _btManager.deviceService.device;
    if (device == null) {
      debugPrint('DeviceManager: connected but no BluetoothDevice handle');
      return;
    }

    // Give the firmware a breath after the connect callback fires so the
    // CCCD subscription on our side is fully wired before we ask for
    // notifications. flutter_blue_plus also needs the services list to
    // finish settling.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final sync = BleSessionSync(device);
    _activeSync = sync;
    isSyncing.value = true;

    _progressSub = sync.progress.listen(
      (p) {
        lastProgress.value = p;
        if (p.complete) {
          isSyncing.value = false;
          syncCompletedTick.value++;
        }
      },
      onError: (Object e) {
        debugPrint('DeviceManager: sync stream error: $e');
        isSyncing.value = false;
      },
      onDone: () {
        isSyncing.value = false;
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
  }
}
