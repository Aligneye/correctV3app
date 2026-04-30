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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:correctv1/home/meditation_page.dart';
import 'package:correctv1/discover/discover_page.dart';
import 'package:correctv1/home/ongoing_therapy_page.dart';
import 'package:correctv1/home/therapy_page.dart';
import 'package:correctv1/home/training_page.dart';
import 'package:correctv1/analytics/analytics_screen.dart';
import 'package:correctv1/sessions/sessions_history_page.dart';
import 'package:correctv1/settings/settings_page.dart';
import 'package:correctv1/components/nav_bar.dart';
import 'package:correctv1/calibration/calibration_page.dart';
import 'package:correctv1/services/device_manager.dart';
import 'package:correctv1/services/session_repository.dart';
import 'package:correctv1/services/therapy_pattern_names.dart';
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
  int _batteryLevel = 0;
  _ModeControlType _selectedMode = _ModeControlType.track;
  _PostureTimingType _selectedPostureTiming = _PostureTimingType.instant;
  int _selectedDifficulty = 25;
  int _therapyDurationMinutes = 10;
  Timer? _therapyCountdownTimer;
  int _therapyRemainingSeconds = 0;
  Timer? _liveSessionTicker;
  String? _liveDisplaySessionId;
  int _liveDisplayDurationSec = 0;
  bool _liveDisplayHasFrame = false;
  bool _hasShownStartupConnectSheet = false;
  bool _isFindingDevice = false;
  bool _syncBannerDismissed = false;
  bool _isLoadingOfflineSessions = true;
  int _lastSyncTick = 0;
  List<SessionData> _offlineSessions = const <SessionData>[];
  TodayStats? _todayStats;
  StreakStats? _streakStats;
  bool _streakPopupCheckedThisSession = false;
  final GlobalKey _streakTileKey = GlobalKey();

  static final List<_QuickMode> _quickModes = [
    _QuickMode(
      title: 'Therapy',
      icon: Icons.graphic_eq,
      gradient: AppTheme.vibrationTherapyGradient.colors,
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Training',
      icon: Icons.accessibility_new_rounded,
      gradient: AppTheme.goodPostureGradient.colors,
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Walking',
      icon: Icons.directions_walk_rounded,
      gradient: AppTheme.alignWalkGradient.colors,
      targetIndex: 1,
    ),
    _QuickMode(
      title: 'Breathe',
      icon: Icons.self_improvement,
      gradient: AppTheme.meditationGradient.colors,
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
      final isLiveMode =
          isTherapyMode ||
          reading.mode.trim().toUpperCase() == 'TRAINING' ||
          reading.mode.trim().toUpperCase() == 'POSTURE';
      final reportedRemainingSec = reading.therapyRemainingSeconds;
      setState(() {
        _syncBannerDismissed = false;
        _postureAngle = reading.angle;
        _isBadPosture = reading.isBadPosture;
        _postureStatus = reading.isBadPosture ? 'Bad posture' : 'Good posture';
        _batteryLevel = reading.batteryPercentage.clamp(0, 100);
        _selectedMode = _modeFromDevice(reading.mode);
        _selectedPostureTiming = _postureTimingFromDevice(reading.subMode);
        _therapyDurationMinutes = _therapyMinutesFromDevice(reading.subMode);
        if (_kDifficultyOptions.contains(reading.difficultyDeg)) {
          _selectedDifficulty = reading.difficultyDeg;
        }
        if (isTherapyMode && reportedRemainingSec > 0) {
          // Snap countdown to firmware ground truth on every frame, then
          // make sure the 1 Hz local ticker is running so the number keeps
          // smoothly decreasing in the gap until the next BLE frame. Without
          // this the timer froze between frames (2-5 s of BLE jitter) and
          // visibly "stuck" — especially during a page transition when the
          // reading stream briefly pauses on the old route.
          _therapyRemainingSeconds = reportedRemainingSec;
          _ensureTherapyCountdownRunning();
        } else if (!isTherapyMode) {
          _therapyCountdownTimer?.cancel();
          _therapyRemainingSeconds = 0;
        }
        // Pattern names used to be mirrored into local fields here; the
        // mini card and ongoing page now read straight from the device
        // service's sticky cache, so there's nothing to do on this side.
        if (isLiveMode) {
          _snapLiveSessionDuration(reading);
        } else {
          _stopLiveSessionTicker(
            clearFrame: _deviceManager.activeSessionId.value == null,
          );
        }
      });
    });

    unawaited(_handleStartupDevicePrompt());
    _lastSyncTick = _deviceManager.syncCompletedTick.value;
    _deviceManager.syncCompletedTick.addListener(_handleSessionSyncFinished);
    _deviceManager.isSyncing.addListener(_handleSyncingChanged);
    _deviceManager.activeSessionId.addListener(_handleActiveSessionChanged);
    _deviceService.connectionStatus.addListener(_handleConnectionStatusChanged);
    unawaited(_hydrateCachedStreak());
    unawaited(_loadOfflineSessions());
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _deviceManager.syncCompletedTick.removeListener(_handleSessionSyncFinished);
    _deviceManager.isSyncing.removeListener(_handleSyncingChanged);
    _deviceManager.activeSessionId.removeListener(_handleActiveSessionChanged);
    _deviceService.connectionStatus.removeListener(
      _handleConnectionStatusChanged,
    );
    _therapyCountdownTimer?.cancel();
    _liveSessionTicker?.cancel();
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
    final id = _deviceManager.activeSessionId.value;
    if (id == null) {
      _stopLiveSessionTicker(clearFrame: true);
    } else {
      _liveDisplaySessionId = id;
      _syncLiveSessionTickerWithConnection();
    }
    unawaited(_loadOfflineSessions());
  }

  void _handleConnectionStatusChanged() {
    _syncLiveSessionTickerWithConnection();
  }

  void _syncLiveSessionTickerWithConnection() {
    final connected =
        _deviceService.connectionStatus.value ==
        DeviceConnectionStatus.connected;
    final hasLiveSession = _deviceManager.activeSessionId.value != null;
    if (connected && hasLiveSession && _liveDisplayHasFrame) {
      _ensureLiveSessionTicker();
    } else {
      _liveSessionTicker?.cancel();
      _liveSessionTicker = null;
      if (mounted) setState(() {});
    }
  }

  void _ensureLiveSessionTicker() {
    if (_liveSessionTicker != null) return;
    _liveSessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _liveSessionTicker?.cancel();
        _liveSessionTicker = null;
        return;
      }
      if (_deviceService.connectionStatus.value !=
              DeviceConnectionStatus.connected ||
          _deviceManager.activeSessionId.value == null ||
          !_liveDisplayHasFrame) {
        return;
      }
      setState(() {
        _liveDisplayDurationSec++;
      });
    });
  }

  void _stopLiveSessionTicker({required bool clearFrame}) {
    _liveSessionTicker?.cancel();
    _liveSessionTicker = null;
    if (clearFrame) {
      _liveDisplayHasFrame = false;
      _liveDisplaySessionId = null;
      _liveDisplayDurationSec = 0;
    }
  }

  void _snapLiveSessionDuration(PostureReading reading) {
    final activeId = _deviceManager.activeSessionId.value;
    if (activeId == null) return;
    _liveDisplaySessionId = activeId;
    _liveDisplayDurationSec = _liveDurationFromReading(reading);
    _liveDisplayHasFrame = true;
    _ensureLiveSessionTicker();
  }

  int _liveDurationFromReading(PostureReading reading) {
    if (reading.liveSessionElapsedSeconds > 0) {
      return reading.liveSessionElapsedSeconds;
    }
    if (reading.mode.trim().toUpperCase() == 'THERAPY' &&
        reading.therapyElapsedSeconds > 0) {
      return reading.therapyElapsedSeconds;
    }
    return _liveDisplayDurationSec;
  }

  List<SessionData> _sessionsWithLiveDisplayDuration() {
    if (!_liveDisplayHasFrame || _liveDisplaySessionId == null) {
      return _offlineSessions;
    }
    return [
      for (final session in _offlineSessions)
        if (session.isLive && session.dbId == _liveDisplaySessionId)
          SessionData(
            id: session.id,
            dbId: session.dbId,
            type: session.type,
            name: session.name,
            time: session.time,
            date: session.date,
            duration: _formatSessionDuration(_liveDisplayDurationSec),
            durationSec: _liveDisplayDurationSec,
            alerts: session.alerts,
            score: session.score,
            pattern: session.pattern,
            wrongDurSec: session.wrongDurSec,
            isLive: session.isLive,
            tsSynced: session.tsSynced,
            cloudSynced: session.cloudSynced,
            startTs: session.startTs,
            postureEvents: session.postureEvents,
            therapyPatterns: session.therapyPatterns,
            therapyPatternEvents: session.therapyPatternEvents,
          )
        else
          session,
    ];
  }

  static String _formatSessionDuration(int durationSec) {
    if (durationSec <= 0) return '0s';
    if (durationSec < 60) return '${durationSec}s';
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    if (seconds == 0) return '$minutes min';
    return '$minutes min ${seconds}s';
  }

  void _handleSessionSyncFinished() {
    final tick = _deviceManager.syncCompletedTick.value;
    if (tick == _lastSyncTick) return;
    _lastSyncTick = tick;
    unawaited(_loadOfflineSessions());
  }

  static _StatItemData _goodPostureStatItem(TodayStats? stats) {
    const gradient = AppTheme.alignWalkGradient;
    const icon = Icons.auto_awesome_rounded;
    const label = 'Good posture';

    if (stats == null) {
      return const _StatItemData(
        value: '-',
        label: label,
        trendText: 'Loading…',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    if (!stats.hasTodayPostureData) {
      return const _StatItemData(
        value: '—',
        label: label,
        trendText: 'Do a training',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    final String trendText;
    final bool positive;
    if (!stats.yesterdayHasPostureData) {
      trendText = 'First today';
      positive = true;
    } else if (stats.postureDeltaVsYesterday == 0) {
      trendText = 'Same';
      positive = true;
    } else {
      final delta = stats.postureDeltaVsYesterday;
      final direction = delta > 0 ? 'more' : 'less';
      trendText = '${delta.abs()}% $direction';
      positive = delta > 0;
    }

    return _StatItemData(
      value: '${stats.todayPct}',
      unit: '%',
      label: label,
      trendText: trendText,
      icon: icon,
      gradient: gradient,
      positiveTrend: positive,
      trendNeutral:
          !stats.yesterdayHasPostureData || stats.postureDeltaVsYesterday == 0,
    );
  }

  static _StatItemData _trackedTimeStatItem(TodayStats? stats) {
    const gradient = AppTheme.trackingGradient;
    const icon = Icons.monitor_heart_outlined;
    const label = 'Tracked time';

    if (stats == null) {
      return const _StatItemData(
        value: '—',
        label: label,
        trendText: 'Loading…',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    if (!stats.hasTodayTrackedData) {
      return const _StatItemData(
        value: '0',
        unit: 'min',
        label: label,
        trendText: 'No sessions',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    final display = _formatTrackedValue(stats.todayTrackedSec);

    final String trendText;
    final bool positive;
    final bool neutral;
    if (!stats.yesterdayHasTrackedData) {
      trendText = 'First today';
      positive = true;
      neutral = true;
    } else {
      final deltaSec = stats.trackedDeltaSecVsYesterday;
      if (deltaSec == 0) {
        trendText = 'Same';
        positive = true;
        neutral = true;
      } else {
        final direction = deltaSec > 0 ? 'more' : 'less';
        trendText = '${_formatDeltaDuration(deltaSec.abs())} $direction';
        positive = deltaSec > 0;
        neutral = false;
      }
    }

    return _StatItemData(
      value: display.value,
      unit: display.unit,
      label: label,
      trendText: trendText,
      icon: icon,
      gradient: gradient,
      positiveTrend: positive,
      trendNeutral: neutral,
    );
  }

  static _DisplayValue _formatTrackedValue(int totalSec) {
    if (totalSec < 3600) {
      final minutes = (totalSec / 60).round();
      return _DisplayValue('$minutes', 'min');
    }
    final hours = totalSec / 3600.0;
    return _DisplayValue(hours.toStringAsFixed(1), 'h');
  }

  static String _formatDeltaDuration(int seconds) {
    if (seconds < 3600) {
      final minutes = (seconds / 60).round();
      return '${minutes}min';
    }
    final hours = seconds / 3600.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  static _StatItemData _sessionsStatItem(TodayStats? stats) {
    const gradient = AppTheme.meditationGradient;
    const icon = Icons.model_training;
    const label = 'Sessions done';

    if (stats == null) {
      return const _StatItemData(
        value: '—',
        label: label,
        trendText: 'Loading…',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    if (!stats.hasTodaySessions) {
      return const _StatItemData(
        value: '0',
        label: label,
        trendText: 'Do a session',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    final String trendText;
    final bool positive;
    final bool neutral;
    if (!stats.yesterdayHasSessions) {
      trendText = 'First today';
      positive = true;
      neutral = true;
    } else {
      final delta = stats.sessionCountDeltaVsYesterday;
      if (delta == 0) {
        trendText = 'Same';
        positive = true;
        neutral = true;
      } else {
        final direction = delta > 0 ? 'more' : 'less';
        trendText = '${delta.abs()} $direction';
        positive = delta > 0;
        neutral = false;
      }
    }

    return _StatItemData(
      value: '${stats.todaySessionCount}',
      label: label,
      trendText: trendText,
      icon: icon,
      gradient: gradient,
      positiveTrend: positive,
      trendNeutral: neutral,
    );
  }

  static _StatItemData _lastSessionStatItem(
    List<SessionData> sessions,
    bool isLoading,
  ) {
    const label = 'Last session';

    if (isLoading && sessions.isEmpty) {
      return const _StatItemData(
        value: '-',
        label: label,
        trendText: 'Loading...',
        icon: Icons.history_rounded,
        gradient: AppTheme.meditationGradient,
        trendNeutral: true,
      );
    }

    if (sessions.isEmpty) {
      return const _StatItemData(
        value: 'None',
        label: label,
        trendText: 'Do a session',
        icon: Icons.history_rounded,
        gradient: AppTheme.meditationGradient,
        trendNeutral: true,
      );
    }

    final session = sessions.first;
    final isTraining = session.type == SessionType.posture;
    return _StatItemData(
      value: isTraining ? 'Training' : 'Therapy',
      label: label,
      trendText: session.isLive ? 'Running now' : session.duration,
      icon: isTraining
          ? Icons.accessibility_new_rounded
          : Icons.graphic_eq_rounded,
      gradient: isTraining
          ? AppTheme.trainingGradient
          : AppTheme.vibrationTherapyGradient,
      trendNeutral: true,
    );
  }

  static _StatItemData _therapyTimeStatItem(TodayStats? stats) {
    return _durationStatItem(
      stats: stats,
      label: 'Therapy time',
      icon: Icons.graphic_eq,
      gradient: AppTheme.vibrationTherapyGradient,
      emptyCta: 'Do a therapy',
      todaySec: stats?.todayTherapyDurationSec ?? 0,
      yesterdaySec: stats?.yesterdayTherapyDurationSec ?? 0,
      yesterdayHasData: stats?.yesterdayHasTherapyData ?? false,
    );
  }

  static _StatItemData _trainingTimeStatItem(TodayStats? stats) {
    return _durationStatItem(
      stats: stats,
      label: 'Training time',
      icon: Icons.accessibility_new_rounded,
      gradient: AppTheme.trainingGradient,
      emptyCta: 'Do a training',
      todaySec: stats?.todayPostureDurationSec ?? 0,
      yesterdaySec: stats?.yesterdayPostureDurationSec ?? 0,
      yesterdayHasData: stats?.yesterdayHasPostureData ?? false,
    );
  }

  static _StatItemData _durationStatItem({
    required TodayStats? stats,
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    required String emptyCta,
    required int todaySec,
    required int yesterdaySec,
    required bool yesterdayHasData,
  }) {
    if (stats == null) {
      return _StatItemData(
        value: '—',
        label: label,
        trendText: 'Loading…',
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    if (todaySec <= 0) {
      return _StatItemData(
        value: '0',
        unit: 'min',
        label: label,
        trendText: emptyCta,
        icon: icon,
        gradient: gradient,
        trendNeutral: true,
      );
    }

    final display = _formatTrackedValue(todaySec);

    final String trendText;
    final bool positive;
    final bool neutral;
    if (!yesterdayHasData) {
      trendText = 'First today';
      positive = true;
      neutral = true;
    } else {
      final deltaSec = todaySec - yesterdaySec;
      if (deltaSec == 0) {
        trendText = 'Same';
        positive = true;
        neutral = true;
      } else {
        final direction = deltaSec > 0 ? 'more' : 'less';
        trendText = '${_formatDeltaDuration(deltaSec.abs())} $direction';
        positive = deltaSec > 0;
        neutral = false;
      }
    }

    return _StatItemData(
      value: display.value,
      unit: display.unit,
      label: label,
      trendText: trendText,
      icon: icon,
      gradient: gradient,
      positiveTrend: positive,
      trendNeutral: neutral,
    );
  }

  Future<void> _loadOfflineSessions() async {
    if (!mounted) return;
    setState(() => _isLoadingOfflineSessions = true);
    try {
      final sessions = await _sessionRepository.fetchByPeriod(
        'all',
        liveSessionId: _deviceManager.activeSessionId.value,
      );
      final todayStats = await _sessionRepository.fetchTodayStats();
      final streakStats = await _sessionRepository.fetchStreakStats();
      if (!mounted) return;
      debugPrint('HomeDashboard: loaded ${sessions.length} sessions');
      setState(() {
        _offlineSessions = sessions.take(5).toList(growable: false);
        _todayStats = todayStats;
        _streakStats = streakStats;
        _isLoadingOfflineSessions = false;
      });
      unawaited(_persistStreakCache(streakStats));
      unawaited(_maybeShowStreakPopup(streakStats));
    } catch (e) {
      debugPrint('HomeDashboard: _loadOfflineSessions error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingOfflineSessions = false;
      });
    }
  }

  static const String _kStreakPrefsLastDay = 'streak_popup_last_day';
  static const String _kStreakPrefsLastValue = 'streak_popup_last_value';
  static const String _kStreakPrefsCachedHighest = 'streak_cached_highest';

  Future<void> _persistStreakCache(StreakStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kStreakPrefsLastValue, stats.currentStreak);
      await prefs.setInt(_kStreakPrefsCachedHighest, stats.highestStreak);
    } catch (e) {
      debugPrint('HomeDashboard: _persistStreakCache error: $e');
    }
  }

  Future<void> _hydrateCachedStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStreak = prefs.getInt(_kStreakPrefsLastValue) ?? 0;
      final cachedHighest = prefs.getInt(_kStreakPrefsCachedHighest) ?? 0;
      if (!mounted || _streakStats != null) return;
      setState(() {
        _streakStats = StreakStats(
          currentStreak: cachedStreak,
          highestStreak: cachedHighest,
          todayActive: false,
          todayStreakDay: DateTime.now(),
        );
      });
    } catch (e) {
      debugPrint('HomeDashboard: _hydrateCachedStreak error: $e');
    }
  }

  Future<void> _maybeShowStreakPopup(StreakStats stats) async {
    if (_streakPopupCheckedThisSession) return;
    _streakPopupCheckedThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    final lastDayStr = prefs.getString(_kStreakPrefsLastDay);
    final lastValue = prefs.getInt(_kStreakPrefsLastValue) ?? 0;

    final todayKey = _streakDayKey(stats.todayStreakDay);
    if (lastDayStr == todayKey) {
      return; // already shown this streak day
    }

    final kind = _classifyStreakEvent(
      previousStreak: lastValue,
      currentStreak: stats.currentStreak,
    );

    await prefs.setString(_kStreakPrefsLastDay, todayKey);
    await prefs.setInt(_kStreakPrefsLastValue, stats.currentStreak);

    if (kind == null || !mounted) return;

    // Defer to post-frame so we don't fight the initial build animations.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => _StreakPopup(
          stats: stats,
          kind: kind,
          resolveTarget: _resolveStreakTileRect,
        ),
      );
    });
  }

  Rect? _resolveStreakTileRect() {
    final ctx = _streakTileKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  static String _streakDayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static _StreakPopupKind? _classifyStreakEvent({
    required int previousStreak,
    required int currentStreak,
  }) {
    if (currentStreak > previousStreak) return _StreakPopupKind.increased;
    if (currentStreak < previousStreak) return _StreakPopupKind.broken;
    return null; // unchanged — no popup
  }

  /// Therapy is "live" from the home-page perspective when the device is in
  /// therapy mode and we still have time on the clock. Used to swap the
  /// live-posture card for a compact ongoing-therapy preview.
  bool get _isTherapyLive =>
      _selectedMode == _ModeControlType.therapy &&
      _therapyRemainingSeconds > 0;

  void _startTherapyCountdown(int minutes) {
    _therapyCountdownTimer?.cancel();
    setState(() {
      _therapyRemainingSeconds = minutes * 60;
    });
    _ensureTherapyCountdownRunning();
  }

  /// Idempotent: spin up the 1 Hz ticker if it isn't already alive. Called
  /// from the BLE reading handler on every frame so the countdown keeps
  /// advancing smoothly between frames instead of freezing until the next
  /// firmware packet arrives.
  void _ensureTherapyCountdownRunning() {
    if (_therapyCountdownTimer?.isActive ?? false) return;
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

    // When already connected, show the management sheet. In every other
    // state (including while an auto-connect attempt is in flight) tapping
    // the pill should take the user straight to the connect page — it will
    // surface the ongoing attempt and auto-pop once the pod is connected.
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

  /// Launch the immersive therapy screen using the device's current default
  /// therapy configuration. Wired to the Therapy button inside the Default
  /// Mode card — the `MODE=THERAPY` command is sent by the surrounding
  /// handler before this fires, so firmware is already configured.
  Future<void> _openOngoingTherapyWithDefaults() async {
    if (_deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      return;
    }
    // Default intensity mirrors the therapy page's initial slider position so
    // the ongoing UI and Supabase row carry consistent values when the user
    // hasn't manually picked one.
    const int defaultIntensityLevel = 2;
    DeviceManager().primeTherapyContext(
      targetPoint: null,
      intensityLevel: defaultIntensityLevel,
      plannedDurationMinutes: _therapyDurationMinutes,
    );
    await _deviceService.sendTherapyStart(
      durationMinutes: _therapyDurationMinutes,
      intensityLevel: defaultIntensityLevel,
    );
    if (!mounted) return;
    _pushOngoingTherapyPage(intensity: defaultIntensityLevel);
  }

  /// Variant for the mini card tap: therapy is already running on the pod,
  /// so we just navigate without re-issuing start/prime commands.
  void _openOngoingTherapyFromHome() {
    if (_deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      return;
    }
    _pushOngoingTherapyPage(intensity: 2);
  }

  void _pushOngoingTherapyPage({required int intensity}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            OngoingTherapyPage(
              deviceService: _deviceService,
              durationMinutes: _therapyDurationMinutes,
              intensity: intensity,
              targetPointName: 'Default',
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation),
              child: child,
            ),
          );
        },
      ),
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
    if (minutes == 10 || minutes == 20 || minutes == 30) {
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
                          gradient: AppTheme.goodPostureGradient,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            widget.onOpenTraining();
                          },
                        ),
                        const SizedBox(height: 12),
                        _AllModesSheetItem(
                          title: 'Vibration therapy mode',
                          subtitle: 'Acupressure vibration therapy',
                          icon: Icons.graphic_eq,
                          gradient: AppTheme.vibrationTherapyGradient,
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
                child: _StatsSummaryCard(
                  streakDays: _streakStats?.currentStreak ?? 0,
                  streakTodayActive: _streakStats?.todayActive ?? false,
                  streakTileKey: _streakTileKey,
                  items: [
                    _lastSessionStatItem(
                      _offlineSessions,
                      _isLoadingOfflineSessions,
                    ),
                    _goodPostureStatItem(_todayStats),
                    _trainingTimeStatItem(_todayStats),
                    _therapyTimeStatItem(_todayStats),
                    _sessionsStatItem(_todayStats),
                    _trackedTimeStatItem(_todayStats),
                  ],
                ),
              ),
              _kSectionSpacing,
              _StaggeredFadeSlide(
                controller: _controller,
                delayMs: 200,
                // While therapy is in progress, swap the live-posture card
                // out for a compact preview of the ongoing therapy session —
                // tap it to jump into the full immersive page.
                child: _isTherapyLive
                    ? _MiniOngoingTherapyCard(
                        deviceService: _deviceService,
                        totalMinutes: _therapyDurationMinutes,
                        onTap: _openOngoingTherapyFromHome,
                      )
                    : _PostureGaugeCard(
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
                    // Therapy button inside Default Mode should also surface
                    // the immersive ongoing-therapy screen using the current
                    // defaults. The MODE=THERAPY command was just sent above,
                    // so the device is already configured.
                    if (mode == _ModeControlType.therapy) {
                      unawaited(_openOngoingTherapyWithDefaults());
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
                          sessions: _sessionsWithLiveDisplayDuration(),
                          isLoading: _isLoadingOfflineSessions,
                          isSyncing: isSyncing,
                          isDeviceDisconnected:
                              status == DeviceConnectionStatus.disconnected &&
                              !_syncBannerDismissed,
                          isDeviceConnecting:
                              status == DeviceConnectionStatus.connecting,
                          onViewAll: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const SessionsHistoryPage(),
                            ),
                          ),
                          onSessionTap: (session) =>
                              showSessionDetailSheet(context, session: session),
                          onSyncNow: () => unawaited(_handleSyncNow()),
                        );
                      },
                    );
                  },
                ),
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
      return;
    }
    try {
      await _bluetoothManager.connect();
    } catch (e) {
      // User denied or connection failed — stop auto-reconnect and hide banner.
      await _bluetoothManager.setAutoReconnect(false);
      if (!mounted) return;
      setState(() => _syncBannerDismissed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth connection cancelled. '
            'Tap the connect button when ready.',
          ),
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

/// Compact preview of an in-progress therapy session shown in the home
/// dashboard in place of the live-posture gauge. Mirrors the visual language
/// of [OngoingTherapyPage] — soft pink gradient, gentle breathing orb —
/// while staying small enough to sit in the stats column. Tapping anywhere
/// on the card opens the full immersive page.
class _MiniOngoingTherapyCard extends StatefulWidget {
  final AlignEyeDeviceService deviceService;
  final int totalMinutes;
  final VoidCallback onTap;

  const _MiniOngoingTherapyCard({
    required this.deviceService,
    required this.totalMinutes,
    required this.onTap,
  });

  @override
  State<_MiniOngoingTherapyCard> createState() =>
      _MiniOngoingTherapyCardState();
}

class _MiniOngoingTherapyCardState extends State<_MiniOngoingTherapyCard>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _wavesController;

  // Timer state mirrors the immersive page so the home mini card reads
  // exactly the same values. Seeded with -1 / 0 until the first therapy
  // frame lands.
  StreamSubscription<PostureReading>? _readingSub;
  Timer? _localTicker;

  int _totalRemainingSeconds = -1;
  int _totalElapsedSeconds = 0;
  int _totalDurationSeconds = 0;
  int _frameRemainingSeconds = -1;

  int _lastPatternStartElapsed = 0;
  String _lastPatternName = '';
  int? _lastKnownPatternDurationSeconds;

  @override
  void initState() {
    super.initState();
    _totalDurationSeconds = widget.totalMinutes * 60;
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _wavesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    // Seed from the service's sticky cache so opening a fresh home page
    // mid-session doesn't flash zeros.
    final cachedPattern = widget.deviceService.latestTherapyPatternName;
    if (cachedPattern.isNotEmpty) {
      _lastPatternName = _stripSessionMeta(cachedPattern);
    }

    _consumeReading(widget.deviceService.currentReading.value);
    _readingSub = widget.deviceService.readings.listen(_handleReading);

    widget.deviceService.connectionStatus.addListener(_handleConnectionStatus);
    _syncLocalTickerWithConnection();
  }

  @override
  void dispose() {
    _readingSub?.cancel();
    _localTicker?.cancel();
    widget.deviceService.connectionStatus
        .removeListener(_handleConnectionStatus);
    _breathController.dispose();
    _wavesController.dispose();
    super.dispose();
  }

  void _handleConnectionStatus() {
    _syncLocalTickerWithConnection();
  }

  void _syncLocalTickerWithConnection() {
    final connected = widget.deviceService.connectionStatus.value ==
        DeviceConnectionStatus.connected;
    if (connected) {
      _ensureLocalTicker();
    } else {
      _localTicker?.cancel();
      _localTicker = null;
      if (mounted) setState(() {});
    }
  }

  void _ensureLocalTicker() {
    if (_localTicker != null) return;
    // Align to the next wall-clock second boundary so this timer fires at
    // the same real-world instant as the immersive page's — zero visible
    // drift between the two surfaces.
    final now = DateTime.now();
    final msToNextSecond = 1000 - now.millisecond;
    _localTicker = Timer(Duration(milliseconds: msToNextSecond), () {
      if (!mounted) return;
      _runTick();
      _localTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          _localTicker?.cancel();
          _localTicker = null;
          return;
        }
        _runTick();
      });
    });
  }

  void _runTick() {
    if (_frameRemainingSeconds < 0) return;
    if (widget.deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      return;
    }
    final anchoredRemaining =
        widget.deviceService.therapyRemainingSecondsNow;
    final anchoredElapsed = widget.deviceService.therapyElapsedSecondsNow;
    setState(() {
      if (anchoredRemaining >= 0) {
        _totalRemainingSeconds = anchoredRemaining;
      } else if (_totalRemainingSeconds > 0) {
        _totalRemainingSeconds -= 1;
      }
      if (anchoredElapsed > _totalElapsedSeconds) {
        _totalElapsedSeconds = anchoredElapsed;
      } else {
        _totalElapsedSeconds += 1;
      }
    });
  }

  void _handleReading(PostureReading reading) {
    _consumeReading(reading);
  }

  void _consumeReading(PostureReading? reading) {
    if (reading == null || !mounted) return;
    final isTherapy = reading.mode.toUpperCase() == 'THERAPY';
    if (!isTherapy) return;

    final elapsed = reading.therapyElapsedSeconds;
    final remaining = reading.therapyRemainingSeconds;
    final cleanPatternName = _stripSessionMeta(reading.therapyPattern.trim());

    setState(() {
      _frameRemainingSeconds = remaining;
      _totalElapsedSeconds = elapsed;
      _totalRemainingSeconds = remaining;
      final firmwareTotal = elapsed + remaining;
      if (firmwareTotal > 0) {
        _totalDurationSeconds = firmwareTotal;
      }
      _ensureLocalTicker();

      if (cleanPatternName != _lastPatternName) {
        if (_lastPatternName.isNotEmpty) {
          final prevDuration = elapsed - _lastPatternStartElapsed;
          if (prevDuration > 0) {
            _lastKnownPatternDurationSeconds = prevDuration;
          }
        }
        _lastPatternName = cleanPatternName;
        _lastPatternStartElapsed = elapsed;
      }
    });
  }

  String _stripSessionMeta(String raw) {
    final bracket = raw.indexOf('[');
    if (bracket <= 0) return raw;
    return raw.substring(0, bracket).trim();
  }

  int get _patternElapsedSeconds {
    if (_totalElapsedSeconds <= 0) return 0;
    return math.max(0, _totalElapsedSeconds - _lastPatternStartElapsed);
  }

  int get _patternDurationSeconds {
    final guess =
        _lastKnownPatternDurationSeconds ?? (_totalDurationSeconds ~/ 7);
    return math.max(20, guess);
  }

  String _formatMMSS(int totalSeconds) {
    final safe = math.max(0, totalSeconds);
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sessionProgress = _totalDurationSeconds == 0
        ? 0.0
        : (_totalElapsedSeconds / _totalDurationSeconds).clamp(0.0, 1.0);
    final remainingForUi = _totalRemainingSeconds >= 0
        ? _totalRemainingSeconds
        : _totalDurationSeconds;
    final totalMinutesForUi = _totalDurationSeconds > 0
        ? (_totalDurationSeconds / 60).round()
        : widget.totalMinutes;
    final patternElapsed = _patternElapsedSeconds;
    final patternProgress =
        (patternElapsed / _patternDurationSeconds).clamp(0.0, 1.0);

    final friendlyPattern = friendlyTherapyPatternLabel(_lastPatternName);
    final pillLabel =
        friendlyPattern.isEmpty || friendlyPattern.toLowerCase() ==
                'preparing pattern...' ||
            friendlyPattern.toLowerCase() == 'waiting for therapy'
        ? 'Preparing pattern…'
        : friendlyPattern;

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF4F6),
                Colors.white,
                Color(0xFFFDF2F8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Therapy in Progress',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  height: 260,
                  width: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _breathController,
                          _wavesController,
                        ]),
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(260, 260),
                            painter: _MiniTherapyOrbPainter(
                              breathValue: _breathController.value,
                              wavesValue: _wavesController.value,
                              sessionProgress:
                                  sessionProgress.clamp(0.0, 1.0),
                              patternProgress: patternProgress,
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SESSION LEFT',
                              style: TextStyle(
                                color: Color(0xFFFF2B62),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatMMSS(remainingForUi),
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 42,
                                fontWeight: FontWeight.w300,
                                height: 1.0,
                                letterSpacing: -1.0,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'of ${totalMinutesForUi}m',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: 32,
                              height: 1,
                              color: const Color(0xFFFCE7F3),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _formatMMSS(patternElapsed),
                              style: const TextStyle(
                                color: Color(0xFFFF2B62),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                                letterSpacing: 0.2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'current pattern',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _NowPatternPill(label: pillLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pink `NOW <pattern>` capsule that sits below the orb, mirroring the
/// reference UI shot. `NOW` is a white chip on a saturated pink pill; the
/// current pattern name sits next to it in bold white.
class _NowPatternPill extends StatelessWidget {
  final String label;

  const _NowPatternPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF3B75), Color(0xFFED2CA6)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'NOW',
              style: TextStyle(
                color: Color(0xFFFF2B62),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTherapyOrbPainter extends CustomPainter {
  final double breathValue;
  final double wavesValue;
  final double sessionProgress;
  final double patternProgress;

  _MiniTherapyOrbPainter({
    required this.breathValue,
    required this.wavesValue,
    required this.sessionProgress,
    required this.patternProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Layered layout mirrors the immersive page: outer session ring, inner
    // pattern ring, then the breathing orb itself.
    final outerRadius = size.width * 0.46;
    final innerRadius = outerRadius - 14;
    final baseRadius = innerRadius - 12;

    final breath = Curves.easeInOut.transform(breathValue);

    const ringCount = 5;
    for (int i = 0; i < ringCount; i++) {
      final phase = (wavesValue + i / ringCount) % 1.0;
      final eased = Curves.easeOut.transform(phase);
      final waveRadius = baseRadius * (0.96 + eased * 0.60);
      final aliveFade = math.sin(phase * math.pi);
      final opacity = (aliveFade * 0.18).clamp(0.0, 1.0);
      final wavePaint = Paint()
        ..color = const Color(0xFFFF7DA0).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      canvas.drawCircle(center, waveRadius, wavePaint);
    }

    final resonancePaint = Paint()
      ..color = const Color(0xFFFF2B62).withValues(alpha: 0.08 + breath * 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(
      center,
      baseRadius * (1.10 + breath * 0.05),
      resonancePaint,
    );

    final breathRadius = baseRadius * (1.0 + breath * 0.045);

    final ambientHaloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFB4C5).withValues(alpha: 0.28),
          const Color(0xFFFFB4C5).withValues(alpha: 0.0),
        ],
        stops: const [0.25, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: breathRadius * 1.7),
      );
    canvas.drawCircle(center, breathRadius * 1.7, ambientHaloPaint);

    final orbRect = Rect.fromCircle(center: center, radius: breathRadius);
    final orbPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.15, -0.20),
        radius: 1.05,
        colors: [
          Color(0xFFFFF5F7),
          Color(0xFFFFE4E6),
          Color(0xFFFDD5E0),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(orbRect);
    canvas.drawCircle(center, breathRadius, orbPaint);

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.7,
        colors: [
          Colors.white.withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(orbRect);
    canvas.drawCircle(center, breathRadius, highlightPaint);

    final orbBorderPaint = Paint()
      ..color = const Color(0xFFFF2B62).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, breathRadius, orbBorderPaint);

    // Inner ring — current-pattern progress.
    _drawRing(
      canvas,
      center,
      innerRadius,
      patternProgress.clamp(0.0, 1.0),
      strokeWidth: 4,
      trackColor: const Color(0xFFFCE7F3),
      gradientColors: const [Color(0xFFFF7DA0), Color(0xFFFF2B62)],
    );

    // Outer ring — total session progress.
    _drawRing(
      canvas,
      center,
      outerRadius,
      sessionProgress.clamp(0.0, 1.0),
      strokeWidth: 6,
      trackColor: const Color(0xFFFFE4E6),
      gradientColors: const [Color(0xFFFF1F5B), Color(0xFFED2CA6)],
    );
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double progress, {
    required double strokeWidth,
    required Color trackColor,
    required List<Color> gradientColors,
  }) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: gradientColors,
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTherapyOrbPainter oldDelegate) {
    return oldDelegate.breathValue != breathValue ||
        oldDelegate.wavesValue != wavesValue ||
        oldDelegate.sessionProgress != sessionProgress ||
        oldDelegate.patternProgress != patternProgress;
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

        // Status banner: disconnect
        if (isDeviceDisconnected) ...[
          const SizedBox(height: 12),
          _DisconnectedBanner(
            isReconnecting: isDeviceConnecting,
            onSyncNow: onSyncNow,
          ),
        ],

        const SizedBox(height: 12),

        if (isLoading && sessions.isEmpty)
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
    final modeGradient = isPosture
        ? AppTheme.goodPostureGradient
        : AppTheme.vibrationTherapyGradient;
    final accent = isPosture
        ? AppTheme.goodPostureStart
        : const Color(0xFF60A5FA);
    final patternName = session.pattern == null
        ? null
        : therapyPatternName(session.pattern!);

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
                  gradient: LinearGradient(
                    colors: modeGradient.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPosture
                      ? Icons.accessibility_new_rounded
                      : Icons.graphic_eq,
                  size: 19,
                  color: Colors.white,
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
              else if (!isPosture && patternName != null)
                Text(
                  patternName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
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
    final postureEventCount = session.postureEvents?.length ?? session.alerts;
    final correctionCount = session.postureEvents
        ?.where((event) => event.wasCorrected)
        .length;
    final playedTherapyEvents = session.therapyPatternEvents
        ?.where((event) => event.durationSec > 0)
        .toList(growable: false);
    final therapyPatternCount =
        playedTherapyEvents?.length ??
        session.therapyPatterns?.length ??
        (session.pattern == null ? null : 1);
    final lastPatternIndex =
        playedTherapyEvents?.lastOrNull?.patternIndex ??
        session.therapyPatternEvents?.lastOrNull?.patternIndex ??
        session.therapyPatterns?.lastOrNull ??
        session.pattern;
    final lastPatternName = lastPatternIndex == null
        ? null
        : therapyPatternName(lastPatternIndex);

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
                      ? AppTheme.goodPostureGradient.colors
                      : AppTheme.vibrationTherapyGradient.colors,
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
                      if (!session.cloudSynced && !session.isLive)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.cloud_off_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        session.time,
                        style: const TextStyle(fontSize: 10, color: _kTextHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _HomeSessionMiniStat(
                        value: session.duration,
                        label: 'Duration',
                      ),
                      if (isPosture && postureEventCount != null)
                        _HomeSessionMiniStat(
                          value: '$postureEventCount',
                          label: 'Slouches',
                        ),
                      if (isPosture && correctionCount != null)
                        _HomeSessionMiniStat(
                          value: '$correctionCount',
                          label: 'Corrected',
                        ),
                      if (isPosture && (session.wrongDurSec ?? 0) > 0)
                        _HomeSessionMiniStat(
                          value: _formatCompactDuration(session.wrongDurSec!),
                          label: 'Bad time',
                        ),
                      if (!isPosture && therapyPatternCount != null)
                        _HomeSessionMiniStat(
                          value: '$therapyPatternCount',
                          label: 'Patterns',
                        ),
                      if (!isPosture && lastPatternName != null)
                        _HomeSessionMiniStat(
                          value: lastPatternName,
                          label: 'Last pattern',
                        ),
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

  static String _formatCompactDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    return rem == 0 ? '${minutes}m' : '${minutes}m ${rem}s';
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
  final ValueChanged<_ModeControlType> onModeSelected;
  final ValueChanged<_PostureTimingType> onPostureTimingSelected;
  final ValueChanged<int> onDifficultySelected;

  const _ModeControlCard({
    required this.selectedMode,
    required this.selectedPostureTiming,
    required this.selectedDifficulty,
    required this.onModeSelected,
    required this.onPostureTimingSelected,
    required this.onDifficultySelected,
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
          // Therapy-specific controls intentionally omitted here. Tapping
          // the Therapy mode button now launches the immersive Ongoing
          // Therapy page with the device's current defaults, so the home
          // card stays a lean mode selector.
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
            gradient: AppTheme.buttonBackground,
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
  final bool streakTodayActive;
  final Key? streakTileKey;

  const _StatsSummaryCard({
    required this.items,
    this.streakDays = 0,
    this.streakTodayActive = false,
    this.streakTileKey,
  });

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
            return SizedBox(
              key: streakTileKey,
              width: 132,
              child: _StreakTile(
                days: streakDays,
                todayActive: streakTodayActive,
              ),
            );
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
  final bool todayActive;

  const _StreakTile({required this.days, this.todayActive = true});

  @override
  State<_StreakTile> createState() => _StreakTileState();
}

class _StreakPalette {
  const _StreakPalette(this.bgStart, this.bgMid, this.bgEnd, this.shadow);
  final Color bgStart;
  final Color bgMid;
  final Color bgEnd;
  final Color shadow;
}

const List<_StreakPalette> _kStreakPalettes = <_StreakPalette>[
  _StreakPalette(
    Color(0xFF60A5FA),
    Color(0xFF3B82F6),
    Color(0xFF1D4ED8),
    Color(0xFF3B82F6),
  ),
  _StreakPalette(
    Color(0xFF818CF8),
    Color(0xFF6366F1),
    Color(0xFF4338CA),
    Color(0xFF6366F1),
  ),
  _StreakPalette(
    Color(0xFFA78BFA),
    Color(0xFF8B5CF6),
    Color(0xFF6D28D9),
    Color(0xFF8B5CF6),
  ),
  _StreakPalette(
    Color(0xFFC084FC),
    Color(0xFFA855F7),
    Color(0xFF7E22CE),
    Color(0xFFA855F7),
  ),
  _StreakPalette(
    Color(0xFFE879F9),
    Color(0xFFD946EF),
    Color(0xFFA21CAF),
    Color(0xFFD946EF),
  ),
  _StreakPalette(
    Color(0xFFF472B6),
    Color(0xFFEC4899),
    Color(0xFFBE185D),
    Color(0xFFEC4899),
  ),
  _StreakPalette(
    Color(0xFFFB7185),
    Color(0xFFF43F5E),
    Color(0xFFBE123C),
    Color(0xFFF43F5E),
  ),
  _StreakPalette(
    Color(0xFFF87171),
    Color(0xFFEF4444),
    Color(0xFFB91C1C),
    Color(0xFFEF4444),
  ),
  _StreakPalette(
    Color(0xFFFB923C),
    Color(0xFFF97316),
    Color(0xFFC2410C),
    Color(0xFFF97316),
  ),
  _StreakPalette(
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
    Color(0xFFB45309),
    Color(0xFFF59E0B),
  ),
  _StreakPalette(
    Color(0xFFFACC15),
    Color(0xFFEAB308),
    Color(0xFFA16207),
    Color(0xFFEAB308),
  ),
  _StreakPalette(
    Color(0xFFA3E635),
    Color(0xFF84CC16),
    Color(0xFF4D7C0F),
    Color(0xFF84CC16),
  ),
  _StreakPalette(
    Color(0xFF4ADE80),
    Color(0xFF22C55E),
    Color(0xFF15803D),
    Color(0xFF22C55E),
  ),
  _StreakPalette(
    Color(0xFF34D399),
    Color(0xFF10B981),
    Color(0xFF047857),
    Color(0xFF10B981),
  ),
  _StreakPalette(
    Color(0xFF2DD4BF),
    Color(0xFF14B8A6),
    Color(0xFF0F766E),
    Color(0xFF14B8A6),
  ),
  _StreakPalette(
    Color(0xFF22D3EE),
    Color(0xFF06B6D4),
    Color(0xFF0E7490),
    Color(0xFF06B6D4),
  ),
  _StreakPalette(
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
    Color(0xFF0369A1),
    Color(0xFF0EA5E9),
  ),
  _StreakPalette(
    Color(0xFF7DD3FC),
    Color(0xFF38BDF8),
    Color(0xFF0284C7),
    Color(0xFF38BDF8),
  ),
  _StreakPalette(
    Color(0xFF93C5FD),
    Color(0xFF60A5FA),
    Color(0xFF2563EB),
    Color(0xFF60A5FA),
  ),
  _StreakPalette(
    Color(0xFF6EE7B7),
    Color(0xFF34D399),
    Color(0xFF059669),
    Color(0xFF34D399),
  ),
  _StreakPalette(
    Color(0xFFFFD700),
    Color(0xFFFFA500),
    Color(0xFFFF8C00),
    Color(0xFFFFA500),
  ),
  _StreakPalette(
    Color(0xFFFF8A65),
    Color(0xFFFF5722),
    Color(0xFFD84315),
    Color(0xFFFF5722),
  ),
  _StreakPalette(
    Color(0xFFFF6B9D),
    Color(0xFFE91E63),
    Color(0xFFAD1457),
    Color(0xFFE91E63),
  ),
  _StreakPalette(
    Color(0xFFBA68C8),
    Color(0xFF9C27B0),
    Color(0xFF6A1B9A),
    Color(0xFF9C27B0),
  ),
  _StreakPalette(
    Color(0xFF7986CB),
    Color(0xFF3F51B5),
    Color(0xFF283593),
    Color(0xFF3F51B5),
  ),
  _StreakPalette(
    Color(0xFF4FC3F7),
    Color(0xFF039BE5),
    Color(0xFF01579B),
    Color(0xFF039BE5),
  ),
  _StreakPalette(
    Color(0xFF4DD0E1),
    Color(0xFF00ACC1),
    Color(0xFF006064),
    Color(0xFF00ACC1),
  ),
  _StreakPalette(
    Color(0xFF81C784),
    Color(0xFF43A047),
    Color(0xFF1B5E20),
    Color(0xFF43A047),
  ),
  _StreakPalette(
    Color(0xFFFFB74D),
    Color(0xFFFB8C00),
    Color(0xFFE65100),
    Color(0xFFFB8C00),
  ),
  _StreakPalette(
    Color(0xFFFFEB3B),
    Color(0xFFFBC02D),
    Color(0xFFF57F17),
    Color(0xFFFBC02D),
  ),
];

_StreakPalette _paletteForStreak(int days) {
  if (days <= 0) {
    return const _StreakPalette(
      Color(0xFF94A3B8),
      Color(0xFF64748B),
      Color(0xFF334155),
      Color(0xFF64748B),
    );
  }
  // days=1 -> palette[0], wraps every 30.
  return _kStreakPalettes[(days - 1) % _kStreakPalettes.length];
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
    final palette = _paletteForStreak(widget.days);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.bgStart, palette.bgMid, palette.bgEnd],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(
                  alpha: 0.25 + _glowAnim.value * 0.02,
                ),
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

enum _StreakPopupKind { increased, broken }

class _StreakPopup extends StatefulWidget {
  const _StreakPopup({
    required this.stats,
    required this.kind,
    required this.resolveTarget,
  });

  final StreakStats stats;
  final _StreakPopupKind kind;
  final Rect? Function() resolveTarget;

  @override
  State<_StreakPopup> createState() => _StreakPopupState();
}

class _StreakPopupState extends State<_StreakPopup>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _exit;
  late final AnimationController _loop;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  final GlobalKey _cardKey = GlobalKey();
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scale = CurvedAnimation(
      parent: _entrance,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _exit.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _flyToTileAndClose() async {
    if (_dismissing) return;
    _dismissing = true;
    await _exit.forward();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForStreak(widget.stats.currentStreak);
    final isIncreased = widget.kind == _StreakPopupKind.increased;
    final days = widget.stats.currentStreak;

    final isRecord = isIncreased && widget.stats.isNewRecord && days > 1;
    final title = isIncreased
        ? (days <= 1
              ? 'Streak started!'
              : isRecord
              ? 'New personal best!'
              : '$days-day streak!')
        : 'Streak reset';
    final subtitle = isIncreased
        ? (days <= 1
              ? 'One session in. Come back tomorrow to grow it.'
              : isRecord
              ? 'You just set a new record of $days days. Keep the flame alive.'
              : 'You showed up ${days == 2 ? '2 days' : '$days days'} in a row. Best so far: ${widget.stats.highestStreak}.')
        : 'You missed a day. Start a new streak today — every day counts.';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _flyToTileAndClose();
      },
      child: Stack(
        children: [
          // Barrier tap — triggers the same fly-to-tile exit.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _flyToTileAndClose,
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_entrance, _exit]),
              builder: (context, child) {
                return _buildCard(palette, child!);
              },
              child: _buildCardContent(palette, title, subtitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_StreakPalette palette, Widget child) {
    // Entrance: fade + scale from 0.8 → 1.0.
    // Exit: scale down + translate toward streak tile + fade.
    final screen = MediaQuery.of(context).size;
    final target = widget.resolveTarget();

    // Card's current center (approx: screen center horizontally, near vertical middle).
    final cardBox = _cardKey.currentContext?.findRenderObject();
    Rect? cardRect;
    if (cardBox is RenderBox && cardBox.attached) {
      final tl = cardBox.localToGlobal(Offset.zero);
      cardRect = tl & cardBox.size;
    }

    final exitT = Curves.easeInCubic.transform(_exit.value);
    double dx = 0;
    double dy = 0;
    double exitScale = 1.0 - 0.95 * exitT;
    if (target != null && cardRect != null) {
      dx = (target.center.dx - cardRect.center.dx) * exitT;
      dy = (target.center.dy - cardRect.center.dy) * exitT;
      // Shrink card to roughly the tile's width.
      final targetScale = (target.width / cardRect.width).clamp(0.05, 1.0);
      exitScale = 1.0 + (targetScale - 1.0) * exitT;
    } else {
      // No target resolved — fall back to a plain shrink-to-nothing.
      dx = 0;
      dy = screen.height * 0.0 * exitT;
    }

    final entranceScale = Tween<double>(begin: 0.8, end: 1.0).evaluate(_scale);
    final combinedScale = entranceScale * exitScale;
    final opacity = (_fade.value * (1.0 - 0.9 * exitT)).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(scale: combinedScale, child: child),
      ),
    );
  }

  Widget _buildCardContent(
    _StreakPalette palette,
    String title,
    String subtitle,
  ) {
    final isIncreased = widget.kind == _StreakPopupKind.increased;
    final days = widget.stats.currentStreak;
    return Container(
      key: _cardKey,
      margin: const EdgeInsets.symmetric(horizontal: 28),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Gradient header burst
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _StreakBurstPainter(
                      progress: _loop.value,
                      palette: palette,
                      dimmed: !isIncreased,
                    ),
                  );
                },
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                // Animated fire
                AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) {
                    final flicker = math.sin(_loop.value * math.pi * 2) * 0.04;
                    final pulse =
                        1.0 + math.sin(_loop.value * math.pi * 2) * 0.06;
                    return Transform.rotate(
                      angle: flicker,
                      child: Transform.scale(
                        scale: isIncreased ? pulse : 0.92,
                        child: SizedBox(
                          width: 96,
                          height: 110,
                          child: CustomPaint(
                            painter: _StreakFirePainter(progress: _loop.value),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Big number
                Text(
                  '$days',
                  style: TextStyle(
                    fontSize: 68,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1.0,
                    color: palette.bgEnd,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  days == 1 ? 'day' : 'days',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (widget.stats.highestStreak > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.bgStart.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: palette.bgEnd,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Best: ${widget.stats.highestStreak}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.bgEnd,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _flyToTileAndClose,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [palette.bgMid, palette.bgEnd],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Keep going',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBurstPainter extends CustomPainter {
  _StreakBurstPainter({
    required this.progress,
    required this.palette,
    required this.dimmed,
  });

  final double progress;
  final _StreakPalette palette;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.95);

    // Soft radial glow
    final glowAlpha = dimmed ? 0.18 : 0.32;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.bgMid.withValues(alpha: glowAlpha),
          palette.bgMid.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.9));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glow);

    // Radiating rays
    const rayCount = 12;
    final rayPaint = Paint()
      ..color = palette.bgStart.withValues(alpha: dimmed ? 0.08 : 0.22)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < rayCount; i++) {
      final t = i / rayCount;
      final angle = math.pi + t * math.pi; // upper half fan
      final len = w * (0.45 + 0.1 * math.sin(progress * math.pi * 2 + i));
      final dx = math.cos(angle) * len;
      final dy = math.sin(angle) * len;
      canvas.drawLine(center, center + Offset(dx, dy), rayPaint);
    }
  }

  @override
  bool shouldRepaint(_StreakBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dimmed != dimmed ||
      oldDelegate.palette != palette;
}

class _SummaryMetricTile extends StatelessWidget {
  final _StatItemData item;

  const _SummaryMetricTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final Color trendColor;
    final Color trendBg;
    if (item.trendNeutral) {
      trendColor = AppTheme.textSecondary;
      trendBg = const Color(0xFFF1F5F9);
    } else if (item.positiveTrend) {
      trendColor = AppTheme.successText;
      trendBg = AppTheme.successBg;
    } else {
      trendColor = AppTheme.destructive;
      trendBg = const Color(0xFFFEF2F2);
    }

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
                    if (!item.trendNeutral)
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

class _DisplayValue {
  const _DisplayValue(this.value, this.unit);
  final String value;
  final String unit;
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
    this.trendNeutral = false,
  });

  final bool trendNeutral;
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
