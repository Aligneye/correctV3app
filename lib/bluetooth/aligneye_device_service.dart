import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const _kCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const _kDefaultDeviceNamePrefix = 'correct v1';

enum DeviceConnectionStatus { disconnected, connecting, connected }

class PostureReading {
  final String mode;
  final String subMode;
  final double angle;
  final double rawXG;
  final double rawYG;
  final double rawZG;
  final double angleX;
  final double angleY;
  final double angleZ;
  final double calY;
  final double calZ;
  final bool isCalibrating;
  final String posture;
  final bool isBadPosture;
  final double batteryVoltage;
  final int batteryPercentage;
  final int difficultyDeg;
  final String therapyPattern;
  final String therapyNextPattern;
  final int therapyElapsedSeconds;
  final int therapyRemainingSeconds;
  final DateTime timestamp;

  const PostureReading({
    required this.mode,
    required this.subMode,
    required this.angle,
    required this.rawXG,
    required this.rawYG,
    required this.rawZG,
    required this.angleX,
    required this.angleY,
    required this.angleZ,
    required this.calY,
    required this.calZ,
    required this.isCalibrating,
    required this.posture,
    required this.isBadPosture,
    required this.batteryVoltage,
    required this.batteryPercentage,
    required this.difficultyDeg,
    required this.therapyPattern,
    required this.therapyNextPattern,
    required this.therapyElapsedSeconds,
    required this.therapyRemainingSeconds,
    required this.timestamp,
  });

  factory PostureReading.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return PostureReading(
      mode: json['mode']?.toString() ?? 'UNKNOWN',
      subMode: json['sub_mode']?.toString() ?? 'UNKNOWN',
      angle: toDouble(json['angle']),
      rawXG: toDouble(json['raw_x_g']),
      rawYG: toDouble(json['raw_y_g']),
      rawZG: toDouble(json['raw_z_g']),
      angleX: toDouble(json['angle_x']),
      angleY: toDouble(json['angle_y']),
      angleZ: toDouble(json['angle_z']),
      calY: toDouble(json['cal_y']),
      calZ: toDouble(json['cal_z']),
      isCalibrating:
          json['is_calibrating'] == true ||
          json['is_calibrating']?.toString() == 'true',
      posture: json['posture']?.toString() ?? 'UNKNOWN',
      isBadPosture:
          json['is_bad_posture'] == true ||
          json['is_bad_posture']?.toString() == 'true',
      batteryVoltage: toDouble(json['battery_voltage']),
      batteryPercentage: toInt(json['battery_percentage']),
      difficultyDeg: toInt(json['difficulty_deg']),
      therapyPattern: json['therapy_pattern']?.toString() ?? '',
      therapyNextPattern: json['therapy_next_pattern']?.toString() ?? '',
      therapyElapsedSeconds: toInt(json['therapy_elapsed_sec']),
      therapyRemainingSeconds: toInt(json['therapy_remaining_sec']),
      timestamp: DateTime.now(),
    );
  }

  String toCompactString() {
    return 'mode=$mode, sub=$subMode, angle=${angle.round()}, '
        'raw=(${rawXG.toStringAsFixed(2)}, ${rawYG.toStringAsFixed(2)}, '
        '${rawZG.toStringAsFixed(2)}), '
        'ang=(${angleX.round()}, ${angleY.round()}, '
        '${angleZ.round()}), '
        'cal=(${calY.toStringAsFixed(2)}, ${calZ.toStringAsFixed(2)}), '
        'calibrating=$isCalibrating, posture=$posture, bad=$isBadPosture, '
        'battery=${batteryVoltage.toStringAsFixed(2)}V (${batteryPercentage}%), '
        'difficulty=$difficultyDeg, therapyNow=$therapyPattern, '
        'therapyNext=$therapyNextPattern, '
        'therapyElapsed=$therapyElapsedSeconds, '
        'therapyRemaining=$therapyRemainingSeconds';
  }
}

class AlignEyeDeviceService {
  AlignEyeDeviceService({String deviceNamePrefix = _kDefaultDeviceNamePrefix})
    : _deviceNamePrefix = deviceNamePrefix;

  final String _deviceNamePrefix;
  final _readingController = StreamController<PostureReading>.broadcast();
  final connectionStatus = ValueNotifier<DeviceConnectionStatus>(
    DeviceConnectionStatus.disconnected,
  );
  final currentReading = ValueNotifier<PostureReading?>(null);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  String _buffer = '';
  bool _userInitiatedDisconnect = false;
  bool _isConnecting = false;
  Timer? _connectionTimeoutTimer;
  Timer? _reconnectTimer;
  int _connectionRetryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _serviceDiscoveryTimeout = Duration(seconds: 20);
  
  // Persistent storage keys
  static const String _keyHasEverConnected = 'bluetooth_has_ever_connected';
  static const String _keyUserManuallyDisconnected = 'bluetooth_user_manually_disconnected';

  Stream<PostureReading> get readings => _readingController.stream;

  // Convenience getters for current reading values
  String get currentMode => currentReading.value?.mode ?? 'UNKNOWN';
  String get currentSubMode => currentReading.value?.subMode ?? 'UNKNOWN';
  double get currentAngle => currentReading.value?.angle ?? 0.0;
  double get currentRawXG => currentReading.value?.rawXG ?? 0.0;
  double get currentRawYG => currentReading.value?.rawYG ?? 0.0;
  double get currentRawZG => currentReading.value?.rawZG ?? 0.0;
  double get currentAngleX => currentReading.value?.angleX ?? 0.0;
  double get currentAngleY => currentReading.value?.angleY ?? 0.0;
  double get currentAngleZ => currentReading.value?.angleZ ?? 0.0;
  double get currentCalY => currentReading.value?.calY ?? 0.0;
  double get currentCalZ => currentReading.value?.calZ ?? 0.0;
  bool get currentIsCalibrating => currentReading.value?.isCalibrating ?? false;
  String get currentPosture => currentReading.value?.posture ?? 'UNKNOWN';
  bool get currentIsBadPosture => currentReading.value?.isBadPosture ?? false;
  double get currentBatteryVoltage => currentReading.value?.batteryVoltage ?? 0.0;
  int get currentBatteryPercentage => currentReading.value?.batteryPercentage ?? 0;
  int get currentDifficultyDeg => currentReading.value?.difficultyDeg ?? 25;
  String get currentTherapyPattern => currentReading.value?.therapyPattern ?? '';
  String get currentTherapyNextPattern =>
      currentReading.value?.therapyNextPattern ?? '';
  int get currentTherapyElapsedSeconds =>
      currentReading.value?.therapyElapsedSeconds ?? 0;
  int get currentTherapyRemainingSeconds =>
      currentReading.value?.therapyRemainingSeconds ?? 0;

  Future<void> sendModeControl({
    required String mode,
    required String postureTiming,
    required int therapyDurationMinutes,
    required int difficultyDegrees,
  }) async {
    if (connectionStatus.value != DeviceConnectionStatus.connected) {
      return;
    }

    final characteristic = _notifyCharacteristic;
    if (characteristic == null) {
      return;
    }

    if (!characteristic.properties.write &&
        !characteristic.properties.writeWithoutResponse) {
      debugPrint('Mode control skipped: characteristic is not writable');
      return;
    }

    final payload =
        'MODE=${mode.toUpperCase()};'
        'POSTURE_TIMING=${postureTiming.toUpperCase()};'
        'THERAPY_DURATION_MIN=$therapyDurationMinutes;'
        'DIFFICULTY_DEG=$difficultyDegrees';

    try {
      await characteristic.write(
        utf8.encode(payload),
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
      debugPrint('Mode control sent: $payload');
    } catch (e) {
      debugPrint('Failed to send mode control: $e');
    }
  }

  Future<bool> sendCalibrationStart() async {
    if (connectionStatus.value != DeviceConnectionStatus.connected) {
      return false;
    }

    // Send a few common command formats for compatibility across firmware
    // variants. Unknown commands are ignored by firmware safely.
    final commands = <String>[
      'CALIBRATE=START',
      'CALIBRATION=START',
      'ACTION=CALIBRATE',
    ];

    var sentAny = false;
    for (final payload in commands) {
      final sent = await _writeTextCommand(payload);
      sentAny = sentAny || sent;
      await Future.delayed(const Duration(milliseconds: 70));
    }
    return sentAny;
  }

  Future<bool> sendCalibrationCancel() async {
    if (connectionStatus.value != DeviceConnectionStatus.connected) {
      return false;
    }

    final commands = <String>[
      'CALIBRATE=CANCEL',
      'CALIBRATION=CANCEL',
      'ACTION=CALIBRATE_CANCEL',
    ];

    var sentAny = false;
    for (final payload in commands) {
      final sent = await _writeTextCommand(payload);
      sentAny = sentAny || sent;
      await Future.delayed(const Duration(milliseconds: 70));
    }
    return sentAny;
  }

  Future<bool> _writeTextCommand(String payload) async {
    final characteristic = _notifyCharacteristic;
    if (characteristic == null) {
      return false;
    }

    if (!characteristic.properties.write &&
        !characteristic.properties.writeWithoutResponse) {
      debugPrint('Write skipped: characteristic is not writable');
      return false;
    }

    try {
      await characteristic.write(
        utf8.encode(payload),
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
      debugPrint('Command sent: $payload');
      return true;
    } catch (e) {
      debugPrint('Failed to send command "$payload": $e');
      return false;
    }
  }

  Future<void> connect({bool isAutoConnect = false}) async {
    // Prevent concurrent connection attempts
    if (_isConnecting) {
      debugPrint('Connection already in progress, ignoring duplicate request');
      return;
    }

    if (connectionStatus.value == DeviceConnectionStatus.connected) {
      debugPrint('Already connected, skipping connection attempt');
      return;
    }

    // Don't auto-connect if user manually disconnected
    if (isAutoConnect && _userInitiatedDisconnect) {
      debugPrint('Skipping auto-connect - user manually disconnected');
      return;
    }

    // Reset retry count for new connection attempt
    if (connectionStatus.value == DeviceConnectionStatus.disconnected) {
      _connectionRetryCount = 0;
    }

    _isConnecting = true;
    connectionStatus.value = DeviceConnectionStatus.connecting;

    // Set connection timeout
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(_connectionTimeout, () {
      if (_isConnecting) {
        debugPrint('Connection timeout reached');
        _isConnecting = false;
        connectionStatus.value = DeviceConnectionStatus.disconnected;
        disconnect();
      }
    });

    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        connectionStatus.value = DeviceConnectionStatus.disconnected;
        return;
      }

      await _ensureBluetoothOn();

      // Verify Bluetooth is actually on with retry
      BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
      for (int i = 0; i < 3; i++) {
        adapterState = await FlutterBluePlus.adapterState.first.timeout(
          const Duration(seconds: 2),
        );
        if (adapterState == BluetoothAdapterState.on) {
          break;
        }
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('ERROR: Bluetooth is not ON after retries, cannot proceed');
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        connectionStatus.value = DeviceConnectionStatus.disconnected;
        throw Exception('Bluetooth is not enabled. Please enable Bluetooth and try again.');
      }

      // Check and request permissions first
      final hasPermissions = await _ensurePermissions();
      if (!hasPermissions) {
        debugPrint('Required permissions not granted, cannot proceed');
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        connectionStatus.value = DeviceConnectionStatus.disconnected;
        throw Exception(
          'Required permissions not granted. Please grant Location and Bluetooth permissions in app settings.',
        );
      }

      // Clean up any existing scan before starting new one
      await _cleanupScan();

      final device = await _scanForDevice();
      if (device == null) {
        debugPrint('Device not found - scan returned null');
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        connectionStatus.value = DeviceConnectionStatus.disconnected;
        
        // Retry connection if we haven't exceeded max retries
        if (_connectionRetryCount < _maxRetries && !isAutoConnect) {
          _connectionRetryCount++;
          debugPrint('Retrying connection (attempt $_connectionRetryCount/$_maxRetries)...');
          await Future.delayed(Duration(seconds: _connectionRetryCount * 2));
          _isConnecting = false;
          await connect(isAutoConnect: isAutoConnect);
          return;
        }
        
        throw Exception(
          'Device "correct v1" not found. Please ensure the device is powered on and within range.',
        );
      }

      _device = device;
      debugPrint(
        'Found device: ${_device!.platformName} (${_device!.remoteId})',
      );

      // Check if device is paired/bonded
      final isPaired = await _isDevicePaired(_device!);
      debugPrint('Device is paired: $isPaired');

      // Check if already connected
      BluetoothConnectionState currentState = await _device!.connectionState.first.timeout(
        const Duration(seconds: 2),
      );
      debugPrint('Current connection state: $currentState');

      bool needsConnection = true;
      if (currentState == BluetoothConnectionState.connected) {
        debugPrint('Device already connected, verifying connection...');
        // Verify the connection is actually working
        if (await _verifyConnection()) {
          debugPrint('Connection verified, setting up services...');
          needsConnection = false; // Already connected and verified
        } else {
          debugPrint('Connection state says connected but verification failed, reconnecting...');
          try {
            await _device!.disconnect();
            await Future.delayed(const Duration(milliseconds: 500));
            // Re-check state after disconnect
            currentState = await _device!.connectionState.first.timeout(
              const Duration(seconds: 2),
            );
            debugPrint('Connection state after disconnect: $currentState');
            needsConnection = true; // Need to reconnect
          } catch (e) {
            debugPrint('Error disconnecting: $e');
            needsConnection = true; // Assume we need to reconnect
          }
        }
      }

      if (needsConnection && currentState != BluetoothConnectionState.connected) {
        // Use auto-connect only if device is paired (not first time) and not user-initiated disconnect
        // For first-time connection (not paired), don't use auto-connect
        final shouldAutoConnect = isPaired && !_userInitiatedDisconnect;
        debugPrint(
          'Connecting to device (autoConnect: $shouldAutoConnect, isPaired: $isPaired, userDisconnected: $_userInitiatedDisconnect)...',
        );
        
        try {
          await _device!.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: shouldAutoConnect,
          );
          debugPrint('Connect call completed, waiting for connection state...');

          // Wait for connection to be established with timeout
          await _device!.connectionState
              .where((state) => state == BluetoothConnectionState.connected)
              .first
              .timeout(const Duration(seconds: 20));
          debugPrint('Device connected successfully');
          
          // Small delay to ensure connection is stable
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Reset user initiated disconnect flag on successful connection
          _userInitiatedDisconnect = false;
        } catch (e) {
          debugPrint('Connection failed: $e');
          final stateAfterError = await _device!.connectionState.first.timeout(
            const Duration(seconds: 2),
            onTimeout: () => BluetoothConnectionState.disconnected,
          );
          debugPrint('Connection state after error: $stateAfterError');
          
          // Retry if we haven't exceeded max retries
          if (_connectionRetryCount < _maxRetries && !isAutoConnect) {
            _connectionRetryCount++;
            debugPrint('Retrying connection after failure (attempt $_connectionRetryCount/$_maxRetries)...');
            await Future.delayed(Duration(seconds: _connectionRetryCount * 2));
            _isConnecting = false;
            _connectionTimeoutTimer?.cancel();
            await connect(isAutoConnect: isAutoConnect);
            return;
          }
          
          rethrow;
        }
      }

      // Set up connection state listener
      await _connectionSubscription?.cancel();
      _connectionSubscription = _device!.connectionState.listen(
        _handleConnectionUpdate,
        onError: (error) {
          debugPrint('Connection state listener error: $error');
        },
      );

      // Discover services with retry logic
      List<BluetoothService> services = await _discoverServicesWithRetry();

      _notifyCharacteristic = _findNotifyCharacteristic(services);

      if (_notifyCharacteristic == null) {
        debugPrint('ERROR: Could not find notify characteristic');
        debugPrint('Looking for service: $_kServiceUuid');
        debugPrint('Looking for characteristic: $_kCharacteristicUuid');
        
        // Retry service discovery if characteristic not found
        if (_connectionRetryCount < _maxRetries) {
          _connectionRetryCount++;
          debugPrint('Retrying service discovery (attempt $_connectionRetryCount/$_maxRetries)...');
          await Future.delayed(Duration(seconds: _connectionRetryCount));
          services = await _discoverServicesWithRetry();
          _notifyCharacteristic = _findNotifyCharacteristic(services);
        }
        
        if (_notifyCharacteristic == null) {
          await disconnect();
          _isConnecting = false;
          _connectionTimeoutTimer?.cancel();
          return;
        }
      }

      debugPrint(
        'Found characteristic: ${_notifyCharacteristic!.uuid} in service: ${_notifyCharacteristic!.serviceUuid}',
      );

      // Enable notifications with retry
      await _enableNotificationsWithRetry();

      // Set up notification subscription
      await _notifySubscription?.cancel();
      _notifySubscription = _notifyCharacteristic!.lastValueStream.listen(
        _handleNotifyData,
        onError: (error) {
          debugPrint('Notification error: $error');
          // Try to reconnect on notification error
          if (connectionStatus.value == DeviceConnectionStatus.connected) {
            disconnect();
          }
        },
      );

      // Verify connection is working by checking if we can receive data
      if (!await _verifyConnection()) {
        debugPrint('Connection verification failed after setup');
        await disconnect();
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        return;
      }

      _connectionTimeoutTimer?.cancel();
      _isConnecting = false;
      connectionStatus.value = DeviceConnectionStatus.connected;
      _connectionRetryCount = 0; // Reset retry count on success
      
      // Save connection state: user has connected and not manually disconnected
      if (!isAutoConnect) {
        // This is a manual connection, save state
        await _saveConnectionState(hasEverConnected: true, userManuallyDisconnected: false);
        debugPrint('Saved connection state: hasEverConnected=true, userManuallyDisconnected=false');
      } else {
        // Auto-connect succeeded, clear manual disconnect flag
        await _saveConnectionState(userManuallyDisconnected: false);
        debugPrint('Auto-connect succeeded, cleared manual disconnect flag');
      }
      
      debugPrint('Connection established successfully');
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      await disconnect();
      connectionStatus.value = DeviceConnectionStatus.disconnected;
      
      // Retry connection if we haven't exceeded max retries
      if (_connectionRetryCount < _maxRetries && !isAutoConnect && !_userInitiatedDisconnect) {
        _connectionRetryCount++;
        debugPrint('Retrying connection after error (attempt $_connectionRetryCount/$_maxRetries)...');
        await Future.delayed(Duration(seconds: _connectionRetryCount * 2));
        await connect(isAutoConnect: isAutoConnect);
      }
    }
  }

  Future<void> disconnect({bool userInitiated = false}) async {
    debugPrint('Disconnecting (userInitiated: $userInitiated)');
    
    // Cancel any pending connection attempts
    _isConnecting = false;
    _connectionTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    
    if (userInitiated) {
      _userInitiatedDisconnect = true;
      // Save state: user manually disconnected
      await _saveConnectionState(userManuallyDisconnected: true);
      debugPrint('User initiated disconnect - saved state to prevent auto-connect');
    }
    
    // Clean up subscriptions first
    _buffer = '';
    await _notifySubscription?.cancel();
    _notifySubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    // Clean up scan
    await _cleanupScan();

    if (_device != null) {
      try {
        // If user initiated disconnect, unpair the device
        if (userInitiated) {
          debugPrint('User initiated disconnect - unpairing device...');
          try {
            await _unpairDevice(_device!);
            debugPrint('Device unpaired successfully');
          } catch (e) {
            debugPrint('Failed to unpair device: $e');
          }
        }
        
        // Disconnect device with timeout
        await _device!.disconnect().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Disconnect timeout, forcing cleanup');
          },
        );
      } catch (e) {
        debugPrint('Error during disconnect: $e');
        // Continue with cleanup even if disconnect fails
      }
    }

    _device = null;
    _notifyCharacteristic = null;
    currentReading.value = null; // Clear current reading on disconnect
    connectionStatus.value = DeviceConnectionStatus.disconnected;
    
    debugPrint('Disconnect completed');
  }

  Future<void> dispose() async {
    debugPrint('Disposing AlignEyeDeviceService');
    _connectionTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    await disconnect();
    await _readingController.close();
    await _cleanupScan();
    connectionStatus.dispose();
    currentReading.dispose();
  }

  Future<void> _ensureBluetoothOn() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final state = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
      );
      debugPrint('Bluetooth adapter state (attempt ${attempt + 1}): $state');

      if (state == BluetoothAdapterState.on) {
        return;
      }

      if (state == BluetoothAdapterState.off &&
          defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('Bluetooth is off, turning on...');
        try {
          await FlutterBluePlus.turnOn();
          // Wait for Bluetooth to turn on
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            final newState = await FlutterBluePlus.adapterState.first.timeout(
              const Duration(seconds: 1),
            );
            if (newState == BluetoothAdapterState.on) {
              debugPrint('Bluetooth turned on successfully');
              return;
            }
          }
        } catch (e) {
          debugPrint('Error turning on Bluetooth: $e');
        }
      }

      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    throw Exception('Failed to ensure Bluetooth is on');
  }

  Future<bool> _isDevicePaired(BluetoothDevice device) async {
    try {
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      final isPaired = bondedDevices.any(
        (bonded) => bonded.remoteId == device.remoteId,
      );
      return isPaired;
    } catch (e) {
      debugPrint('Error checking if device is paired: $e');
      return false;
    }
  }

  Future<void> _unpairDevice(BluetoothDevice device) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('Attempting to remove bond for device: ${device.remoteId}');
        
        // Check if device is bonded first
        final isPaired = await _isDevicePaired(device);
        if (isPaired) {
          // Use platform channel to remove bond on Android
          const platform = MethodChannel('com.correctv1.bluetooth/unpair');
          try {
            final result = await platform.invokeMethod<bool>(
              'removeBond',
              {'address': device.remoteId.toString()},
            );
            if (result == true) {
              debugPrint('Device bond removed successfully');
            } else {
              debugPrint('Failed to remove bond (returned false)');
            }
          } on PlatformException catch (e) {
            debugPrint('Platform exception while removing bond: ${e.message}');
            // Fallback: try using flutter_blue_plus if it has removeBond
            // For now, we'll just log the error
          }
        } else {
          debugPrint('Device is not paired, nothing to unpair');
        }
      } else {
        debugPrint('Unpairing not implemented for this platform');
      }
    } catch (e) {
      debugPrint('Error unpairing device: $e');
      // Don't rethrow - unpairing failure shouldn't block disconnect
    }
  }

  Future<bool> _ensurePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // iOS handles permissions differently
    }

    debugPrint('Checking required permissions...');

    // Check and request location permission (required for BLE scanning on Android)
    final locationStatus = await Permission.location.status;
    debugPrint('Location permission status: $locationStatus');

    if (!locationStatus.isGranted) {
      debugPrint('Location permission not granted, requesting...');
      final locationResult = await Permission.location.request();
      debugPrint('Location permission request result: $locationResult');

      if (!locationResult.isGranted) {
        debugPrint('Location permission denied by user');
        return false;
      }
    }

    // Check Bluetooth permissions (Android 12+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;

      debugPrint('Bluetooth scan permission: $bluetoothScanStatus');
      debugPrint('Bluetooth connect permission: $bluetoothConnectStatus');

      if (!bluetoothScanStatus.isGranted) {
        debugPrint('Requesting Bluetooth scan permission...');
        final scanResult = await Permission.bluetoothScan.request();
        if (!scanResult.isGranted) {
          debugPrint('Bluetooth scan permission denied');
          return false;
        }
      }

      if (!bluetoothConnectStatus.isGranted) {
        debugPrint('Requesting Bluetooth connect permission...');
        final connectResult = await Permission.bluetoothConnect.request();
        if (!connectResult.isGranted) {
          debugPrint('Bluetooth connect permission denied');
          return false;
        }
      }
    }

    debugPrint('All required permissions granted');
    return true;
  }

  Future<BluetoothDevice?> _scanForDevice() async {
    // First, check for already connected devices
    final connectedDevices = await FlutterBluePlus.connectedDevices;
    for (final device in connectedDevices) {
      final name = device.platformName.trim();
      if (name.toLowerCase() == _deviceNamePrefix.toLowerCase() ||
          name.toLowerCase().startsWith(_deviceNamePrefix.toLowerCase())) {
        debugPrint('Found already connected device: $name');
        return device;
      }
    }

    // Second, check for bonded/paired devices (for auto-connect scenarios)
    // This allows faster connection if device is already paired
    try {
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      debugPrint('Found ${bondedDevices.length} bonded devices');
      
      for (final device in bondedDevices) {
        final name = device.platformName.trim();
        debugPrint('Checking bonded device: "$name"');
        
        if (name.toLowerCase() == _deviceNamePrefix.toLowerCase() ||
            name.toLowerCase().startsWith(_deviceNamePrefix.toLowerCase())) {
          debugPrint('Found already paired device: $name');
          return device;
        }
      }
      
      if (bondedDevices.isEmpty) {
        debugPrint('No bonded devices found');
      }
    } catch (e) {
      debugPrint('Error checking bonded devices: $e');
    }

    // Then scan for live advertisement packets. This avoids selecting stale
    // bonded entries that are currently out of range / not advertising.
    final completer = Completer<BluetoothDevice?>();

    // Clean up any existing scan
    await _cleanupScan();

    debugPrint('Starting BLE scan for device: $_deviceNamePrefix');

    // Check adapter state before scanning
    final adapterState = await FlutterBluePlus.adapterState.first;
    debugPrint('Adapter state before scan: $adapterState');

    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('ERROR: Bluetooth adapter is not ON, cannot scan');
      return null;
    }

    // Start scanning WITHOUT service filter to find all devices
    // Service UUID filter can be too restrictive if device doesn't advertise it
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      debugPrint('Scan started successfully');
    } catch (e) {
      debugPrint('ERROR: Failed to start scan: $e');
      debugPrint(
        'This is usually due to missing location permission on Android',
      );
      debugPrint('Please grant location permission in app settings');
      return null;
    }

    final scanResultCount = <int>[0]; // Use list to make it mutable in closure
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      scanResultCount[0] += results.length;
      debugPrint(
        'Scan found ${results.length} devices (total: ${scanResultCount[0]})',
      );

      for (final result in results) {
        final name = result.device.platformName.trim();
        final advName = result.advertisementData.advName.trim();

        // Check both platform name and advertisement name
        final deviceName = name.isNotEmpty ? name : advName;

        // Log all devices for debugging
        if (deviceName.isNotEmpty) {
          debugPrint(
            '  - Found device: "$deviceName" (platform: "$name", adv: "$advName")',
          );
        }

        // Check by service UUID first (most reliable)
        if (result.advertisementData.serviceUuids.any(
          (uuid) =>
              uuid.toString().toLowerCase() == _kServiceUuid.toLowerCase(),
        )) {
          debugPrint('Found device by service UUID: $deviceName');
          await FlutterBluePlus.stopScan();
          await _scanSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(result.device);
          }
          return;
        }

        // Match device name (case-insensitive, exact or prefix match)
        if (deviceName.isNotEmpty) {
          if (deviceName.toLowerCase() == _deviceNamePrefix.toLowerCase() ||
              deviceName.toLowerCase().startsWith(
                _deviceNamePrefix.toLowerCase(),
              )) {
            debugPrint('Found device by name match: $deviceName');
            await FlutterBluePlus.stopScan();
            await _scanSubscription?.cancel();
            if (!completer.isCompleted) {
              completer.complete(result.device);
            }
            return;
          }
        }
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () async {
        debugPrint('Scan timeout after 20 seconds - device not found');
        debugPrint('Total devices scanned: ${scanResultCount[0]}');

        if (scanResultCount[0] == 0) {
          debugPrint('WARNING: No devices found at all during scan!');
          debugPrint('This could mean:');
          debugPrint(
            '  1. Location permission not granted (required for BLE scan on Android)',
          );
          debugPrint('  2. Bluetooth is not enabled');
          debugPrint('  3. Device is not advertising');
          debugPrint('  4. Device is out of range');
        }

        await FlutterBluePlus.stopScan();
        await _scanSubscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return null;
      },
    );
  }

  BluetoothCharacteristic? _findNotifyCharacteristic(
    List<BluetoothService> services,
  ) {
    final serviceUuidLower = _kServiceUuid.toLowerCase();
    final charUuidLower = _kCharacteristicUuid.toLowerCase();

    debugPrint('Searching for service: $serviceUuidLower');
    debugPrint('Searching for characteristic: $charUuidLower');

    for (final service in services) {
      final serviceUuid = service.uuid.toString().toLowerCase();
      debugPrint('Checking service: $serviceUuid');

      if (serviceUuid == serviceUuidLower) {
        debugPrint('Found matching service!');
        for (final characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.toString().toLowerCase();
          debugPrint('  Checking characteristic: $charUuid');

          if (charUuid == charUuidLower) {
            debugPrint('  Found matching characteristic!');
            // Verify it supports notifications
            if (characteristic.properties.notify ||
                characteristic.properties.indicate) {
              debugPrint('  Characteristic supports notifications - SUCCESS!');
              return characteristic;
            } else {
              debugPrint('  Characteristic does NOT support notifications');
            }
          }
        }
      }
    }

    debugPrint('Could not find matching service/characteristic');
    return null;
  }

  void _handleNotifyData(List<int> data) {
    if (data.isEmpty) return;
    _buffer += utf8.decode(data, allowMalformed: true);

    while (true) {
      final start = _buffer.indexOf('{');
      final end = _buffer.indexOf('}', start + 1);
      if (start == -1 || end == -1) {
        break;
      }
      final chunk = _buffer.substring(start, end + 1).trim();
      _buffer = _buffer.substring(end + 1);
      try {
        final decoded = jsonDecode(chunk);
        if (decoded is Map<String, dynamic>) {
          final reading = PostureReading.fromJson(decoded);
          // Store current reading
          currentReading.value = reading;
          // Emit to stream
          _readingController.add(reading);
        }
      } catch (_) {
        // Ignore malformed payloads; we'll wait for the next valid JSON packet.
      }
    }
  }

  void _handleConnectionUpdate(BluetoothConnectionState state) {
    debugPrint('Connection state changed: $state');
    
    if (state == BluetoothConnectionState.connected) {
      // Reset user initiated disconnect flag when reconnected (user manually connected again)
      _userInitiatedDisconnect = false;
      _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      _connectionRetryCount = 0;
      
      // Save state: user has connected again, clear manual disconnect flag
      _saveConnectionState(userManuallyDisconnected: false);
      
      // Verify connection is actually working
      _verifyConnection().then((isValid) {
        if (isValid) {
          connectionStatus.value = DeviceConnectionStatus.connected;
        } else {
          debugPrint('Connection state says connected but verification failed');
          disconnect();
        }
      });
    } else if (state == BluetoothConnectionState.disconnected) {
      _isConnecting = false;
      _connectionTimeoutTimer?.cancel();
      
      // Only update status if we're not already disconnected
      if (connectionStatus.value != DeviceConnectionStatus.disconnected) {
        connectionStatus.value = DeviceConnectionStatus.disconnected;
        
        // Don't auto-reconnect here - auto-reconnect only happens on app start
        // via tryAutoConnect() which checks persistent state
      }
      
      // Keep _userInitiatedDisconnect flag set if user manually disconnected
      // This prevents auto-reconnect until user manually connects again
    } else if (state == BluetoothConnectionState.connecting) {
      connectionStatus.value = DeviceConnectionStatus.connecting;
    }
  }

  /// Clean up any active scan
  Future<void> _cleanupScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Discover services with retry logic
  Future<List<BluetoothService>> _discoverServicesWithRetry() async {
    List<BluetoothService>? services;
    Exception? lastError;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        debugPrint('Discovering services (attempt ${attempt + 1}/3)...');
        
        if (_device == null) {
          throw Exception('Device is null');
        }

        services = await _device!.discoverServices().timeout(
          _serviceDiscoveryTimeout,
        );
        
        debugPrint('Found ${services.length} services');
        
        // Log all services and characteristics for debugging
        for (final service in services) {
          debugPrint('  Service: ${service.uuid}');
          for (final char in service.characteristics) {
            debugPrint(
              '    Characteristic: ${char.uuid} (notify: ${char.properties.notify}, read: ${char.properties.read})',
            );
          }
        }
        
        // If we got services, break out of retry loop
        if (services.isNotEmpty) {
          break;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('Service discovery failed (attempt ${attempt + 1}/3): $e');
        
        if (attempt < 2) {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }

    if (services == null || services.isEmpty) {
      throw lastError ?? Exception('Failed to discover services after 3 attempts');
    }

    return services;
  }

  /// Enable notifications with retry logic
  Future<void> _enableNotificationsWithRetry() async {
    if (_notifyCharacteristic == null) {
      throw Exception('Notify characteristic is null');
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        debugPrint('Enabling notifications (attempt ${attempt + 1}/3)...');
        await _notifyCharacteristic!.setNotifyValue(true);
        
        // Wait a bit to ensure notification is set up
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Verify notification is enabled
        if (_notifyCharacteristic!.isNotifying) {
          debugPrint('Notifications enabled successfully');
          return;
        } else {
          throw Exception('Notification enabled but isNotifying is false');
        }
      } catch (e) {
        debugPrint('Failed to enable notifications (attempt ${attempt + 1}/3): $e');
        
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        } else {
          rethrow;
        }
      }
    }
  }

  /// Verify connection is actually working
  Future<bool> _verifyConnection() async {
    if (_device == null) {
      debugPrint('Connection verification failed: device is null');
      return false;
    }

    try {
      // Check connection state
      final state = await _device!.connectionState.first.timeout(
        const Duration(seconds: 2),
      );
      
      if (state != BluetoothConnectionState.connected) {
        debugPrint('Connection verification failed: state is $state');
        return false;
      }

      // If characteristic is not set up yet, that's okay - we'll set it up
      // Only verify notifications if characteristic is already set up
      if (_notifyCharacteristic != null) {
        // Check if notifications are enabled
        if (!_notifyCharacteristic!.isNotifying) {
          debugPrint('Connection verification: characteristic exists but notifications not enabled yet');
          // This is okay - we'll enable them during setup
          return true; // Connection is good, just need to set up notifications
        }
        debugPrint('Connection verification passed - device connected and notifications enabled');
        return true;
      } else {
        debugPrint('Connection verification passed - device connected, will set up services');
        return true; // Device is connected, we just need to set up services
      }
    } catch (e) {
      debugPrint('Connection verification error: $e');
      return false;
    }
  }

  /// Attempts to auto-connect to a paired device if available
  /// This should be called on app start or when appropriate
  Future<void> tryAutoConnect() async {
    // Load persistent state
    await _loadConnectionState();
    
    if (_userInitiatedDisconnect) {
      debugPrint('Skipping auto-connect - user manually disconnected');
      return;
    }

    if (connectionStatus.value != DeviceConnectionStatus.disconnected) {
      debugPrint('Already connected or connecting, skipping auto-connect');
      return;
    }

    // Check if user has ever connected before
    final prefs = await SharedPreferences.getInstance();
    final hasEverConnected = prefs.getBool(_keyHasEverConnected) ?? false;
    
    if (!hasEverConnected) {
      debugPrint('Skipping auto-connect - user has never connected before (first time)');
      return;
    }

    try {
      // Check if we have a paired device
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      
      BluetoothDevice? pairedDevice;
      for (final device in bondedDevices) {
        final name = device.platformName.trim();
        if (name.toLowerCase() == _deviceNamePrefix.toLowerCase() ||
            name.toLowerCase().startsWith(_deviceNamePrefix.toLowerCase())) {
          pairedDevice = device;
          break;
        }
      }

      if (pairedDevice != null) {
        debugPrint('Found paired device, attempting auto-connect...');
        await connect(isAutoConnect: true);
      } else {
        debugPrint('No paired device found for auto-connect');
      }
    } catch (e) {
      debugPrint('Auto-connect failed: $e');
      // Don't throw - auto-connect failures should be silent
    }
  }
  
  /// Save connection state to persistent storage
  Future<void> _saveConnectionState({
    bool? hasEverConnected,
    bool? userManuallyDisconnected,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (hasEverConnected != null) {
        await prefs.setBool(_keyHasEverConnected, hasEverConnected);
      }
      if (userManuallyDisconnected != null) {
        await prefs.setBool(_keyUserManuallyDisconnected, userManuallyDisconnected);
        _userInitiatedDisconnect = userManuallyDisconnected;
      }
    } catch (e) {
      debugPrint('Error saving connection state: $e');
    }
  }
  
  /// Load connection state from persistent storage
  Future<void> _loadConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userManuallyDisconnected = prefs.getBool(_keyUserManuallyDisconnected) ?? false;
      _userInitiatedDisconnect = userManuallyDisconnected;
      debugPrint('Loaded connection state: userManuallyDisconnected=$userManuallyDisconnected');
    } catch (e) {
      debugPrint('Error loading connection state: $e');
    }
  }
}
