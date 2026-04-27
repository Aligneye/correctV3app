import 'dart:async';
import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const Duration _maxReconnectInterval = Duration(seconds: 60);
  static const int _reconnectJitterMs = 500;
  int _reconnectFailureCount = 0;

  static const String _keyAutoReconnect = 'settings_auto_reconnect';

  final autoReconnectEnabled = ValueNotifier<bool>(true);

  AlignEyeDeviceService get deviceService => _deviceService;

  Future<void> setAutoReconnect(bool enabled) async {
    autoReconnectEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoReconnect, enabled);
    } catch (e) {
      debugPrint('Error saving auto-reconnect preference: $e');
    }
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectFailureCount = 0;
      debugPrint('Auto-reconnect disabled — cancelled pending reconnects');
    }
  }

  Future<void> _loadAutoReconnectPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      autoReconnectEnabled.value = prefs.getBool(_keyAutoReconnect) ?? true;
    } catch (e) {
      debugPrint('Error loading auto-reconnect preference: $e');
    }
  }

  /// Initialize and start maintaining the Bluetooth connection
  Future<void> initialize() async {
    debugPrint('=== BluetoothServiceManager: Initializing ===');
    await _loadAutoReconnectPreference();
    _shouldMaintainConnection = true;
    _startConnectionMonitoring();

    // Only try auto-connect when app opens if the preference is enabled
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!autoReconnectEnabled.value) {
        debugPrint(
          'BluetoothServiceManager: Auto-reconnect disabled in settings, skipping startup auto-connect',
        );
        return;
      }

      final currentStatus = _deviceService.connectionStatus.value;
      debugPrint(
        'BluetoothServiceManager: Current connection status: $currentStatus',
      );

      if (currentStatus == DeviceConnectionStatus.disconnected) {
        final hasBondedTarget = await _deviceService.hasBondedTargetDevice();
        if (!hasBondedTarget) {
          debugPrint(
            'BluetoothServiceManager: No paired target device found, skipping startup auto-connect',
          );
          return;
        }
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
      if (!autoReconnectEnabled.value) {
        debugPrint(
          'Bluetooth disconnected, but auto-reconnect is disabled in settings — skipping',
        );
        return;
      }
      debugPrint('Bluetooth disconnected, checking if should reconnect...');
      unawaited(_scheduleReconnectIfEligible());
    } else if (status == DeviceConnectionStatus.connected) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _isAutoReconnecting = false;
      _reconnectFailureCount = 0;
      debugPrint('Bluetooth connected successfully');
    }
  }

  Future<void> _scheduleReconnectIfEligible() async {
    final hasBondedTarget = await _deviceService.hasBondedTargetDevice();
    if (!hasBondedTarget) {
      debugPrint(
        'Skipping auto-reconnect scheduling: no paired target device is available',
      );
      _reconnectFailureCount = 0;
      return;
    }
    _scheduleReconnect();
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
      await _deviceService.connect(isAutoConnect: false);
    } catch (e) {
      debugPrint('Connection failed: $e');
      final msg = e.toString().toLowerCase();
      final isDenied = msg.contains('permission') ||
          msg.contains('bluetooth is not enabled') ||
          msg.contains('not granted');
      if (isDenied) {
        // User denied — stop trying entirely.
        _shouldMaintainConnection = false;
        autoReconnectEnabled.value = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        debugPrint('User denied BLE — stopping all reconnect attempts');
      } else if (_shouldMaintainConnection) {
        _scheduleReconnect();
      }
    } finally {
      _isAutoReconnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (!_shouldMaintainConnection) return;
    if (!autoReconnectEnabled.value) return;
    if (_reconnectTimer != null) return;

    final baseDelayMs =
        _reconnectInterval.inMilliseconds * (1 << _reconnectFailureCount);
    final cappedDelayMs = baseDelayMs > _maxReconnectInterval.inMilliseconds
        ? _maxReconnectInterval.inMilliseconds
        : baseDelayMs;
    final jitterMs = DateTime.now().millisecondsSinceEpoch %
        (_reconnectJitterMs + 1);
    final effectiveDelayMs = cappedDelayMs + jitterMs;

    debugPrint(
      'Scheduling auto-reconnect in ${effectiveDelayMs}ms '
      '(failureCount=$_reconnectFailureCount)',
    );

    _reconnectTimer = Timer(Duration(milliseconds: effectiveDelayMs), () async {
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
        if (_reconnectFailureCount < 20) {
          _reconnectFailureCount++;
        }
        _scheduleReconnect();
      }
    });
  }
}
