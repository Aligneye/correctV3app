import 'dart:async';
import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:flutter/foundation.dart';

/// Singleton manager for maintaining Bluetooth connection across the app
class BluetoothServiceManager {
  static final BluetoothServiceManager _instance = BluetoothServiceManager._internal();
  factory BluetoothServiceManager() => _instance;
  BluetoothServiceManager._internal();

  final AlignEyeDeviceService _deviceService = AlignEyeDeviceService();
  Timer? _reconnectTimer;
  bool _isAutoReconnecting = false;
  bool _shouldMaintainConnection = false;

  AlignEyeDeviceService get deviceService => _deviceService;

  /// Initialize and start maintaining the Bluetooth connection
  Future<void> initialize() async {
    _shouldMaintainConnection = true;
    _startConnectionMonitoring();
    
    // Try auto-connect only if user has connected before and didn't manually disconnect
    // This uses the persistent state stored in AlignEyeDeviceService
    if (_deviceService.connectionStatus.value == DeviceConnectionStatus.disconnected) {
      await _deviceService.tryAutoConnect();
    }
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
    // Listen to connection status changes
    _deviceService.connectionStatus.addListener(_handleConnectionStatusChange);
  }

  void _handleConnectionStatusChange() {
    _onConnectionStatusChanged(_deviceService.connectionStatus.value);
  }

  void _stopConnectionMonitoring() {
    _deviceService.connectionStatus.removeListener(_handleConnectionStatusChange);
  }

  void _onConnectionStatusChanged(DeviceConnectionStatus status) {
    if (!_shouldMaintainConnection) return;

    if (status == DeviceConnectionStatus.disconnected && !_isAutoReconnecting) {
      // Only auto-reconnect if user didn't manually disconnect
      // The _userInitiatedDisconnect flag is managed by AlignEyeDeviceService
      debugPrint('Bluetooth disconnected, checking if should reconnect...');
      // Don't auto-reconnect here - let the user manually connect again
      // The auto-reconnect only happens on app start via tryAutoConnect()
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
      // Don't schedule auto-reconnect - user must manually connect again
    } finally {
      _isAutoReconnecting = false;
    }
  }
}
