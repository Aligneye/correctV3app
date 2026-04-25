import 'dart:async';
import 'dart:math' as math;

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:correctv1/home/meditation_page.dart';
import 'package:correctv1/discover/discover_page.dart';
import 'package:correctv1/home/therapy_page.dart';
import 'package:correctv1/home/training_page.dart';
import 'package:correctv1/analytics/analytics_screen.dart';
import 'package:correctv1/settings/settings_page.dart';
import 'package:correctv1/components/nav_bar.dart';
import 'package:correctv1/calibration/calibration_page.dart';
import 'package:correctv1/services/device_manager.dart';
import 'package:correctv1/services/session_repository.dart';
import 'package:correctv1/theme/app_theme.dart';

const _kPagePadding = EdgeInsets.fromLTRB(24, 24, 24, 100);
const _kSectionSpacing = SizedBox(height: 24);
const _kInnerSpacing = SizedBox(height: 16);
const _kPrimaryBlue = AppTheme.brandPrimary;
const _kMutedText = AppTheme.textSecondary;
const _kPrimaryGreen = AppTheme.goodPostureEnd;
const _kBadPostureRed = AppTheme.destructive;

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
    // Hook up the BLE -> Supabase sync coordinator. Idempotent so it's safe
    // to call on every HomePage rebuild.
    DeviceManager().init();
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

  Future<void> _openTherapyPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const TherapyPage()),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  Future<void> _openTrainingPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const TrainingPage()),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  Future<void> _openMeditationPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const MeditationPage()),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboard(
        onNavigateToPage: _onItemTapped,
        onOpenTherapy: _openTherapyPage,
        onOpenTraining: _openTrainingPage,
        onOpenMeditation: _openMeditationPage,
        deviceService: _bluetoothManager.deviceService,
      ),
      const DiscoverPage(),
      const AnalyticsScreen(),
      const SettingsPage(),
    ];

    return Scaffold(
      extendBody: true,
      // The background is handled inside HomeDashboard for the gradient
      // But for other pages we might need a background.
      // For now, let's keep the Scaffold background simple or transparent if pages handle it.
      // The React code showed a full page gradient for Home.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
  final VoidCallback onOpenTherapy;
  final VoidCallback onOpenTraining;
  final VoidCallback onOpenMeditation;
  final AlignEyeDeviceService deviceService;

  const HomeDashboard({
    super.key,
    required this.onNavigateToPage,
    required this.onOpenTherapy,
    required this.onOpenTraining,
    required this.onOpenMeditation,
    required this.deviceService,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  late final AlignEyeDeviceService _deviceService;
  final BluetoothServiceManager _bluetoothManager = BluetoothServiceManager();
  final DeviceManager _deviceManager = DeviceManager();
  final SessionRepository _sessionRepository = SessionRepository();
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
  bool _hasShownStartupConnectSheet = false;
  bool _isFindingDevice = false;
  bool _isLoadingOfflineSessions = true;
  int _lastSyncTick = 0;
  List<SessionData> _offlineSessions = const <SessionData>[];

  static const List<_QuickMode> _quickModes = [
    _QuickMode(
      title: 'Therapy',
      icon: Icons.graphic_eq,
      gradient: [Color(0xFF60A5FA), Color(0xFF06B6D4)],
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Training',
      icon: Icons.accessibility_new_rounded,
      gradient: [Color(0xFFC084FC), Color(0xFFEC4899)],
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Walking',
      icon: Icons.directions_walk_rounded,
      gradient: [Color(0xFFFB7185), Color(0xFFEF4444)],
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Breathe',
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

    unawaited(_handleStartupDevicePrompt());
    _lastSyncTick = _deviceManager.syncCompletedTick.value;
    _deviceManager.syncCompletedTick.addListener(_handleSessionSyncFinished);
    _deviceManager.isSyncing.addListener(_handleSyncingChanged);
    _deviceManager.activeSessionId.addListener(_handleSessionSyncFinished);
    unawaited(_loadOfflineSessions());
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _deviceManager.syncCompletedTick.removeListener(_handleSessionSyncFinished);
    _deviceManager.isSyncing.removeListener(_handleSyncingChanged);
    _deviceManager.activeSessionId.removeListener(_handleSessionSyncFinished);
    _therapyCountdownTimer?.cancel();
    // Don't dispose the device service here - it's managed by BluetoothServiceManager
    // unawaited(_deviceService.dispose());
    _controller.dispose();
    super.dispose();
  }

  void _handleSyncingChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSessionSyncFinished() {
    final tick = _deviceManager.syncCompletedTick.value;
    if (tick == _lastSyncTick) return;
    _lastSyncTick = tick;
    unawaited(_loadOfflineSessions());
  }

  Future<void> _loadOfflineSessions() async {
    if (!mounted) return;
    setState(() => _isLoadingOfflineSessions = true);
    try {
      final sessions = await _sessionRepository.fetchByPeriod(
        'all',
        liveSessionId: _deviceManager.activeSessionId.value,
      );
      if (!mounted) return;
      setState(() {
        _offlineSessions = sessions.take(3).toList(growable: false);
        _isLoadingOfflineSessions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offlineSessions = const <SessionData>[];
        _isLoadingOfflineSessions = false;
      });
    }
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

    _therapyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
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
            'Device "aligneye pod" not found.\n\n'
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
              '1. Device "aligneye pod" is powered on\n'
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

  Future<void> _handleStartupDevicePrompt() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted || _hasShownStartupConnectSheet) {
      return;
    }

    if (_deviceService.connectionStatus.value !=
        DeviceConnectionStatus.disconnected) {
      return;
    }

    final hasBondedTarget = await _deviceService.hasBondedTargetDevice();
    if (!mounted || hasBondedTarget) {
      return;
    }

    if (_deviceService.connectionStatus.value !=
        DeviceConnectionStatus.disconnected) {
      return;
    }

    setState(() {
      _isFindingDevice = true;
    });
    bool hasUnpairedNearby = false;
    try {
      hasUnpairedNearby = await _deviceService.hasUnpairedTargetDeviceNearby(
        timeout: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFindingDevice = false;
        });
      }
    }
    if (!mounted || !hasUnpairedNearby) {
      return;
    }

    _hasShownStartupConnectSheet = true;
    await _showStartupConnectBottomSheet();
  }

  Future<void> _showStartupConnectBottomSheet() {
    bool isConnecting = false;
    const popupPrimary = AppTheme.brandPrimary;
    const popupSecondaryBg = AppTheme.connectedBg;
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Aligneye Pod',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Straighten up. Your future self will thank you.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            final scale = 0.92 + (0.08 * value);
                            return Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/product.png',
                              height: 170,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isConnecting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                backgroundColor: popupSecondaryBg,
                                foregroundColor: popupPrimary,
                                side: const BorderSide(color: popupPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Not now'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isConnecting
                                  ? null
                                  : () {
                                      setModalState(() => isConnecting = true);
                                      Navigator.of(context).pop();
                                      unawaited(_handleDeviceStatusTap());
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: popupPrimary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isConnecting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Connect'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

  void _showAllModesSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.brandGradient.createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'All Modes',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(sheetCtx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose your training mode',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      children: [
                        _AllModesSheetItem(
                          title: 'Tracking mode',
                          subtitle: 'Monitor your posture in real-time',
                          icon: Icons.monitor_heart_outlined,
                          gradient: AppTheme.trackingGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                          },
                        ),
                        const SizedBox(height: 12),
                        _AllModesSheetItem(
                          title: 'Posture training mode',
                          subtitle: 'Basic, Intermediate & Advanced levels',
                          icon: Icons.accessibility_new_rounded,
                          gradient: AppTheme.trainingGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            widget.onOpenTraining();
                          },
                        ),
                        const SizedBox(height: 12),
                        _AllModesSheetItem(
                          title: 'Vibration therapy mode',
                          subtitle: 'Acupressure vibration therapy',
                          icon: Icons.favorite,
                          gradient: AppTheme.therapyGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            widget.onOpenTherapy();
                          },
                        ),
                        const SizedBox(height: 12),
                        _AllModesSheetItem(
                          title: 'Breathe mode',
                          subtitle: 'Rhythmic breathing guidance',
                          icon: Icons.self_improvement,
                          gradient: AppTheme.meditationGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            widget.onOpenMeditation();
                          },
                        ),
                        const SizedBox(height: 12),
                        _AllModesSheetItem(
                          title: 'Walking mode',
                          subtitle: 'Walking posture trainer',
                          icon: Icons.directions_walk,
                          gradient: AppTheme.alignWalkGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                          },
                        ),
                        const SizedBox(height: 12),
                        _AllModesSheetItem(
                          title: 'Analytics',
                          subtitle: 'Track your posture progress',
                          icon: Icons.bar_chart_rounded,
                          gradient: AppTheme.ridingGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            widget.onNavigateToPage(2);
                          },
                        ),
                        const SizedBox(height: 20),
                        const _QuickModeProTipCard(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.pageBackgroundGradientFor(context),
      ),
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
                child: const _StatsSummaryCard(
                  items: [
                    _StatItemData(
                      value: '82',
                      unit: '%',
                      label: 'Good posture',
                      trendText: '6% from last week',
                      icon: Icons.accessibility_new_rounded,
                      gradient: AppTheme.goodPostureGradient,
                      positiveTrend: true,
                    ),
                    _StatItemData(
                      value: '14',
                      unit: 'h',
                      label: 'Tracked time',
                      trendText: '2.5h more',
                      icon: Icons.bar_chart_rounded,
                      gradient: AppTheme.trackingGradient,
                      positiveTrend: true,
                    ),
                    _StatItemData(
                      value: '9',
                      label: 'Sessions done',
                      trendText: '3 more',
                      icon: Icons.check_circle_rounded,
                      gradient: AppTheme.meditationGradient,
                      positiveTrend: true,
                    ),
                    _StatItemData(
                      value: '47',
                      unit: 'min',
                      label: 'Therapy time',
                      trendText: '8min less',
                      icon: Icons.favorite_rounded,
                      gradient: AppTheme.therapyGradient,
                      positiveTrend: false,
                    ),
                  ],
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 100,
                child: ValueListenableBuilder<DeviceConnectionStatus>(
                  valueListenable: _deviceService.connectionStatus,
                  builder: (context, connectionStatus, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _deviceService.isAutoConnectionAttempt,
                      builder: (context, isAutoConnectionAttempt, child) {
                        return _DeviceStatusCard(
                          status: connectionStatus,
                          isAutoConnectionAttempt: isAutoConnectionAttempt,
                          isFindingDevice: _isFindingDevice,
                          batteryLevel: _batteryLevel,
                          onTap: _handleDeviceStatusTap,
                        );
                      },
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
                delayMs: 350,
                child: _QuickModesSection(
                  modes: _quickModes,
                  onViewAll: () => _showAllModesSheet(context),
                  onModeTap: widget.onNavigateToPage,
                  onTherapyModeTap: widget.onOpenTherapy,
                  onTrainingModeTap: widget.onOpenTraining,
                  onMeditationModeTap: widget.onOpenMeditation,
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 400,
                child: _CalibrationCard(
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
                      widget.onNavigateToPage(0);
                    }
                  },
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 800,
                child: _RecentValuesCard(recentValues: _recentValues),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 900,
                child: _OfflineSessionsCard(
                  sessions: _offlineSessions,
                  isLoading: _isLoadingOfflineSessions,
                  isSyncing: _deviceManager.isSyncing.value,
                  onViewAll: () => widget.onNavigateToPage(2),
                ),
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

class _StreakChip extends StatelessWidget {
  const _StreakChip({this.days = 7});

  final int days;

  static const _accent = AppTheme.purple600;
  static const _surface = Color(0xFFF5F3FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 20,
            child: CustomPaint(painter: _StreakFlamePainter()),
          ),
          const SizedBox(width: 6),
          Text(
            '$days days',
            style: const TextStyle(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakFlamePainter extends CustomPainter {
  const _StreakFlamePainter();

  static const _fill = AppTheme.purple600;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..cubicTo(w * 0.95, h * 0.32, w * 0.92, h * 0.72, w * 0.5, h * 0.96)
      ..cubicTo(w * 0.08, h * 0.72, w * 0.05, h * 0.32, w * 0.5, h * 0.05)
      ..close();
    canvas.drawPath(path, Paint()..color = _fill);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.76),
      w * 0.11,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeviceStatusCard extends StatelessWidget {
  final DeviceConnectionStatus status;
  final bool isAutoConnectionAttempt;
  final bool isFindingDevice;
  final int batteryLevel;
  final VoidCallback onTap;

  const _DeviceStatusCard({
    required this.status,
    required this.isAutoConnectionAttempt,
    required this.isFindingDevice,
    required this.batteryLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = status == DeviceConnectionStatus.connected;
    final isConnecting = status == DeviceConnectionStatus.connecting;
    final statusText = isFindingDevice
        ? 'Finding device'
        : isConnecting
        ? (isAutoConnectionAttempt ? 'Auto connecting' : 'Connecting')
        : isConnected
        ? 'Connected'
        : 'Disconnected';
    final statusColor = (isConnecting || isFindingDevice)
        ? const Color(0xFFF59E0B)
        : _kPrimaryBlue;
    final iconColor = isConnected
        ? _kPrimaryBlue
        : (isConnecting || isFindingDevice)
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
                        color: AppTheme.connectedBg,
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
                              color: (isConnecting || isFindingDevice)
                                  ? statusColor
                                  : iconColor,
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
                    if (isConnecting || isFindingDevice) ...[
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
  return AppTheme.successBg;
}

Color _batteryTierTextColor(int level) {
  if (level < 25) {
    return const Color(0xFFDC2626);
  }
  if (level < 60) {
    return const Color(0xFFF59E0B);
  }
  return AppTheme.successText;
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
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recentValues,
            style: const TextStyle(fontSize: 12, color: _kMutedText),
          ),
        ],
      ),
    );
  }
}

class _OfflineSessionsCard extends StatelessWidget {
  final List<SessionData> sessions;
  final bool isLoading;
  final bool isSyncing;
  final VoidCallback onViewAll;

  const _OfflineSessionsCard({
    required this.sessions,
    required this.isLoading,
    required this.isSyncing,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Device Sessions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isSyncing
                ? 'Syncing stored sessions from device...'
                : 'Live sessions appear instantly; offline sessions sync on reconnect.',
            style: const TextStyle(fontSize: 12, color: _kMutedText),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No device sessions yet.',
                style: TextStyle(fontSize: 12, color: _kMutedText),
              ),
            )
          else
            ...sessions.map((session) => _OfflineSessionRow(session: session)),
        ],
      ),
    );
  }
}

class _OfflineSessionRow extends StatelessWidget {
  final SessionData session;

  const _OfflineSessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final isPosture = session.type == SessionType.posture;
    final color = isPosture ? _kPrimaryBlue : _kBadPostureRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPosture ? Icons.accessibility_new : Icons.favorite,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.isLive) ...[
                      const SizedBox(width: 6),
                      const _HomeLiveTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.time} · ${session.duration}',
                  style: const TextStyle(fontSize: 12, color: _kMutedText),
                ),
              ],
            ),
          ),
          if (session.score != null)
            Text(
              '${session.score}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeLiveTag extends StatelessWidget {
  const _HomeLiveTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kBadPostureRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBadPostureRed.withValues(alpha: 0.18)),
      ),
      child: const Text(
        'Live',
        style: TextStyle(
          color: _kBadPostureRed,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF0), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
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
            'Default Mode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
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
                    color: AppTheme.textPrimary,
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
            _TherapyStatusRow(
              therapyCountdownRunning: therapyCountdownRunning,
              therapyRemainingSeconds: therapyRemainingSeconds,
              currentPattern: currentTherapyPattern,
              nextPattern: nextTherapyPattern,
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

class _TherapyStatusRow extends StatefulWidget {
  final bool therapyCountdownRunning;
  final int therapyRemainingSeconds;
  final String currentPattern;
  final String nextPattern;

  const _TherapyStatusRow({
    required this.therapyCountdownRunning,
    required this.therapyRemainingSeconds,
    required this.currentPattern,
    required this.nextPattern,
  });

  @override
  State<_TherapyStatusRow> createState() => _TherapyStatusRowState();
}

class _TherapyStatusRowState extends State<_TherapyStatusRow> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive =
        widget.therapyCountdownRunning &&
        widget.currentPattern != 'Waiting for therapy' &&
        widget.currentPattern != 'Preparing pattern...';

    return Container(
      height: 86,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  AppTheme.brandPrimary.withValues(alpha: 0.06),
                  AppTheme.purple600.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppTheme.brandPrimary.withValues(alpha: 0.3)
              : AppTheme.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _kPrimaryBlue.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Countdown section
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        AppTheme.brandPrimary.withValues(alpha: 0.15),
                        AppTheme.brandPrimary.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isActive ? null : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.brandPrimary.withValues(alpha: 0.2)
                            : AppTheme.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: isActive ? AppTheme.brandPrimary : _kMutedText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppTheme.brandPrimary : _kMutedText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.therapyCountdownRunning
                      ? _formatCountdown(widget.therapyRemainingSeconds)
                      : '--:--',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppTheme.brandPrimary
                        : AppTheme.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.brandPrimary.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    )
                  : null,
              color: isActive ? null : AppTheme.border,
            ),
          ),
          // Swipeable pattern section
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _TherapyPatternCard(
                        label: 'Running Now',
                        pattern: widget.currentPattern,
                        icon: Icons.play_circle_filled,
                        isActive: isActive,
                        isHighlighted: true,
                      ),
                      _TherapyPatternCard(
                        label: 'Next',
                        pattern: widget.nextPattern,
                        icon: Icons.schedule,
                        isActive: false,
                        isHighlighted: false,
                      ),
                    ],
                  ),
                  // Page indicators
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PageIndicator(isActive: _currentPage == 0),
                        const SizedBox(width: 8),
                        _PageIndicator(isActive: _currentPage == 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
              color: selected ? Colors.white : AppTheme.textPrimary,
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

class _CalibrationCard extends StatelessWidget {
  final VoidCallback onCalibratePressed;

  const _CalibrationCard({required this.onCalibratePressed});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.goodPostureGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calibrate',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reset posture baseline',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _kInnerSpacing,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.connectedBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppTheme.brandPrimary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _kPrimaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sit in your ideal posture position before calibrating. '
                    'This will set your baseline reference angle.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _kInnerSpacing,
          _GradientActionButton(
            label: 'Start Calibration',
            gradient: AppTheme.trainingGradient,
            onTap: onCalibratePressed,
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapyPatternCard extends StatelessWidget {
  final String label;
  final String pattern;
  final IconData icon;
  final bool isActive;
  final bool isHighlighted;

  const _TherapyPatternCard({
    required this.label,
    required this.pattern,
    required this.icon,
    required this.isActive,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppTheme.brandPrimary : _kMutedText,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pattern,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isHighlighted
                  ? AppTheme.brandPrimary
                  : AppTheme.textPrimary,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;

  const _PageIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isActive ? 24 : 6,
      height: 6,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [AppTheme.brandPrimary, AppTheme.purple600],
              )
            : null,
        color: isActive ? null : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(3),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
        border: Border.all(color: AppTheme.border),
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
            color: AppTheme.textPrimary,
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
                            color: AppTheme.textPrimary,
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
  final VoidCallback onTherapyModeTap;
  final VoidCallback onTrainingModeTap;
  final VoidCallback onMeditationModeTap;

  const _QuickModesSection({
    required this.modes,
    required this.onViewAll,
    required this.onModeTap,
    required this.onTherapyModeTap,
    required this.onTrainingModeTap,
    required this.onMeditationModeTap,
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
                color: AppTheme.textPrimary,
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
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: modes
              .map(
                (mode) => _QuickModeCard(
                  mode: mode,
                  onTap: () {
                    if (mode.title == 'Therapy') {
                      onTherapyModeTap();
                      return;
                    }
                    if (mode.title == 'Training') {
                      onTrainingModeTap();
                      return;
                    }
                    if (mode.title == 'Breathe') {
                      onMeditationModeTap();
                      return;
                    }
                    onModeTap(mode.targetIndex);
                  },
                ),
              )
              .toList(),
        ),
        _kInnerSpacing,
        const _QuickModeProTipCard(),
      ],
    );
  }
}

class _QuickModeProTipCard extends StatelessWidget {
  const _QuickModeProTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'Pro Tip',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Start with Training Mode to build awareness, then use Therapy Mode for muscle relief.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
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
                  color: AppTheme.textPrimary,
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
    assert(items.length == 4, '_StatsSummaryCard expects 4 items');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Summary",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const _StreakChip(days: 7),
            ],
          ),
        ),
        SizedBox(
          height: 156,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 132,
                child: _SummaryMetricTile(item: items[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final _StatItemData item;

  const _SummaryMetricTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final trendColor = item.positiveTrend
        ? AppTheme.successText
        : AppTheme.destructive;
    final trendBg = item.positiveTrend
        ? AppTheme.successBg
        : const Color(0xFFFEF2F2);

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: item.gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: Colors.white, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1.05,
                      ),
                    ),
                    if (item.unit != null && item.unit!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        item.unit!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 104),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: trendBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.positiveTrend
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: trendColor,
                    ),
                    Flexible(
                      child: Text(
                        item.trendText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: trendColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
  final String? unit;
  final String label;
  final String trendText;
  final IconData icon;
  final LinearGradient gradient;
  final bool positiveTrend;

  const _StatItemData({
    required this.value,
    this.unit,
    required this.label,
    required this.trendText,
    required this.icon,
    required this.gradient,
    this.positiveTrend = true,
  });
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

class _AllModesSheetItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _AllModesSheetItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
