import 'dart:async';
import 'dart:math' as math;

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:correctv1/bluetooth/device_connect_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:correctv1/home/meditation_page.dart';
import 'package:correctv1/discover/discover_page.dart';
import 'package:correctv1/home/therapy_page.dart';
import 'package:correctv1/home/training_page.dart';
import 'package:correctv1/analytics/analytics_screen.dart';
import 'package:correctv1/sessions/sessions_history_page.dart';
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
    _deviceManager.activeSessionId.addListener(_handleActiveSessionChanged);
    unawaited(_loadOfflineSessions());
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _deviceManager.syncCompletedTick.removeListener(_handleSessionSyncFinished);
    _deviceManager.isSyncing.removeListener(_handleSyncingChanged);
    _deviceManager.activeSessionId.removeListener(_handleActiveSessionChanged);
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

  void _handleActiveSessionChanged() {
    if (!mounted) return;
    unawaited(_loadOfflineSessions());
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
      debugPrint('HomeDashboard: loaded ${sessions.length} sessions');
      setState(() {
        _offlineSessions = sessions.take(5).toList(growable: false);
        _isLoadingOfflineSessions = false;
      });
    } catch (e) {
      debugPrint('HomeDashboard: _loadOfflineSessions error: $e');
      if (!mounted) return;
      setState(() {
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
    final status = _deviceService.connectionStatus.value;
    if (status == DeviceConnectionStatus.connecting) return;

    if (status == DeviceConnectionStatus.connected) {
      await _showConnectedSheet();
      return;
    }

    if (!mounted) return;

    if (!await _ensureBleReady()) return;

    if (!mounted) return;
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const DeviceConnectPage()));
  }

  /// Ensures Bluetooth is on and permissions are granted before proceeding.
  /// Returns `true` when BLE is ready; `false` if the user declined or
  /// something couldn't be resolved.
  Future<bool> _ensureBleReady() async {
    final readiness = await _deviceService.checkReadiness();
    if (!mounted) return false;

    switch (readiness) {
      case BleReadiness.ready:
        return true;

      case BleReadiness.bluetoothUnsupported:
        _showBleSnackBar('Bluetooth is not supported on this device.');
        return false;

      case BleReadiness.bluetoothOff:
        try {
          // On Android this surfaces the native "Allow app to turn on
          // Bluetooth?" system dialog — no custom prompt needed.
          await FlutterBluePlus.turnOn();

          // Wait for the adapter to actually come up (the user might still be
          // looking at the system dialog, so poll for a few seconds).
          final on = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 8));
          if (on == BluetoothAdapterState.on) return true;
        } catch (_) {
          // User declined the system dialog or timeout.
        }
        if (!mounted) return false;
        _showBleSnackBar(
          'Bluetooth is required to connect. Please enable it and try again.',
        );
        return false;

      case BleReadiness.permissionDenied:
        _showBleSnackBar(
          'Bluetooth permissions are required. Please grant them and try again.',
        );
        return false;

      case BleReadiness.permissionPermanentlyDenied:
        if (!mounted) return false;
        _showBleSnackBar(
          'Bluetooth permissions were denied. Opening settings…',
        );
        await openAppSettings();
        return false;
    }
  }

  void _showBleSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _showConnectedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConnectedDeviceSheet(
        batteryLevel: _batteryLevel,
        onDisconnect: () async {
          Navigator.of(ctx).pop();
          await _deviceService.disconnect(userInitiated: true);
          if (!mounted) return;
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const DeviceConnectPage()),
          );
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
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
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.1,
                              ),
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
                child: ValueListenableBuilder<DeviceConnectionStatus>(
                  valueListenable: _deviceService.connectionStatus,
                  builder: (context, connectionStatus, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _deviceService.isAutoConnectionAttempt,
                      builder: (context, isAutoConnectionAttempt, child) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _deviceManager.isSyncing,
                          builder: (context, isSyncing, child) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: _deviceManager.activeSessionId,
                              builder: (context, activeSessionId, child) {
                                return _TopHeaderBar(
                                  status: connectionStatus,
                                  isAutoConnectionAttempt:
                                      isAutoConnectionAttempt,
                                  isFindingDevice: _isFindingDevice,
                                  isSyncing: isSyncing,
                                  isLive: activeSessionId != null,
                                  batteryLevel: _batteryLevel,
                                  onTap: _handleDeviceStatusTap,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 100,
                child: const _StatsSummaryCard(
                  streakDays: 12,
                  items: [
                    _StatItemData(
                      value: '82',
                      unit: '%',
                      label: 'Good posture',
                      trendText: '6% from last week',
                      icon: Icons.accessibility_new_rounded,
                      gradient: AppTheme.trainingGradient,
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
                      icon: Icons.self_improvement,
                      gradient: AppTheme.meditationGradient,
                      positiveTrend: true,
                    ),
                    _StatItemData(
                      value: '47',
                      unit: 'min',
                      label: 'Therapy time',
                      trendText: '8min less',
                      icon: Icons.graphic_eq,
                      gradient: AppTheme.therapyGradient,
                      positiveTrend: false,
                    ),
                  ],
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
                delayMs: 500,
                child: ValueListenableBuilder<DeviceConnectionStatus>(
                  valueListenable: _deviceService.connectionStatus,
                  builder: (context, status, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _deviceManager.isSyncing,
                      builder: (context, isSyncing, _) {
                        return _RecentSessionsCard(
                          sessions: _offlineSessions,
                          isLoading: _isLoadingOfflineSessions,
                          isSyncing: isSyncing,
                          isDeviceDisconnected:
                              status == DeviceConnectionStatus.disconnected,
                          isDeviceConnecting:
                              status == DeviceConnectionStatus.connecting,
                          onViewAll: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const SessionsHistoryPage(),
                            ),
                          ),
                          onSessionTap: (session) =>
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SessionDetailScreen(session: session),
                                ),
                              ),
                          onSyncNow: () => unawaited(_handleSyncNow()),
                        );
                      },
                    );
                  },
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

  Future<void> _handleSyncNow() async {
    final status = _deviceService.connectionStatus.value;
    if (status == DeviceConnectionStatus.connected) {
      // Already connected — nudge a fresh sync by toggling reconnect path.
      // Simplest robust way: reuse the existing connect flow, which is a
      // no-op when already connected and otherwise does the right thing.
      return;
    }
    try {
      await _bluetoothManager.connect();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\'t reach the pod: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

class _TopHeaderBar extends StatefulWidget {
  final DeviceConnectionStatus status;
  final bool isAutoConnectionAttempt;
  final bool isFindingDevice;
  final bool isSyncing;
  final bool isLive;
  final int batteryLevel;
  final VoidCallback onTap;

  const _TopHeaderBar({
    required this.status,
    required this.isAutoConnectionAttempt,
    required this.isFindingDevice,
    required this.isSyncing,
    required this.isLive,
    required this.batteryLevel,
    required this.onTap,
  });

  @override
  State<_TopHeaderBar> createState() => _TopHeaderBarState();
}

class _TopHeaderBarState extends State<_TopHeaderBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── Connection celebration animation ──────────────────────────────
  late final AnimationController _connectCtrl;
  late final Animation<double> _connectScale;
  late final Animation<double> _connectGlow;

  // ── Rotating border for pending states ────────────────────────────
  late final AnimationController _spinCtrl;

  DeviceConnectionStatus? _prevStatus;

  // ── Motivational word pool (shown with typewriter effect) ──────────
  static const _motivationalWords = [
    'Focus',
    'Breathe',
    'Balance',
    'Keep Going',
    'Stand tall',
    'Be present',
    'Reset',
    'Own it',
    'Redefining posture',
    'Stay aligned',
    'Be in the moment',
    'Posture Matters',
    'Just do it',
    'Move Better',
    'Build Good Habits',
    'Rise Above Limits',
    'Sit Like Human',
    'Straighten Up Champ',
    'Posture Police Watching',
    'Neck Says Ouch',
    'Look Less Potato',
  ];

  String _chosenText = '';
  String _displayedText = '';
  Timer? _typewriterTimer;
  Timer? _cycleTimer;
  int _charIndex = 0;
  int _cycleCount = 0;
  static const _maxCyclesPerBurst = 3;
  static const _delayBetweenCycles = Duration(seconds: 5);
  static const _burstInterval = Duration(seconds: 60);

  String _pickTextForSession() {
    final rand = math.Random();
    final now = DateTime.now();
    final h = now.hour;

    // ~30 % chance to show a time-aware greeting instead of motivational word
    if (rand.nextDouble() < 0.30) {
      if (h >= 5 && h < 12) return 'Good morning';
      if (h >= 12 && h < 17) return 'Good afternoon';
      if (h >= 17 && h < 21) return 'Good evening';
      return 'Welcome back';
    }
    return _motivationalWords[rand.nextInt(_motivationalWords.length)];
  }

  // ── Typewriter engine ─────────────────────────────────────────────
  void _startTypewriterCycle() {
    _cycleCount = 0;
    _runSingleTypewrite();
  }

  void _runSingleTypewrite() {
    _charIndex = 0;
    _displayedText = '';
    if (mounted) setState(() {});

    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 80), (
      timer,
    ) {
      if (_charIndex < _chosenText.length) {
        _charIndex++;
        _displayedText = _chosenText.substring(0, _charIndex);
        if (mounted) setState(() {});
      } else {
        timer.cancel();
        _cycleCount++;
        if (_cycleCount < _maxCyclesPerBurst) {
          Future.delayed(_delayBetweenCycles, () {
            if (mounted) _runSingleTypewrite();
          });
        }
      }
    });
  }

  void _scheduleBursts() {
    _startTypewriterCycle();
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(_burstInterval, (_) {
      if (mounted) _startTypewriterCycle();
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _connectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _connectScale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _connectCtrl, curve: Curves.easeOutBack));
    _connectGlow = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _connectCtrl, curve: Curves.easeOut));

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _prevStatus = widget.status;
    _chosenText = _pickTextForSession();
    _scheduleBursts();
  }

  @override
  void didUpdateWidget(covariant _TopHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      if (widget.status == DeviceConnectionStatus.connected &&
          _prevStatus != DeviceConnectionStatus.connected) {
        _connectCtrl.forward().then((_) => _connectCtrl.reverse());
      }
      _prevStatus = widget.status;
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _cycleTimer?.cancel();
    _pulseCtrl.dispose();
    _connectCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status == DeviceConnectionStatus.connected;
    final isConnecting = widget.status == DeviceConnectionStatus.connecting;
    final isPending =
        isConnecting || widget.isFindingDevice || widget.isSyncing;

    final Color accentColor;
    final IconData statusIcon;
    final String statusLabel;

    if (widget.isFindingDevice) {
      accentColor = const Color(0xFFF59E0B);
      statusIcon = Icons.bluetooth_searching_rounded;
      statusLabel = 'Finding…';
    } else if (isConnecting) {
      accentColor = const Color(0xFFF59E0B);
      statusIcon = Icons.bluetooth_searching_rounded;
      statusLabel = widget.isAutoConnectionAttempt
          ? 'Auto-connecting'
          : 'Connecting…';
    } else if (widget.isSyncing) {
      accentColor = const Color(0xFF3B82F6);
      statusIcon = Icons.sync_rounded;
      statusLabel = 'Syncing';
    } else if (widget.isLive) {
      accentColor = const Color(0xFFEF4444);
      statusIcon = Icons.sensors_rounded;
      statusLabel = 'Live';
    } else if (isConnected) {
      accentColor = const Color(0xFF22C55E);
      statusIcon = Icons.bluetooth_connected_rounded;
      statusLabel = 'Connected';
    } else {
      accentColor = AppTheme.textMuted;
      statusIcon = Icons.bluetooth_rounded;
      statusLabel = 'Tap to connect';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Left: logo + tagline ────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/logosvg.svg',
                height: 30,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.trainingGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                blendMode: BlendMode.srcIn,
                child: Text(
                  _displayedText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // ── Right: connection chip ──────────────────────────────────
        GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _connectScale,
              _connectGlow,
              _pulseAnim,
              _spinCtrl,
            ]),
            builder: (context, child) {
              return Transform.scale(
                scale: _connectScale.value,
                child: _buildConnectionChip(
                  accentColor: accentColor,
                  statusIcon: statusIcon,
                  statusLabel: statusLabel,
                  isConnected: isConnected,
                  isPending: isPending,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionChip({
    required Color accentColor,
    required IconData statusIcon,
    required String statusLabel,
    required bool isConnected,
    required bool isPending,
  }) {
    final batteryIcon = widget.batteryLevel > 70
        ? Icons.battery_full_rounded
        : widget.batteryLevel > 30
        ? Icons.battery_5_bar_rounded
        : Icons.battery_alert_rounded;
    final batteryColor = widget.batteryLevel > 30
        ? AppTheme.textSecondary
        : const Color(0xFFEF4444);

    final glowOpacity = _connectGlow.value * 0.5;
    final breathe = isConnected ? 0.04 * _pulseAnim.value : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: isPending ? 0.35 : 0.15),
          width: 1,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
          if (glowOpacity > 0)
            BoxShadow(
              color: accentColor.withValues(alpha: glowOpacity),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          if (isConnected)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.04 + breathe),
              blurRadius: 14,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Animated icon with spinner ──────────────────────────
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isPending)
                  Transform.rotate(
                    angle: _spinCtrl.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(24, 24),
                      painter: _ArcPainter(color: accentColor),
                    ),
                  ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10 + breathe),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      statusIcon,
                      key: ValueKey(statusIcon),
                      size: 13,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Status label + battery below ────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  statusLabel,
                  key: ValueKey(statusLabel),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topLeft,
                clipBehavior: Clip.hardEdge,
                child: isConnected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(batteryIcon, size: 12, color: batteryColor),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.batteryLevel}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: batteryColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  const _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas.drawArc(rect, 0, math.pi * 1.2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.color != color;
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

class _RecentSessionsCard extends StatelessWidget {
  final List<SessionData> sessions;
  final bool isLoading;
  final bool isSyncing;
  final bool isDeviceDisconnected;
  final bool isDeviceConnecting;
  final VoidCallback onViewAll;
  final ValueChanged<SessionData> onSessionTap;
  final VoidCallback onSyncNow;

  const _RecentSessionsCard({
    required this.sessions,
    required this.isLoading,
    required this.isSyncing,
    required this.isDeviceDisconnected,
    required this.isDeviceConnecting,
    required this.onViewAll,
    required this.onSessionTap,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    final liveSessions = sessions.where((s) => s.isLive).toList();
    final finishedSessions = sessions.where((s) => !s.isLive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header – matches Quick Modes style
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Sessions',
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

        // Status banner: disconnect / syncing
        if (isDeviceDisconnected) ...[
          const SizedBox(height: 12),
          _DisconnectedBanner(
            isReconnecting: isDeviceConnecting,
            onSyncNow: onSyncNow,
          ),
        ] else if (isSyncing) ...[
          const SizedBox(height: 12),
          const _HomeSyncingBanner(),
        ],

        const SizedBox(height: 12),

        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: LinearProgressIndicator(minHeight: 3),
          )
        else if (sessions.isEmpty)
          const _EmptyRecentSessions()
        else ...[
          for (final live in liveSessions) ...[
            _LiveSessionRow(session: live, onTap: () => onSessionTap(live)),
            const SizedBox(height: 8),
          ],
          for (
            var i = 0;
            i < finishedSessions.length && (liveSessions.length + i) < 5;
            i++
          ) ...[
            _HomeSessionItem(
              session: finishedSessions[i],
              onTap: () => onSessionTap(finishedSessions[i]),
            ),
            if ((liveSessions.length + i + 1) <
                (liveSessions.length + finishedSessions.length).clamp(0, 5))
              const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _DisconnectedBanner extends StatelessWidget {
  final bool isReconnecting;
  final VoidCallback onSyncNow;
  const _DisconnectedBanner({
    required this.isReconnecting,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE2A8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bluetooth_disabled_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device disconnected',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Sessions are still being saved on the pod. '
                  'Sync to pull them in.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB45309),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isReconnecting ? null : onSyncNow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isReconnecting
                    ? const Color(0xFFFFE2A8)
                    : const Color(0xFFB45309),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isReconnecting) ...[
                    const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    const Icon(
                      Icons.sync_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    isReconnecting ? 'Syncing' : 'Sync now',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isReconnecting
                          ? const Color(0xFFB45309)
                          : Colors.white,
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

class _HomeSyncingBanner extends StatelessWidget {
  const _HomeSyncingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: _kPrimaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(_kPrimaryBlue),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Syncing offline sessions from your pod…',
              style: TextStyle(
                fontSize: 12,
                color: _kPrimaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecentSessions extends StatelessWidget {
  const _EmptyRecentSessions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kPrimaryBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 18,
              color: _kPrimaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No sessions yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Start a posture or therapy session and it shows up here.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _kMutedText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSessionRow extends StatelessWidget {
  final SessionData session;
  final VoidCallback onTap;
  const _LiveSessionRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPosture = session.type == SessionType.posture;
    final accent = isPosture ? _kPrimaryBlue : _kPrimaryGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.10),
                accent.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPosture
                      ? Icons.accessibility_new_rounded
                      : Icons.vibration_rounded,
                  size: 19,
                  color: accent,
                ),
              ),
              const SizedBox(width: 11),
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
                        const SizedBox(width: 6),
                        const _HomeLivePill(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.duration == '0s'
                          ? 'Just started · live now'
                          : 'In progress · ${session.duration}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPosture && session.score != null)
                Text(
                  '${session.score}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: -0.4,
                  ),
                )
              else if (!isPosture && session.pattern != null)
                Text(
                  '#${session.pattern}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: -0.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSessionItem extends StatelessWidget {
  final SessionData session;
  final VoidCallback onTap;
  const _HomeSessionItem({required this.session, required this.onTap});

  static const _kText = Color(0xFF1A1A2E);
  static const _kTextHint = Color(0xFFBBBBCC);
  static const _kBlue = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final isPosture = session.type == SessionType.posture;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPosture
                      ? const [Color(0xFFC084FC), Color(0xFFEC4899)]
                      : const [Color(0xFF60A5FA), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isPosture ? Icons.accessibility_new_rounded : Icons.graphic_eq,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          session.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (session.isLive) ...[
                        const SizedBox(width: 6),
                        const _HomeLivePill(),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        session.time,
                        style: const TextStyle(fontSize: 10, color: _kTextHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _HomeSessionMiniStat(
                        value: session.duration,
                        label: 'Duration',
                      ),
                      if (session.score != null) ...[
                        const SizedBox(width: 14),
                        _HomeSessionMiniStat(
                          value: '${session.score}%',
                          label: 'Good posture',
                        ),
                      ],
                      if (session.alerts != null) ...[
                        const SizedBox(width: 14),
                        _HomeSessionMiniStat(
                          value: '${session.alerts}×',
                          label: 'Alerts',
                        ),
                      ],
                      if (session.pattern != null) ...[
                        const SizedBox(width: 14),
                        _HomeSessionMiniStat(
                          value: '#${session.pattern}',
                          label: 'Pattern',
                        ),
                      ],
                    ],
                  ),
                  if (session.score != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: session.score! / 100,
                        backgroundColor: const Color(0xFFEEEEF8),
                        valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
                        minHeight: 3.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCCCCDD),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSessionMiniStat extends StatelessWidget {
  final String value, label;
  const _HomeSessionMiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
          height: 1.2,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFBBBBCC),
          height: 1.3,
        ),
      ),
    ],
  );
}

class _HomeLivePill extends StatefulWidget {
  const _HomeLivePill();

  @override
  State<_HomeLivePill> createState() => _HomeLivePillState();
}

class _HomeLivePillState extends State<_HomeLivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kBadPostureRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBadPostureRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _kBadPostureRed.withValues(
                  alpha: 0.55 + 0.45 * _ctrl.value,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: _kBadPostureRed,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedDeviceSheet extends StatelessWidget {
  final int batteryLevel;
  final VoidCallback onDisconnect;
  final VoidCallback onCancel;

  const _ConnectedDeviceSheet({
    required this.batteryLevel,
    required this.onDisconnect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final batteryColor = batteryLevel > 30
        ? const Color(0xFF16A34A)
        : const Color(0xFFEF4444);
    final batteryIcon = batteryLevel > 70
        ? Icons.battery_full_rounded
        : batteryLevel > 30
        ? Icons.battery_5_bar_rounded
        : Icons.battery_alert_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 32,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Device info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Product image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/product.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AlignEye Pod',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Connected',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Battery chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: batteryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(batteryIcon, color: batteryColor, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '$batteryLevel%',
                        style: TextStyle(
                          color: batteryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: const Color(0xFFF1F5F9), thickness: 1),
          ),
          const SizedBox(height: 16),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Column(
              children: [
                GestureDetector(
                  onTap: onDisconnect,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'Disconnect & Find New Pod',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                )
              : null,
          color: selected ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                    if (mode.title == 'Walking') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _ComingSoonPage(title: 'Walking Mode'),
                        ),
                      );
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
  final int streakDays;

  const _StatsSummaryCard({required this.items, this.streakDays = 12});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 24),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SizedBox(width: 132, child: _StreakTile(days: streakDays));
          }
          return SizedBox(
            width: 132,
            child: _SummaryMetricTile(item: items[index - 1]),
          );
        },
      ),
    );
  }
}

class _StreakTile extends StatefulWidget {
  final int days;

  const _StreakTile({required this.days});

  @override
  State<_StreakTile> createState() => _StreakTileState();
}

class _StreakTileState extends State<_StreakTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _flameFlicker;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _flameFlicker = Tween<double>(
      begin: -0.04,
      end: 0.04,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF3B82F6,
                ).withValues(alpha: 0.25 + _glowAnim.value * 0.02),
                blurRadius: 16 + _glowAnim.value,
                offset: const Offset(0, 6),
                spreadRadius: _glowAnim.value * 0.3,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Subtle radial highlight
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Shimmer line
              Positioned(
                top: 0,
                bottom: 0,
                left: -60 + (_ctrl.value * 260),
                child: Transform.rotate(
                  angle: -0.4,
                  child: Container(
                    width: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Number
                    Text(
                      '${widget.days}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    // Label
                    const Text(
                      'Streak\nDays',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Animated fire icon (bottom right)
              Positioned(
                bottom: -6,
                right: -2,
                child: Transform.rotate(
                  angle: _flameFlicker.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 56,
                      height: 64,
                      child: CustomPaint(
                        painter: _StreakFirePainter(progress: _ctrl.value),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StreakFirePainter extends CustomPainter {
  final double progress;

  const _StreakFirePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer flame (orange-red)
    final outerPath = Path()
      ..moveTo(w * 0.50, h * 0.02)
      ..cubicTo(w * 0.20, h * 0.20, w * -0.05, h * 0.45, w * 0.15, h * 0.70)
      ..cubicTo(w * 0.22, h * 0.82, w * 0.30, h * 0.95, w * 0.50, h * 0.98)
      ..cubicTo(w * 0.70, h * 0.95, w * 0.78, h * 0.82, w * 0.85, h * 0.70)
      ..cubicTo(w * 1.05, h * 0.45, w * 0.80, h * 0.20, w * 0.50, h * 0.02)
      ..close();

    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF6B35),
          Color.lerp(
            const Color(0xFFFF4500),
            const Color(0xFFFF6347),
            progress,
          )!,
          const Color(0xFFFF8C00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(outerPath, outerPaint);

    // Inner flame (yellow-orange)
    final innerPath = Path()
      ..moveTo(w * 0.50, h * 0.28)
      ..cubicTo(w * 0.30, h * 0.42, w * 0.18, h * 0.55, w * 0.28, h * 0.72)
      ..cubicTo(w * 0.34, h * 0.85, w * 0.42, h * 0.94, w * 0.50, h * 0.96)
      ..cubicTo(w * 0.58, h * 0.94, w * 0.66, h * 0.85, w * 0.72, h * 0.72)
      ..cubicTo(w * 0.82, h * 0.55, w * 0.70, h * 0.42, w * 0.50, h * 0.28)
      ..close();

    final innerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFD700),
          Color.lerp(
            const Color(0xFFFFA500),
            const Color(0xFFFFD700),
            progress,
          )!,
          const Color(0xFFFFE066),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(innerPath, innerPaint);

    // Core (bright yellow-white)
    final corePath = Path()
      ..moveTo(w * 0.50, h * 0.52)
      ..cubicTo(w * 0.40, h * 0.62, w * 0.36, h * 0.72, w * 0.42, h * 0.82)
      ..cubicTo(w * 0.45, h * 0.90, w * 0.48, h * 0.94, w * 0.50, h * 0.95)
      ..cubicTo(w * 0.52, h * 0.94, w * 0.55, h * 0.90, w * 0.58, h * 0.82)
      ..cubicTo(w * 0.64, h * 0.72, w * 0.60, h * 0.62, w * 0.50, h * 0.52)
      ..close();

    final corePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFDE0), Color(0xFFFFE082)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(corePath, corePaint);
  }

  @override
  bool shouldRepaint(_StreakFirePainter oldDelegate) =>
      oldDelegate.progress != progress;
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

class _ComingSoonPage extends StatelessWidget {
  final String title;
  const _ComingSoonPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF4B5563),
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEEEF0)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFB7185), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Walking mode is under development.\nStay tuned for updates!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
