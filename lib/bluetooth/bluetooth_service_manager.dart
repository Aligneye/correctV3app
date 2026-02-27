import 'dart:async';
import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:flutter/foundation.dart';

/// Singleton manager for maintaining Bluetooth connection across the app
class BluetoothServiceManager {
  static final BluetoothServiceManager _instance =
      BluetoothServiceManager._internal();
  factory BluetoothServiceManager() => _instance;
  BluetoothServiceManager._internal();

  final AlignEyeDeviceService _deviceService = AlignEyeDeviceService();
  Timer? _reconnectTimer;
  bool _isAutoReconnecting = false;
  bool _shouldMaintainConnection = false;
  bool _isMonitoring = false;

  static const Duration _reconnectInterval = Duration(seconds: 3);

  AlignEyeDeviceService get deviceService => _deviceService;

  /// Initialize and start maintaining the Bluetooth connection
  Future<void> initialize() async {
    debugPrint('=== BluetoothServiceManager: Initializing ===');
    _shouldMaintainConnection = true;
    _startConnectionMonitoring();

    // Always try auto-connect when app opens (if not already connected)
    // Use a small delay to ensure the app is fully initialized
    Future.delayed(const Duration(milliseconds: 300), () async {
      final currentStatus = _deviceService.connectionStatus.value;
      debugPrint(
        'BluetoothServiceManager: Current connection status: $currentStatus',
      );

      if (currentStatus == DeviceConnectionStatus.disconnected) {
        debugPrint(
          'BluetoothServiceManager: Status is disconnected, calling tryAutoConnect()...',
        );
        try {
          await _deviceService.tryAutoConnect();
        } catch (e) {
          debugPrint('BluetoothServiceManager: Error during auto-connect: $e');
        }
      } else {
        debugPrint(
          'BluetoothServiceManager: Already connected/connecting, skipping auto-connect',
        );
      }
    });

    debugPrint(
      '=== BluetoothServiceManager: Initialization complete (auto-connect scheduled) ===',
    );
  }

  /// Stop maintaining the connection (called when app is closed)
  Future<void> shutdown() async {
    _shouldMaintainConnection = false;
    _stopConnectionMonitoring();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Note: We don't disconnect here to allow connection to persist
    // If you want to disconnect on app close, uncomment the next line:
    // await _deviceService.disconnect();
  }

  /// Manually connect to the device
  Future<void> connect() async {
    _shouldMaintainConnection = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _attemptConnection();
  }

  /// Manually disconnect from the device
  Future<void> disconnect() async {
    _shouldMaintainConnection = false;
    _stopConnectionMonitoring();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Pass userInitiated=true to prevent auto-reconnect
    await _deviceService.disconnect(userInitiated: true);
  }

  void _startConnectionMonitoring() {
    if (_isMonitoring) {
      return;
    }
    // Listen to connection status changes
    _deviceService.connectionStatus.addListener(_handleConnectionStatusChange);
    _isMonitoring = true;
  }

  void _handleConnectionStatusChange() {
    _onConnectionStatusChanged(_deviceService.connectionStatus.value);
  }

  void _stopConnectionMonitoring() {
    if (!_isMonitoring) {
      return;
    }
    _deviceService.connectionStatus.removeListener(
      _handleConnectionStatusChange,
    );
    _isMonitoring = false;
  }

  void _onConnectionStatusChanged(DeviceConnectionStatus status) {
    if (!_shouldMaintainConnection) return;

    if (status == DeviceConnectionStatus.disconnected && !_isAutoReconnecting) {
      debugPrint('Bluetooth disconnected, checking if should reconnect...');
      _scheduleReconnect();
    } else if (status == DeviceConnectionStatus.connected) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _isAutoReconnecting = false;
      debugPrint('Bluetooth connected successfully');
    }
  }

  Future<void> _attemptConnection() async {
    if (_isAutoReconnecting) return;

    final currentStatus = _deviceService.connectionStatus.value;
    if (currentStatus == DeviceConnectionStatus.connected ||
        currentStatus == DeviceConnectionStatus.connecting) {
      return;
    }

    _isAutoReconnecting = true;
    try {
      debugPrint('Attempting to connect to Bluetooth device...');
      // Use manual connect (not auto-connect) when user taps connect button
      await _deviceService.connect(isAutoConnect: false);
    } catch (e) {
      debugPrint('Connection failed: $e');
      if (_shouldMaintainConnection) {
        _scheduleReconnect();
      }
    } finally {
      _isAutoReconnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (!_shouldMaintainConnection) return;
    if (_reconnectTimer != null) return;

    debugPrint('Scheduling auto-reconnect in ${_reconnectInterval.inSeconds}s');

    _reconnectTimer = Timer(_reconnectInterval, () async {
      _reconnectTimer = null;

      if (!_shouldMaintainConnection) {
        return;
      }

      final status = _deviceService.connectionStatus.value;
      if (status == DeviceConnectionStatus.connected ||
          status == DeviceConnectionStatus.connecting) {
        return;
      }

      _isAutoReconnecting = true;
      try {
        await _deviceService.connect(isAutoConnect: true);
      } catch (e) {
        debugPrint('Auto-reconnect attempt failed: $e');
      } finally {
        _isAutoReconnecting = false;
      }

      if (_deviceService.connectionStatus.value !=
              DeviceConnectionStatus.connected &&
          _shouldMaintainConnection) {
        _scheduleReconnect();
      }
    });
  }
}
