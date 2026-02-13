import 'dart:async';
import 'dart:math' as math;

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:correctv1/arogyam/arogyam_page.dart';
import 'package:correctv1/discover/discover_page.dart';
import 'package:correctv1/settings/settings_page.dart';
import 'package:correctv1/components/nav_bar.dart';
import 'package:correctv1/calibration/calibration_page.dart';

const _kPagePadding = EdgeInsets.fromLTRB(24, 48, 24, 100);
const _kSectionSpacing = SizedBox(height: 24);
const _kHeaderSpacing = SizedBox(height: 32);
const _kInnerSpacing = SizedBox(height: 16);
const _kPrimaryBlue = Color(0xFF2563EB);
const _kMutedText = Color(0xFF94A3B8);
const _kPrimaryGreen = Color(0xFF10B981);
const _kBadPostureRed = Color(0xFFEF4444);
const _kDashboardBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEFF6FF), Colors.white, Color(0xFFFAF5FF)],
);

enum _ModeControlType { track, posture, therapy }

enum _PostureTimingType { instant, delayed, automatic }

const _kDifficultyOptions = [15, 20, 25, 30, 35, 40, 45, 50];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late PageController _pageController;
  int _currentIndex = 0;
  final BluetoothServiceManager _bluetoothManager = BluetoothServiceManager();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Initialize Bluetooth connection when HomePage is created
    _bluetoothManager.initialize();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Note: We don't shutdown the Bluetooth manager here to maintain connection
    // The connection will persist across page navigations
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboard(
        onNavigateToPage: _onItemTapped,
        deviceService: _bluetoothManager.deviceService,
      ),
      const ArogyamPage(),
      const DiscoverPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      extendBody: true,
      // The background is handled inside HomeDashboard for the gradient
      // But for other pages we might need a background.
      // For now, let's keep the Scaffold background simple or transparent if pages handle it.
      // The React code showed a full page gradient for Home.
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const BouncingScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: ModernNavBar(
        selectedIndex: _currentIndex,
        onItemSelected: _onItemTapped,
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final ValueChanged<int> onNavigateToPage;
  final AlignEyeDeviceService deviceService;

  const HomeDashboard({
    super.key,
    required this.onNavigateToPage,
    required this.deviceService,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  late final AlignEyeDeviceService _deviceService;
  final BluetoothServiceManager _bluetoothManager = BluetoothServiceManager();
  StreamSubscription<PostureReading>? _readingSubscription;

  double _postureAngle = 0;
  String _postureStatus = 'Waiting for data';
  bool _isBadPosture = false;
  String _recentValues = 'No data yet';
  int _batteryLevel = 0;
  _ModeControlType _selectedMode = _ModeControlType.track;
  _PostureTimingType _selectedPostureTiming = _PostureTimingType.instant;
  int _selectedDifficulty = 25;
  int _therapyDurationMinutes = 10;
  Timer? _therapyCountdownTimer;
  int _therapyRemainingSeconds = 0;
  String _currentTherapyPattern = 'Waiting for therapy';
  String _nextTherapyPattern = 'Waiting for therapy';

  static const List<_QuickMode> _quickModes = [
    _QuickMode(
      title: 'Tracking',
      icon: Icons.graphic_eq,
      gradient: [Color(0xFF60A5FA), Color(0xFF06B6D4)],
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Training',
      icon: Icons.flash_on,
      gradient: [Color(0xFFC084FC), Color(0xFFEC4899)],
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Therapy',
      icon: Icons.favorite,
      gradient: [Color(0xFFFB7185), Color(0xFFEF4444)],
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Meditate',
      icon: Icons.self_improvement,
      gradient: [Color(0xFF818CF8), Color(0xFF3B82F6)],
      targetIndex: 1,
    ),
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _deviceService = widget.deviceService;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();

    _readingSubscription = _deviceService.readings.listen((reading) {
      if (!mounted) return;
      final isTherapyMode = reading.mode.trim().toUpperCase() == 'THERAPY';
      final currentPattern = reading.therapyPattern.trim();
      final nextPattern = reading.therapyNextPattern.trim();
      final reportedRemainingSec = reading.therapyRemainingSeconds;
      setState(() {
        _postureAngle = reading.angle;
        _isBadPosture = reading.isBadPosture;
        _postureStatus = reading.isBadPosture ? 'Bad posture' : 'Good posture';
        _recentValues = reading.toCompactString();
        _batteryLevel = reading.batteryPercentage.clamp(0, 100);
        _selectedMode = _modeFromDevice(reading.mode);
        _selectedPostureTiming = _postureTimingFromDevice(reading.subMode);
        _therapyDurationMinutes = _therapyMinutesFromDevice(reading.subMode);
        if (_kDifficultyOptions.contains(reading.difficultyDeg)) {
          _selectedDifficulty = reading.difficultyDeg;
        }
        if (isTherapyMode && reportedRemainingSec > 0) {
          // Align app countdown with device state after late BLE connection.
          _therapyCountdownTimer?.cancel();
          _therapyRemainingSeconds = reportedRemainingSec;
        } else if (!isTherapyMode) {
          _therapyCountdownTimer?.cancel();
          _therapyRemainingSeconds = 0;
        }
        _currentTherapyPattern = isTherapyMode
            ? (currentPattern.isEmpty ? 'Preparing pattern...' : currentPattern)
            : 'Waiting for therapy';
        _nextTherapyPattern = isTherapyMode
            ? (nextPattern.isEmpty ? 'Upcoming pattern...' : nextPattern)
            : 'Waiting for therapy';
      });
    });
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _therapyCountdownTimer?.cancel();
    // Don't dispose the device service here - it's managed by BluetoothServiceManager
    // unawaited(_deviceService.dispose());
    _controller.dispose();
    super.dispose();
  }

  bool get _isTherapyCountdownRunning =>
      _selectedMode == _ModeControlType.therapy &&
      ((_therapyCountdownTimer?.isActive ?? false) ||
          _therapyRemainingSeconds > 0);

  void _startTherapyCountdown(int minutes) {
    _therapyCountdownTimer?.cancel();
    setState(() {
      _therapyRemainingSeconds = minutes * 60;
    });

    _therapyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_therapyRemainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _therapyRemainingSeconds = 0;
        });
        return;
      }
      setState(() {
        _therapyRemainingSeconds -= 1;
      });
    });
  }

  void _stopTherapyCountdown({bool clearTime = false}) {
    _therapyCountdownTimer?.cancel();
    if (clearTime) {
      setState(() {
        _therapyRemainingSeconds = 0;
      });
    }
  }

  Future<void> _handleDeviceStatusTap() async {
    final currentStatus = _deviceService.connectionStatus.value;
    if (currentStatus == DeviceConnectionStatus.connecting) {
      return;
    }

    if (currentStatus == DeviceConnectionStatus.connected) {
      final shouldDisconnect = await _confirmDisconnect();
      if (shouldDisconnect == true) {
        // User initiated disconnect - will unpair device and prevent auto-reconnect
        await _deviceService.disconnect(userInitiated: true);
      }
      return;
    }

    try {
      // Use the manager's connect method to ensure proper connection handling
      await _bluetoothManager.connect();
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString();
      String dialogTitle = 'Connection Failed';
      String dialogContent = 'Could not connect to device.';

      if (errorMessage.contains('permission') ||
          errorMessage.contains('Permission')) {
        dialogTitle = 'Permission Required';
        dialogContent =
            'Bluetooth scanning requires Location permission.\n\n'
            'Please grant Location permission:\n\n'
            '1. Tap "Open Settings" below\n'
            '2. Go to Permissions → Location\n'
            '3. Select "Allow" or "While using the app"\n'
            '4. Return to the app and try again';
      } else if (errorMessage.contains('not found')) {
        dialogContent =
            'Device "correct v1" not found.\n\n'
            'Please ensure:\n\n'
            '1. Device is powered on\n'
            '2. Device is within range\n'
            '3. Device is advertising\n\n'
            'If you can see the device in Bluetooth settings, try pairing it manually first.';
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(dialogTitle),
            content: Text(dialogContent),
            actions: [
              if (errorMessage.contains('permission') ||
                  errorMessage.contains('Permission'))
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Open app settings
                    await openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Check if connection failed after a delay
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    if (_deviceService.connectionStatus.value ==
        DeviceConnectionStatus.disconnected) {
      // Connection failed for other reasons
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Failed'),
            content: const Text(
              'Could not connect to device. Please ensure:\n\n'
              '1. Device "correct v1" is powered on\n'
              '2. Device is within range\n'
              '3. Device is not connected to another device\n\n'
              'If you can see the device in Bluetooth settings, try pairing it manually first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<bool?> _confirmDisconnect() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disconnect device?'),
          content: const Text(
            'Disconnecting will stop real-time posture updates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncModeControlToDevice({
    required _ModeControlType mode,
    required _PostureTimingType postureTiming,
    required int therapyDurationMinutes,
    required int difficultyDegrees,
  }) async {
    final modeLabel = switch (mode) {
      _ModeControlType.track => 'TRACKING',
      _ModeControlType.posture => 'TRAINING',
      _ModeControlType.therapy => 'THERAPY',
    };
    final timingLabel = switch (postureTiming) {
      _PostureTimingType.instant => 'INSTANT',
      _PostureTimingType.delayed => 'DELAYED',
      _PostureTimingType.automatic => 'AUTOMATIC',
    };

    await _deviceService.sendModeControl(
      mode: modeLabel,
      postureTiming: timingLabel,
      therapyDurationMinutes: therapyDurationMinutes,
      difficultyDegrees: difficultyDegrees,
    );
  }

  _ModeControlType _modeFromDevice(String mode) {
    final normalized = mode.trim().toUpperCase();
    if (normalized == 'TRAINING' || normalized == 'POSTURE') {
      return _ModeControlType.posture;
    }
    if (normalized == 'THERAPY') {
      return _ModeControlType.therapy;
    }
    return _ModeControlType.track;
  }

  _PostureTimingType _postureTimingFromDevice(String subMode) {
    final normalized = subMode.trim().toUpperCase();
    if (normalized == 'DELAYED') {
      return _PostureTimingType.delayed;
    }
    if (normalized == 'AUTOMATIC') {
      return _PostureTimingType.automatic;
    }
    return _PostureTimingType.instant;
  }

  int _therapyMinutesFromDevice(String subMode) {
    final minutes = int.tryParse(subMode.split(' ').first.trim());
    if (minutes == 5 || minutes == 10 || minutes == 20) {
      return minutes!;
    }
    return _therapyDurationMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _kDashboardBackground),
      child: SafeArea(
        bottom: false, // Let content flow behind navbar
        child: SingleChildScrollView(
          padding: _kPagePadding, // Extra bottom padding for navbar
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 0,
                child: const _DashboardHeader(),
              ),
              _kHeaderSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 100,
                child: ValueListenableBuilder<DeviceConnectionStatus>(
                  valueListenable: _deviceService.connectionStatus,
                  builder: (context, connectionStatus, child) {
                    return _DeviceStatusCard(
                      status: connectionStatus,
                      batteryLevel: _batteryLevel,
                      onTap: _handleDeviceStatusTap,
                    );
                  },
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 200,
                child: _PostureGaugeCard(
                  postureAngle: _postureAngle,
                  postureStatus: _postureStatus,
                  isBadPosture: _isBadPosture,
                  controller: _controller,
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 300,
                child: _ModeControlCard(
                  selectedMode: _selectedMode,
                  selectedPostureTiming: _selectedPostureTiming,
                  selectedDifficulty: _selectedDifficulty,
                  therapyDurationMinutes: _therapyDurationMinutes,
                  therapyRemainingSeconds: _therapyRemainingSeconds,
                  therapyCountdownRunning: _isTherapyCountdownRunning,
                  currentTherapyPattern: _currentTherapyPattern,
                  nextTherapyPattern: _nextTherapyPattern,
                  onModeSelected: (mode) {
                    setState(() => _selectedMode = mode);
                    if (mode == _ModeControlType.therapy) {
                      _startTherapyCountdown(_therapyDurationMinutes);
                    } else {
                      _stopTherapyCountdown();
                    }
                    unawaited(
                      _syncModeControlToDevice(
                        mode: mode,
                        postureTiming: _selectedPostureTiming,
                        therapyDurationMinutes: _therapyDurationMinutes,
                        difficultyDegrees: _selectedDifficulty,
                      ),
                    );
                  },
                  onCalibratePressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => CalibrationPage(
                          deviceService: _deviceService,
                          autoStart: true,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    if (result == true) {
                      widget.onNavigateToPage(1);
                    }
                  },
                  onPostureTimingSelected: (timing) {
                    setState(() => _selectedPostureTiming = timing);
                    unawaited(
                      _syncModeControlToDevice(
                        mode: _selectedMode,
                        postureTiming: timing,
                        therapyDurationMinutes: _therapyDurationMinutes,
                        difficultyDegrees: _selectedDifficulty,
                      ),
                    );
                  },
                  onDifficultySelected: (difficulty) {
                    setState(() => _selectedDifficulty = difficulty);
                    unawaited(
                      _syncModeControlToDevice(
                        mode: _selectedMode,
                        postureTiming: _selectedPostureTiming,
                        therapyDurationMinutes: _therapyDurationMinutes,
                        difficultyDegrees: difficulty,
                      ),
                    );
                  },
                  onTherapyDurationSelected: (minutes) {
                    setState(() => _therapyDurationMinutes = minutes);
                    if (_selectedMode == _ModeControlType.therapy) {
                      _startTherapyCountdown(minutes);
                    }
                    unawaited(
                      _syncModeControlToDevice(
                        mode: _selectedMode,
                        postureTiming: _selectedPostureTiming,
                        therapyDurationMinutes: minutes,
                        difficultyDegrees: _selectedDifficulty,
                      ),
                    );
                  },
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 400,
                child: _QuickModesSection(
                  modes: _quickModes,
                  onViewAll: () => widget.onNavigateToPage(1),
                  onModeTap: widget.onNavigateToPage,
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 700,
                child: const _StatsSummaryCard(
                  items: [
                    _StatItemData(value: '87%', label: 'Good Posture'),
                    _StatItemData(value: '6.5h', label: 'Active Time'),
                  ],
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 800,
                child: _RecentValuesCard(recentValues: _recentValues),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaggeredFadeSlide extends StatelessWidget {
  final Animation<double> controller;
  final int delayMs;
  final Widget child;

  const _StaggeredFadeSlide({
    required this.controller,
    required this.delayMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final start = delayMs / 1000.0;
        final value = Curves.easeOut.transform(
          ((controller.value - start) / 0.6).clamp(0.0, 1.0),
        );

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      ],
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final DeviceConnectionStatus status;
  final int batteryLevel;
  final VoidCallback onTap;

  const _DeviceStatusCard({
    required this.status,
    required this.batteryLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = status == DeviceConnectionStatus.connected;
    final isConnecting = status == DeviceConnectionStatus.connecting;
    final statusText = isConnecting
        ? 'Connecting...'
        : isConnected
        ? 'Connected'
        : 'Disconnected';
    final statusColor = isConnecting ? const Color(0xFFF59E0B) : _kPrimaryBlue;
    final iconColor = isConnected
        ? _kPrimaryBlue
        : isConnecting
        ? const Color(0xFFF59E0B)
        : Colors.grey.shade400;
    final batteryTierColor = _batteryTierColor(batteryLevel);
    final batteryTextColor = _batteryTierTextColor(batteryLevel);

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0ECFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.bluetooth, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Status',
                          style: TextStyle(
                            color: _kMutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            statusText,
                            key: ValueKey(statusText),
                            style: TextStyle(
                              color: isConnecting ? statusColor : iconColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isConnecting) ...[
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: batteryTierColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.battery_full,
                            color: batteryTextColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$batteryLevel%',
                            style: TextStyle(
                              color: batteryTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _batteryTierColor(int level) {
  if (level < 25) {
    return const Color(0xFFFEE2E2);
  }
  if (level < 60) {
    return const Color(0xFFFEF3C7);
  }
  return const Color(0xFFEAFBF1);
}

Color _batteryTierTextColor(int level) {
  if (level < 25) {
    return const Color(0xFFDC2626);
  }
  if (level < 60) {
    return const Color(0xFFF59E0B);
  }
  return _kPrimaryGreen;
}

class _PostureGaugeCard extends StatelessWidget {
  final double postureAngle;
  final String postureStatus;
  final bool isBadPosture;
  final Animation<double> controller;

  const _PostureGaugeCard({
    required this.postureAngle,
    required this.postureStatus,
    required this.isBadPosture,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isBadPosture ? _kBadPostureRed : _kPrimaryGreen;
    final clampedAngle = postureAngle.clamp(-90.0, 90.0);

    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Real-time Posture',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              height: 220,
              width: 220,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(end: clampedAngle),
                builder: (context, value, child) {
                  return CustomPaint(
                    painter: PostureGaugePainter(
                      angle: value,
                      accentColor: accentColor,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          _StaggeredFadeSlide(
            controller: controller,
            delayMs: 500,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withValues(alpha: 0.9), accentColor],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  'Posture Status: $postureStatus',
                  key: ValueKey(postureStatus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentValuesCard extends StatelessWidget {
  final String recentValues;

  const _RecentValuesCard({required this.recentValues});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Values',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recentValues,
            style: const TextStyle(
              fontSize: 12,
              color: _kMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _SurfaceCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModeControlCard extends StatelessWidget {
  final _ModeControlType selectedMode;
  final _PostureTimingType selectedPostureTiming;
  final int selectedDifficulty;
  final int therapyDurationMinutes;
  final int therapyRemainingSeconds;
  final bool therapyCountdownRunning;
  final String currentTherapyPattern;
  final String nextTherapyPattern;
  final ValueChanged<_ModeControlType> onModeSelected;
  final VoidCallback onCalibratePressed;
  final ValueChanged<_PostureTimingType> onPostureTimingSelected;
  final ValueChanged<int> onDifficultySelected;
  final ValueChanged<int> onTherapyDurationSelected;

  const _ModeControlCard({
    required this.selectedMode,
    required this.selectedPostureTiming,
    required this.selectedDifficulty,
    required this.therapyDurationMinutes,
    required this.therapyRemainingSeconds,
    required this.therapyCountdownRunning,
    required this.currentTherapyPattern,
    required this.nextTherapyPattern,
    required this.onModeSelected,
    required this.onCalibratePressed,
    required this.onPostureTimingSelected,
    required this.onDifficultySelected,
    required this.onTherapyDurationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mode Control',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Track/Off',
                  selected: selectedMode == _ModeControlType.track,
                  onTap: () => onModeSelected(_ModeControlType.track),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Posture',
                  selected: selectedMode == _ModeControlType.posture,
                  onTap: () => onModeSelected(_ModeControlType.posture),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Therapy',
                  selected: selectedMode == _ModeControlType.therapy,
                  onTap: () => onModeSelected(_ModeControlType.therapy),
                ),
              ),
            ],
          ),
          if (selectedMode == _ModeControlType.track) ...[
            const SizedBox(height: 16),
            _LabeledControl(
              label: 'Calibrate',
              icon: Icons.tune_rounded,
              child: _IconModeButton(
                icon: Icons.tune_rounded,
                onTap: onCalibratePressed,
                tooltip: 'Calibrate',
              ),
            ),
          ],
          if (selectedMode == _ModeControlType.posture) ...[
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(
                  Icons.accessibility_new_rounded,
                  size: 16,
                  color: _kPrimaryBlue,
                ),
                SizedBox(width: 6),
                Text(
                  'Posture settings',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LabeledControl(
                    label: 'Timing',
                    icon: Icons.av_timer_rounded,
                    child: _DropdownModeButton<_PostureTimingType>(
                      value: selectedPostureTiming,
                      items: _PostureTimingType.values
                          .map(
                            (timing) => DropdownMenuItem<_PostureTimingType>(
                              value: timing,
                              child: Text(_postureTimingLabel(timing)),
                            ),
                          )
                          .toList(),
                      selectedLabelBuilder: _postureTimingCompactLabel,
                      onChanged: (value) {
                        if (value != null) onPostureTimingSelected(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LabeledControl(
                    label: 'Difficulty',
                    icon: Icons.speed_rounded,
                    child: _DropdownModeButton<int>(
                      value: selectedDifficulty,
                      items: _kDifficultyOptions
                          .map(
                            (difficulty) => DropdownMenuItem<int>(
                              value: difficulty,
                              child: Text(
                                difficulty == 25
                                    ? '$difficulty° (default)'
                                    : '$difficulty°',
                              ),
                            ),
                          )
                          .toList(),
                      selectedLabelBuilder: (value) => '$value°',
                      onChanged: (value) {
                        if (value != null) onDifficultySelected(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (selectedMode == _ModeControlType.therapy) ...[
            const SizedBox(height: 16),
            const Text(
              'Therapy duration',
              style: TextStyle(
                color: _kMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: '5 min',
                    selected: therapyDurationMinutes == 5,
                    onTap: () => onTherapyDurationSelected(5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: '10 min',
                    selected: therapyDurationMinutes == 10,
                    onTap: () => onTherapyDurationSelected(10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: '20 min',
                    selected: therapyDurationMinutes == 20,
                    onTap: () => onTherapyDurationSelected(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: therapyCountdownRunning
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: therapyCountdownRunning
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: therapyCountdownRunning
                        ? _kPrimaryBlue
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    therapyCountdownRunning
                        ? 'Countdown: ${_formatCountdown(therapyRemainingSeconds)}'
                        : 'Tap Therapy or duration to start',
                    style: TextStyle(
                      color: therapyCountdownRunning
                          ? _kPrimaryBlue
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TherapyPatternInfo(
                    label: 'Now',
                    pattern: currentTherapyPattern,
                    highlighted: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TherapyPatternInfo(
                    label: 'Next',
                    pattern: nextTherapyPattern,
                    highlighted: false,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _formatCountdown(int totalSeconds) {
  final safeSeconds = math.max(0, totalSeconds);
  final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kPrimaryBlue : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _LabeledControl({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: _kMutedText),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kMutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _IconModeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconModeButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Icon(icon, color: _kPrimaryBlue, size: 20),
        ),
      ),
    );
  }
}

class _TherapyPatternInfo extends StatelessWidget {
  final String label;
  final String pattern;
  final bool highlighted;

  const _TherapyPatternInfo({
    required this.label,
    required this.pattern,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kMutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pattern,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlighted ? _kPrimaryBlue : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownModeButton<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? selectedLabelBuilder;

  const _DropdownModeButton({
    required this.value,
    required this.items,
    required this.onChanged,
    this.selectedLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
            overflow: TextOverflow.ellipsis,
          ),
          selectedItemBuilder: selectedLabelBuilder == null
              ? null
              : (context) => items
                    .map(
                      (item) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selectedLabelBuilder!(item.value as T),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

String _postureTimingLabel(_PostureTimingType timing) {
  switch (timing) {
    case _PostureTimingType.instant:
      return 'Instant';
    case _PostureTimingType.delayed:
      return 'Delayed';
    case _PostureTimingType.automatic:
      return 'Automatic';
  }
}

String _postureTimingCompactLabel(_PostureTimingType timing) {
  switch (timing) {
    case _PostureTimingType.instant:
      return 'Instant';
    case _PostureTimingType.delayed:
      return 'Delayed';
    case _PostureTimingType.automatic:
      return 'Auto';
  }
}

class _QuickModesSection extends StatelessWidget {
  final List<_QuickMode> modes;
  final VoidCallback onViewAll;
  final ValueChanged<int> onModeTap;

  const _QuickModesSection({
    required this.modes,
    required this.onViewAll,
    required this.onModeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Modes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: _kPrimaryBlue,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Row(
                children: [
                  Text('View All'),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ],
        ),
        _kInnerSpacing,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: modes
              .map(
                (mode) => _QuickModeCard(
                  mode: mode,
                  onTap: () => onModeTap(mode.targetIndex),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _QuickModeCard extends StatelessWidget {
  final _QuickMode mode;
  final VoidCallback onTap;

  const _QuickModeCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: mode.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(mode.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                mode.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  final List<_StatItemData> items;

  const _StatsSummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          _kInnerSpacing,
          Row(
            children: [
              Expanded(child: _StatItem(item: items[0])),
              const SizedBox(width: 16),
              Expanded(child: _StatItem(item: items[1])),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final _StatItemData item;

  const _StatItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(fontSize: 12, color: Color(0xFFDBEAFE)),
          ),
        ],
      ),
    );
  }
}

class _QuickMode {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final int targetIndex;

  const _QuickMode({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.targetIndex,
  });
}

class _StatItemData {
  final String value;
  final String label;

  const _StatItemData({required this.value, required this.label});
}

class PostureGaugePainter extends CustomPainter {
  final double angle;
  final Color accentColor;

  PostureGaugePainter({required this.angle, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background ring (full circle)
    paint.color = const Color(0xFFE5E7EB);
    canvas.drawCircle(center, radius, paint);

    // Draw division markers at 0°, 90°, and -90°
    final markerPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw marker at top (0°)
    final topMarker = Offset(center.dx, center.dy - radius);
    canvas.drawLine(
      Offset(topMarker.dx - 8, topMarker.dy),
      Offset(topMarker.dx + 8, topMarker.dy),
      markerPaint,
    );

    // Draw marker at right (90°)
    final rightMarker = Offset(center.dx + radius, center.dy);
    canvas.drawLine(
      Offset(rightMarker.dx, rightMarker.dy - 8),
      Offset(rightMarker.dx, rightMarker.dy + 8),
      markerPaint,
    );

    // Draw marker at left (-90°)
    final leftMarker = Offset(center.dx - radius, center.dy);
    canvas.drawLine(
      Offset(leftMarker.dx, leftMarker.dy - 8),
      Offset(leftMarker.dx, leftMarker.dy + 8),
      markerPaint,
    );

    // Clamp angle to -90 to 90 range
    final clampedAngle = angle.clamp(-90.0, 90.0);

    // Convert angle to radians
    final angleRad = clampedAngle * math.pi / 180.0;

    // Start angle is at the top (-π/2 in canvas coordinates)
    const startAngle = -math.pi / 2;

    // Calculate sweep angle based on positive or negative angle
    // In canvas.drawArc: positive sweep = clockwise, negative sweep = anticlockwise
    double sweepAngle;
    if (clampedAngle >= 0) {
      // Positive angle: 0 to 90, draw clockwise (right side)
      // Sweep from top (0°) to the right
      sweepAngle = angleRad; // Positive sweep = clockwise
    } else {
      // Negative angle: 0 to -90, draw anticlockwise (left side)
      // Sweep from top (0°) to the left (negative direction)
      sweepAngle =
          angleRad; // angleRad is already negative, so this gives anticlockwise
    }

    // Draw the arc with gradient
    final gradient = LinearGradient(
      colors: [accentColor.withValues(alpha: 0.8), accentColor],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    paint.shader = gradient;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Draw needle/indicator at the current angle position
    final needleRadius = radius;
    final needleAngle = startAngle + sweepAngle;
    final needleEnd = Offset(
      center.dx + needleRadius * math.cos(needleAngle),
      center.dy + needleRadius * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw shadow for depth
    canvas.drawCircle(
      needleEnd.translate(0, 2),
      7,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Draw needle circle
    canvas.drawCircle(needleEnd, 7, needlePaint);
    canvas.drawCircle(
      needleEnd,
      7,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw angle value in center (as integer)
    final valuePainter = TextPainter(
      text: TextSpan(
        text: "${clampedAngle.round()}°",
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    valuePainter.layout();

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Angle',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalHeight = valuePainter.height + 6 + labelPainter.height;
    final startY = center.dy - totalHeight / 2;

    valuePainter.paint(
      canvas,
      Offset(center.dx - valuePainter.width / 2, startY),
    );
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        startY + valuePainter.height + 6,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is PostureGaugePainter &&
        (oldDelegate.angle != angle || oldDelegate.accentColor != accentColor);
  }
}
