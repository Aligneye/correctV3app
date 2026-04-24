import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const _kCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const _kDefaultDeviceNamePrefix = 'correct v1';

enum DeviceConnectionStatus { disconnected, connecting, connected }

class _ScanCandidate {
  const _ScanCandidate({
    required this.device,
    required this.rssi,
    required this.isBonded,
  });

  final BluetoothDevice device;
  final int rssi;
  final bool isBonded;
}

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
  final String calibrationResult;
  final int calibrationElapsedMs;
  final int calibrationTotalMs;
  final String calibrationPhase;
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
    required this.calibrationResult,
    required this.calibrationElapsedMs,
    required this.calibrationTotalMs,
    required this.calibrationPhase,
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
      calibrationResult: json['calibration_result']?.toString() ?? '',
      calibrationElapsedMs: toInt(
        json['c_elap'] ?? json['calibration_elapsed_ms'],
      ),
      calibrationTotalMs: toInt(json['c_tot'] ?? json['calibration_total_ms']),
      calibrationPhase: (json['c_phase']?.toString() ?? 'IDLE').toUpperCase(),
      posture: json['posture']?.toString() ?? 'UNKNOWN',
      isBadPosture:
          json['is_bad_posture'] == true ||
          json['is_bad_posture']?.toString() == 'true',
      batteryVoltage: toDouble(json['battery_voltage']),
      batteryPercentage: toInt(json['battery_percentage']),
      difficultyDeg: toInt(json['difficulty_deg']),
      // Device sends shortened field names: t_patt, t_next, t_elap, t_rem
      // Also check for full names for backward compatibility
      therapyPattern:
          (json['t_patt'] ?? json['therapy_pattern'])?.toString() ?? '',
      therapyNextPattern:
          (json['t_next'] ?? json['therapy_next_pattern'])?.toString() ?? '',
      therapyElapsedSeconds: toInt(
        json['t_elap'] ?? json['therapy_elapsed_sec'],
      ),
      therapyRemainingSeconds: toInt(
        json['t_rem'] ?? json['therapy_remaining_sec'],
      ),
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
        'battery=${batteryVoltage.toStringAsFixed(2)}V ($batteryPercentage%), '
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
  final isAutoConnectionAttempt = ValueNotifier<bool>(false);
  final currentReading = ValueNotifier<PostureReading?>(null);

  BluetoothDevice? _device;
  BluetoothDevice? get device => _device;
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
  static const int _maxRetries = 1;
  static const Duration _connectionTimeout = Duration(seconds: 12);
  static const Duration _serviceDiscoveryTimeout = Duration(seconds: 8);
  static const Duration _defaultScanTimeout = Duration(seconds: 3);

  bool get _isAndroid12OrAbove {
    if (!Platform.isAndroid) {
      return false;
    }

    // SDK 31 (Android 12) introduced runtime BLUETOOTH_SCAN/CONNECT permissions.
    return (int.tryParse(Platform.operatingSystemVersion) ?? 0) >= 31;
  }

  // Persistent storage keys
  static const String _keyHasEverConnected = 'bluetooth_has_ever_connected';
  static const String _keyLastConnectedDeviceId =
      'bluetooth_last_connected_device_id';
  static const MethodChannel _bondChannel = MethodChannel(
    'com.correctv1.bluetooth/unpair',
  );

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
  double get currentBatteryVoltage =>
      currentReading.value?.batteryVoltage ?? 0.0;
  int get currentBatteryPercentage =>
      currentReading.value?.batteryPercentage ?? 0;
  int get currentDifficultyDeg => currentReading.value?.difficultyDeg ?? 25;
  String get currentTherapyPattern =>
      currentReading.value?.therapyPattern ?? '';
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

  /// Sends the current phone date/time and timezone to the device.
  /// Firmware prints the received time as local date/time in the Serial monitor.
  Future<bool> sendDateTime() async {
    if (connectionStatus.value != DeviceConnectionStatus.connected) {
      return false;
    }
    final now = DateTime.now();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final tzOffsetSeconds = now.timeZoneOffset.inSeconds;
    return _writeTextCommand('TIME=$epochSeconds;TZ=$tzOffsetSeconds');
  }

  Future<bool> sendCalibrationStart() async {
    if (connectionStatus.value != DeviceConnectionStatus.connected) {
      return false;
    }

    // Single command - firmware handles CALIBRATE=START, CALIBRATION=START, ACTION=CALIBRATE
    return _writeTextCommand('CALIBRATION=START');
  }

  Future<bool> sendCalibrationCancel() async {
    if (connectionStatus.value != DeviceConnectionStatus.connected) {
      return false;
    }

    return _writeTextCommand('CALIBRATION=CANCEL');
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

    // Don't auto-connect if user manually disconnected (only during current session)
    // Note: This flag is reset to false when app starts, so it only blocks during the same session
    if (isAutoConnect && _userInitiatedDisconnect) {
      debugPrint(
        'CONNECT: Skipping auto-connect - user manually disconnected during this session',
      );
      return;
    }

    // Reset retry count for new connection attempt
    if (connectionStatus.value == DeviceConnectionStatus.disconnected) {
      _connectionRetryCount = 0;
    }

    _isConnecting = true;
    connectionStatus.value = DeviceConnectionStatus.connecting;
    isAutoConnectionAttempt.value = isAutoConnect;

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
        throw Exception(
          'Bluetooth is not enabled. Please enable Bluetooth and try again.',
        );
      }

      // Clean up any existing scan before starting new one
      await _cleanupScan();

      final preferredDeviceId = await _loadLastConnectedDeviceId();
      final device = await _scanForDevice(
        preferredRemoteId: preferredDeviceId,
        preferPairedDevice: isAutoConnect,
        prioritizePreferredDevice: false,
        requirePairedDevice: isAutoConnect,
        timeout: _defaultScanTimeout,
      );
      if (device == null) {
        debugPrint('Device not found - scan returned null');
        _isConnecting = false;
        _connectionTimeoutTimer?.cancel();
        connectionStatus.value = DeviceConnectionStatus.disconnected;

        // Retry connection if we haven't exceeded max retries
        if (_connectionRetryCount < _maxRetries && !isAutoConnect) {
          _connectionRetryCount++;
          debugPrint(
            'Retrying connection (attempt $_connectionRetryCount/$_maxRetries)...',
          );
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
      var isPaired = await _isDevicePaired(_device!);
      debugPrint('Device is paired: $isPaired');
      isAutoConnectionAttempt.value = isPaired;

      // For first-time devices, ask Android to create a bond before connection.
      if (!isPaired) {
        final pairingCompleted = await _requestPairing(_device!);
        if (pairingCompleted) {
          isPaired = true;
          debugPrint('Pairing completed successfully before connect');
        } else {
          debugPrint(
            'Pairing request was not completed, continuing with connection attempt',
          );
        }
      }

      // Check if already connected
      BluetoothConnectionState currentState = await _device!
          .connectionState
          .first
          .timeout(const Duration(seconds: 2));
      debugPrint('Current connection state: $currentState');

      bool needsConnection = true;
      if (currentState == BluetoothConnectionState.connected) {
        debugPrint('Device already connected, verifying connection...');
        // Verify the connection is actually working
        if (await _verifyConnection()) {
          debugPrint('Connection verified, setting up services...');
          needsConnection = false; // Already connected and verified
        } else {
          debugPrint(
            'Connection state says connected but verification failed, reconnecting...',
          );
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

      if (needsConnection &&
          currentState != BluetoothConnectionState.connected) {
        // flutter_blue_plus asserts when autoConnect=true with the default MTU flow.
        // We still do startup reconnects by explicitly calling connect() from app lifecycle,
        // but keep the native connect call as a direct connect.
        const bool shouldAutoConnect = false;
        debugPrint(
          'Connecting to device (autoConnect: $shouldAutoConnect, startupAttempt: $isAutoConnect, isPaired: $isPaired, userDisconnected: $_userInitiatedDisconnect)...',
        );

        try {
          await _device!.connect(
            timeout: const Duration(seconds: 8),
            autoConnect: shouldAutoConnect,
          );
          debugPrint('Connect call completed, waiting for connection state...');

          // Wait for connection to be established with timeout
          await _device!.connectionState
              .where((state) => state == BluetoothConnectionState.connected)
              .first
              .timeout(const Duration(seconds: 8));
          debugPrint('Device connected successfully');

          // Small delay to ensure connection is stable
          await Future.delayed(const Duration(milliseconds: 300));

          // Reset user initiated disconnect flag on successful connection
          _userInitiatedDisconnect = false;
        } catch (e) {
          debugPrint('Connection failed: $e');
          final deviceAfterError = _device;
          final stateAfterError = deviceAfterError == null
              ? BluetoothConnectionState.disconnected
              : await deviceAfterError.connectionState.first.timeout(
                  const Duration(seconds: 2),
                  onTimeout: () => BluetoothConnectionState.disconnected,
                );
          debugPrint('Connection state after error: $stateAfterError');

          // Retry if we haven't exceeded max retries
          if (_connectionRetryCount < _maxRetries && !isAutoConnect) {
            _connectionRetryCount++;
            debugPrint(
              'Retrying connection after failure (attempt $_connectionRetryCount/$_maxRetries)...',
            );
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
          debugPrint(
            'Retrying service discovery (attempt $_connectionRetryCount/$_maxRetries)...',
          );
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

      // Sync phone time to device immediately after every successful connection.
      sendDateTime().then((sent) {
        debugPrint(sent ? 'DateTime synced to device' : 'DateTime sync failed');
      });

      // Save connection state: user has connected and not manually disconnected
      if (!isAutoConnect) {
        // This is a manual connection, save state
        await _saveConnectionState(
          hasEverConnected: true,
          userManuallyDisconnected: false,
          lastConnectedDeviceId: _device?.remoteId.toString(),
        );
        debugPrint(
          'Saved connection state: hasEverConnected=true, userManuallyDisconnected=false',
        );
      } else {
        // Auto-connect succeeded, clear manual disconnect flag
        await _saveConnectionState(
          userManuallyDisconnected: false,
          lastConnectedDeviceId: _device?.remoteId.toString(),
        );
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
      if (_connectionRetryCount < _maxRetries &&
          !isAutoConnect &&
          !_userInitiatedDisconnect) {
        _connectionRetryCount++;
        debugPrint(
          'Retrying connection after error (attempt $_connectionRetryCount/$_maxRetries)...',
        );
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

    final deviceToDisconnect = _device;

    if (userInitiated) {
      _userInitiatedDisconnect = true;
      // Manual disconnect should fully forget the device and stop auto-connect.
      await _saveConnectionState(
        userManuallyDisconnected: true,
        clearLastConnectedDeviceId: true,
      );
      debugPrint('User initiated disconnect - cleared remembered device state');
    }

    // Clean up subscriptions first
    _buffer = '';
    await _notifySubscription?.cancel();
    _notifySubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    // Clean up scan
    await _cleanupScan();

    if (deviceToDisconnect != null) {
      try {
        // Disconnect device with timeout first; unpairing is more reliable once link is closed.
        await deviceToDisconnect.disconnect().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Disconnect timeout, forcing cleanup');
          },
        );
      } catch (e) {
        debugPrint('Error during disconnect: $e');
        // Continue with cleanup even if disconnect fails
      }

      if (userInitiated) {
        try {
          await _unpairDevice(deviceToDisconnect);
          debugPrint('Device unpaired successfully after manual disconnect');
        } catch (e) {
          debugPrint('Failed to unpair device after manual disconnect: $e');
        }
      }
    }

    _device = null;
    _notifyCharacteristic = null;
    currentReading.value = null; // Clear current reading on disconnect
    connectionStatus.value = DeviceConnectionStatus.disconnected;
    isAutoConnectionAttempt.value = false;

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
    isAutoConnectionAttempt.dispose();
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

  Future<bool> hasBondedTargetDevice() async {
    try {
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      return bondedDevices.any(
        (device) => _matchesTargetDeviceName(device.platformName),
      );
    } catch (e) {
      debugPrint('Error checking bonded target devices: $e');
      return false;
    }
  }

  Future<bool> hasUnpairedTargetDeviceNearby({
    Duration timeout = _defaultScanTimeout,
  }) async {
    final device = await _scanForDevice(
      preferPairedDevice: false,
      prioritizePreferredDevice: false,
      requirePairedDevice: false,
      timeout: timeout,
    );
    if (device == null) {
      return false;
    }
    return !(await _isDevicePaired(device));
  }

  Future<bool> _requestPairing(BluetoothDevice device) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      // iOS handles BLE pairing implicitly based on characteristic permissions.
      return true;
    }

    try {
      if (await _isDevicePaired(device)) {
        return true;
      }

      final address = device.remoteId.toString();
      debugPrint('Requesting bond for device: $address');
      final started = await _bondChannel.invokeMethod<bool>('createBond', {
        'address': address,
      });

      if (started != true) {
        debugPrint('createBond did not start successfully');
        return false;
      }

      // Wait for Android bond state to settle.
      for (int attempt = 0; attempt < 10; attempt++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await _isDevicePaired(device)) {
          return true;
        }
      }

      debugPrint('Pairing request timed out without bonded state');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Platform exception during pairing: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error during pairing request: $e');
      return false;
    }
  }

  Future<void> _unpairDevice(BluetoothDevice device) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final address = device.remoteId.toString();
    if (address.isEmpty) {
      return;
    }

    await _bondChannel.invokeMethod<bool>('removeBond', {'address': address});
  }

  Future<bool> _ensurePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // iOS handles permissions differently
    }

    debugPrint('Checking required permissions...');

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

    // Location permission is only required pre-Android 12 for BLE scanning.
    if (!_isAndroid12OrAbove) {
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
    }

    debugPrint('All required permissions granted');
    return true;
  }

  bool _matchesTargetDeviceName(String candidateName) {
    final normalizedName = candidateName.trim().toLowerCase();
    final normalizedPrefix = _deviceNamePrefix.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return false;
    }
    return normalizedName == normalizedPrefix ||
        normalizedName.startsWith(normalizedPrefix);
  }

  Future<BluetoothDevice?> _scanForDevice({
    String? preferredRemoteId,
    bool preferPairedDevice = true,
    bool prioritizePreferredDevice = true,
    bool requirePairedDevice = false,
    Duration timeout = _defaultScanTimeout,
  }) async {
    final normalizedPreferredId = preferredRemoteId?.toLowerCase();

    // First, prefer devices that are already connected.
    final connectedDevices = FlutterBluePlus.connectedDevices;
    BluetoothDevice? connectedMatch;
    for (final device in connectedDevices) {
      final deviceId = device.remoteId.toString().toLowerCase();
      if (normalizedPreferredId != null && deviceId == normalizedPreferredId) {
        debugPrint('Found preferred connected device: ${device.platformName}');
        return device;
      }
      if (_matchesTargetDeviceName(device.platformName)) {
        connectedMatch ??= device;
      }
    }
    if (connectedMatch != null) {
      debugPrint(
        'Found matching connected device: ${connectedMatch.platformName}',
      );
      return connectedMatch;
    }

    // Build bonded device index for paired-first selection.
    final bondedDeviceIds = <String>{};
    try {
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      for (final device in bondedDevices) {
        if (_matchesTargetDeviceName(device.platformName)) {
          bondedDeviceIds.add(device.remoteId.toString().toLowerCase());
        }
      }
      debugPrint('Matching bonded devices found: ${bondedDeviceIds.length}');
    } catch (e) {
      debugPrint('Error loading bonded devices: $e');
    }

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

    final candidates = <String, _ScanCandidate>{};
    final serviceUuidLower = _kServiceUuid.toLowerCase();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final hasServiceMatch = result.advertisementData.serviceUuids.any(
            (uuid) => uuid.toString().toLowerCase() == serviceUuidLower,
          );
          // Require AlignEye service UUID to be present so we only consider
          // genuine AlignEye devices during scanning.
          if (!hasServiceMatch) {
            continue;
          }

          final remoteId = result.device.remoteId.toString().toLowerCase();
          final isBonded = bondedDeviceIds.contains(remoteId);
          final existing = candidates[remoteId];

          if (existing == null || result.rssi > existing.rssi) {
            candidates[remoteId] = _ScanCandidate(
              device: result.device,
              rssi: result.rssi,
              isBonded: isBonded,
            );
          }
        }
      },
      onError: (error) {
        debugPrint('Scan results stream error: $error');
      },
    );

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      debugPrint('ERROR: Failed to start scan: $e');
      debugPrint('Please verify Bluetooth + Location permissions on Android');
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      return null;
    }

    await Future.delayed(timeout + const Duration(milliseconds: 250));
    await _cleanupScan();

    if (candidates.isEmpty) {
      debugPrint('Scan finished with no matching candidates');
      return null;
    }

    if (prioritizePreferredDevice &&
        normalizedPreferredId != null &&
        candidates.containsKey(normalizedPreferredId)) {
      final preferred = candidates[normalizedPreferredId]!;
      debugPrint(
        'Selected preferred known device: ${preferred.device.platformName} (RSSI ${preferred.rssi})',
      );
      return preferred.device;
    }

    if (preferPairedDevice) {
      final pairedCandidates = candidates.values
          .where((candidate) => candidate.isBonded)
          .toList();
      if (pairedCandidates.isNotEmpty) {
        pairedCandidates.sort((a, b) => b.rssi.compareTo(a.rssi));
        final bestPaired = pairedCandidates.first;
        debugPrint(
          'Selected paired candidate: ${bestPaired.device.platformName} (RSSI ${bestPaired.rssi})',
        );
        return bestPaired.device;
      }
    }

    if (requirePairedDevice) {
      debugPrint(
        'Auto-connect requires a paired device, but no paired candidates are currently available',
      );
      return null;
    }

    final allCandidates = candidates.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final nearest = allCandidates.first;
    debugPrint(
      'Selected nearest candidate: ${nearest.device.platformName} (RSSI ${nearest.rssi})',
    );
    return nearest.device;
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
      _saveConnectionState(
        userManuallyDisconnected: false,
        lastConnectedDeviceId: _device?.remoteId.toString(),
      );

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
      throw lastError ??
          Exception('Failed to discover services after 3 attempts');
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
        debugPrint(
          'Failed to enable notifications (attempt ${attempt + 1}/3): $e',
        );

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
          debugPrint(
            'Connection verification: characteristic exists but notifications not enabled yet',
          );
          // This is okay - we'll enable them during setup
          return true; // Connection is good, just need to set up notifications
        }
        debugPrint(
          'Connection verification passed - device connected and notifications enabled',
        );
        return true;
      } else {
        debugPrint(
          'Connection verification passed - device connected, will set up services',
        );
        return true; // Device is connected, we just need to set up services
      }
    } catch (e) {
      debugPrint('Connection verification error: $e');
      return false;
    }
  }

  /// Attempts to auto-connect to a paired device if available
  /// This should be called on app start or when appropriate
  /// Always attempts to connect when app opens, regardless of previous connection history
  Future<void> tryAutoConnect() async {
    // Reset user initiated disconnect flag on app start
    // This ensures auto-connect always happens when app opens
    _userInitiatedDisconnect = false;
    debugPrint(
      '=== AUTO-CONNECT: App started - resetting user disconnect flag, attempting auto-connect ===',
    );

    // Load persistent state (but don't use it to block auto-connect on app start)
    await _loadConnectionState();

    // Note: We don't check _userInitiatedDisconnect here because we just reset it
    // The flag will be set if user disconnects during this session

    if (connectionStatus.value != DeviceConnectionStatus.disconnected) {
      debugPrint(
        'AUTO-CONNECT: Already connected or connecting, skipping auto-connect',
      );
      return;
    }

    // Wait a bit for the app to fully initialize and Bluetooth to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if Bluetooth is supported
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        debugPrint('AUTO-CONNECT: Bluetooth is not supported on this device');
        return;
      }

      // Check if Bluetooth adapter is ready
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint(
            'AUTO-CONNECT: Timeout waiting for Bluetooth adapter state',
          );
          return BluetoothAdapterState.unknown;
        },
      );

      if (adapterState != BluetoothAdapterState.on) {
        debugPrint(
          'AUTO-CONNECT: Bluetooth adapter is not ON (state: $adapterState), cannot auto-connect',
        );
        return;
      }

      debugPrint(
        'AUTO-CONNECT: Bluetooth is ready, starting connection flow...',
      );
      // Force reset again right before connecting to ensure session flag never blocks startup.
      _userInitiatedDisconnect = false;
      // Startup flow only targets already paired devices. If none are available,
      // UI can prompt the user to manually connect to the nearest device.
      await connect(isAutoConnect: true);
      debugPrint('AUTO-CONNECT: Connection attempt completed');
    } catch (e, stackTrace) {
      debugPrint('AUTO-CONNECT: Failed with error: $e');
      debugPrint('AUTO-CONNECT: Stack trace: $stackTrace');
      // Don't throw - auto-connect failures should be silent
    }
  }

  /// Save connection state to persistent storage
  /// Note: We don't persist userManuallyDisconnected anymore
  /// because we want auto-connect to always happen on app start
  Future<void> _saveConnectionState({
    bool? hasEverConnected,
    bool? userManuallyDisconnected,
    String? lastConnectedDeviceId,
    bool clearLastConnectedDeviceId = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (hasEverConnected != null) {
        await prefs.setBool(_keyHasEverConnected, hasEverConnected);
      }
      if (clearLastConnectedDeviceId) {
        await prefs.remove(_keyLastConnectedDeviceId);
      } else if (lastConnectedDeviceId != null) {
        final normalized = lastConnectedDeviceId.trim();
        if (normalized.isEmpty) {
          await prefs.remove(_keyLastConnectedDeviceId);
        } else {
          await prefs.setString(_keyLastConnectedDeviceId, normalized);
        }
      }
      // Don't persist userManuallyDisconnected - it's session-only now
      // Just update the in-memory flag for the current session
      if (userManuallyDisconnected != null) {
        _userInitiatedDisconnect = userManuallyDisconnected;
      }
    } catch (e) {
      debugPrint('Error saving connection state: $e');
    }
  }

  /// Load connection state from persistent storage
  /// Note: We don't load _userInitiatedDisconnect from storage anymore
  /// because we want auto-connect to always happen on app start
  Future<void> _loadConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // We still load hasEverConnected to know if user has connected before
      final hasEverConnected = prefs.getBool(_keyHasEverConnected) ?? false;
      final lastConnectedDeviceId = prefs.getString(_keyLastConnectedDeviceId);
      debugPrint(
        'Loaded connection state: hasEverConnected=$hasEverConnected, lastConnectedDeviceId=$lastConnectedDeviceId',
      );
      // Don't load userManuallyDisconnected - it's session-only now
    } catch (e) {
      debugPrint('Error loading connection state: $e');
    }
  }

  Future<String?> _loadLastConnectedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_keyLastConnectedDeviceId)?.trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } catch (e) {
      debugPrint('Error loading last connected device id: $e');
      return null;
    }
  }
}
