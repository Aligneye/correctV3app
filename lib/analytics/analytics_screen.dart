import 'package:flutter/material.dart';
import 'package:correctv1/services/device_manager.dart';
import 'package:correctv1/services/session_repository.dart';
import 'package:correctv1/theme/app_theme.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

enum SessionType { posture, therapy }

class SessionData {
  final int id;
  final String? dbId;
  final SessionType type;
  final String name;
  final String time;
  final String date;
  final String duration;
  final int? alerts;
  final int? score;
  final int? pattern;
  final bool isLive;

  const SessionData({
    required this.id,
    this.dbId,
    required this.type,
    required this.name,
    required this.time,
    required this.date,
    required this.duration,
    this.alerts,
    this.score,
    this.pattern,
    this.isLive = false,
  });
}

const List<String> _kDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<int> _kHeatmap = [
  0,
  1,
  2,
  3,
  4,
  2,
  1,
  2,
  3,
  4,
  3,
  2,
  1,
  0,
  1,
  2,
  3,
  4,
  3,
  2,
  1,
  2,
  3,
  2,
  3,
  4,
  3,
  2,
];

// ─── Palette ─────────────────────────────────────────────────────────────────

const _kBlue = AppTheme.brandPrimary; // #2563EB
const _kBlueLight = Color(0xFFEFF6FF);
const _kBluePale = Color(0xFFBFDBFE);
const _kGreen = AppTheme.successText; // #16A34A
const _kGreenLight = AppTheme.successBg; // #F0FDF4
const _kRed = AppTheme.destructive; // #EF4444
const _kRedLight = Color(0xFFFCA5A5);
const _kBg = Color(0xFFF7F8FC);
const _kCard = Colors.white;
const _kBorder = Color(0xFFEEEEF0);
const _kText = Color(0xFF1A1A2E);
const _kTextMuted = Color(0xFF9A9AAA);
const _kTextHint = Color(0xFFBBBBCC);

const _kCardShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1)),
];

const _kAngleChartPurple = Color(0xFF8A56FF);
const _kAngleInsightBg = Color(0xFFF8F5FF);
const _kAngleInsightText = Color(0xFF4A5568);

BoxDecoration _cardDecoration({double radius = 16}) => BoxDecoration(
  color: _kCard,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _kBorder, width: 0.5),
  boxShadow: _kCardShadow,
);

// ─── Analytics Screen ────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _period = 0;

  static const _periodLabels = ['Weekly', 'Monthly'];
  static const _periodKeys = ['week', 'month'];

  final SessionRepository _repo = SessionRepository();
  final DeviceManager _deviceManager = DeviceManager();

  List<SessionData>? _sessions;
  Map<String, dynamic>? _weeklyStats;
  List<double>? _dailyScores;
  bool _isLoadingSessions = true;
  bool _isLoadingStats = true;
  bool _isLoadingDaily = true;
  int _lastSyncTick = 0;

  @override
  void initState() {
    super.initState();
    _lastSyncTick = _deviceManager.syncCompletedTick.value;
    _deviceManager.syncCompletedTick.addListener(_onSyncFinished);
    _deviceManager.isSyncing.addListener(_onSyncingChanged);
    _deviceManager.activeSessionId.addListener(_onSyncFinished);
    _reloadAll();
  }

  @override
  void dispose() {
    _deviceManager.syncCompletedTick.removeListener(_onSyncFinished);
    _deviceManager.isSyncing.removeListener(_onSyncingChanged);
    _deviceManager.activeSessionId.removeListener(_onSyncFinished);
    super.dispose();
  }

  void _onSyncFinished() {
    final tick = _deviceManager.syncCompletedTick.value;
    if (tick == _lastSyncTick) return;
    _lastSyncTick = tick;
    // Supabase row inserts may settle a moment after the ACK, so nudge the
    // reload slightly to avoid an empty-looking fetch right on the heels
    // of the final insert.
    Future<void>.delayed(const Duration(milliseconds: 400), _reloadAll);
  }

  void _onSyncingChanged() {
    if (!mounted) return;
    setState(() {}); // redraw the "Syncing..." banner
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadSessions(), _loadStats(), _loadDailyScores()]);
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() => _isLoadingSessions = true);
    try {
      final rows = await _repo.fetchByPeriod(
        _periodKeys[_period],
        liveSessionId: _deviceManager.activeSessionId.value,
      );
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _isLoadingSessions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessions = <SessionData>[];
        _isLoadingSessions = false;
      });
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _repo.fetchWeeklyStats();
      if (!mounted) return;
      setState(() {
        _weeklyStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weeklyStats = null;
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadDailyScores() async {
    if (!mounted) return;
    setState(() => _isLoadingDaily = true);
    try {
      final scores = await _repo.fetchDailyScores(7);
      if (!mounted) return;
      setState(() {
        _dailyScores = scores;
        _isLoadingDaily = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dailyScores = null;
        _isLoadingDaily = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions ?? const <SessionData>[];
    final isSyncing = _deviceManager.isSyncing.value;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSyncing) _buildSyncingBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildSummaryGrid(),
                    const SizedBox(height: 22),
                    _buildPeriodSelector(),
                    const SizedBox(height: 20),
                    _DailyScoreTrendCard(
                      goodData: _dailyScores,
                      loading: _isLoadingDaily,
                    ),
                    const SizedBox(height: 20),
                    const _AngleDeviationDayCard(),
                    _sectionLabel('Weekly streak'),
                    _buildWeeklyStreak(),
                    _sectionLabel('4-week habit'),
                    const _HeatmapCard(),
                    _sectionLabel('Recent sessions'),
                    if (_isLoadingSessions)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(_kBlue),
                          ),
                        ),
                      )
                    else if (sessions.isEmpty)
                      _buildEmptyState()
                    else
                      ...sessions.map(
                        (s) => _SessionItem(
                          session: s,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(session: s),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncingBanner() {
    return Container(
      width: double.infinity,
      color: _kBlueLight,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: const [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(_kBlue),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Syncing…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _kBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      margin: const EdgeInsets.only(top: 4),
      decoration: _cardDecoration(radius: 14),
      child: Column(
        children: const [
          Icon(Icons.insights_rounded, size: 42, color: _kTextHint),
          SizedBox(height: 12),
          Text(
            'No sessions yet.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Wear your Aligneye and start tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kTextMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final stats = _weeklyStats;
    final score = _scoreText(stats);
    final delta = _deltaText(stats);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 24,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          const Text(
            'Analytics & Insights',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w400,
              color: _kBlue,
              letterSpacing: -0.7,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Track your posture progress',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF667085),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(21, 24, 21, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2F7BFF), Color(0xFF08B4CB)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A0EA5E9),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today’s Posture Score',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        score,
                        style: const TextStyle(
                          fontSize: 42,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                          height: 0.95,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            delta,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    size: 31,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary grid ────────────────────────────────────────────────────────────

  Widget _buildSummaryGrid() {
    final stats = _weeklyStats;
    final trackedHours = _hoursValue(stats?['trackedHours'], fallback: 8.0);
    final scorePct = _scoreNumber(stats, fallback: 85);
    final goodHours = trackedHours * (scorePct / 100);
    final poorHours = (trackedHours - goodHours)
        .clamp(0, double.infinity)
        .toDouble();

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: _formatHours(goodHours),
            label: 'Good Posture',
            icon: Icons.trending_up_rounded,
            iconColor: _kGreen,
            iconBg: const Color(0xFFD8F8E3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            value: _formatHours(poorHours),
            label: 'Poor Posture',
            icon: Icons.access_time_rounded,
            iconColor: _kRed,
            iconBg: const Color(0xFFFFD9DC),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: List.generate(_periodLabels.length, (i) {
        final active = _period == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 0 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                if (_period == i) return;
                setState(() => _period = i);
                _loadSessions();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: 37,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF2F7BFF) : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: active ? const Color(0xFF2F7BFF) : _kBorder,
                    width: 1,
                  ),
                  boxShadow: active
                      ? const [
                          BoxShadow(
                            color: Color(0x262F7BFF),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _periodLabels[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: active ? Colors.white : const Color(0xFF344054),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWeeklyStreak() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_kDays.length, (i) {
              final isComplete = i < 6;
              return _StreakDayBadge(day: _kDays[i], isComplete: isComplete);
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _kDays
                .map(
                  (day) => SizedBox(
                    width: 32,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9AA0AA),
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            '7 consecutive days — keep it up!',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9AA0AA),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _scoreText(Map<String, dynamic>? stats) {
    if (_isLoadingStats || stats == null) return '87';
    return _scoreNumber(stats, fallback: 87).round().toString();
  }

  double _scoreNumber(Map<String, dynamic>? stats, {required double fallback}) {
    if (_isLoadingStats || stats == null) return fallback;
    final value = stats['goodPosturePct'];
    if (value is num) return value.toDouble().clamp(0, 100).toDouble();
    return (double.tryParse(value?.toString() ?? '') ?? fallback)
        .clamp(0, 100)
        .toDouble();
  }

  String _deltaText(Map<String, dynamic>? stats) {
    if (_isLoadingStats || stats == null) return '+5% from yesterday';
    final deltas = (stats['deltaVsLastWeek'] as Map?) ?? const {};
    final raw = deltas['goodPosturePct'];
    final delta = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    if (delta == 0) return 'No change from yesterday';
    final sign = delta > 0 ? '+' : '-';
    return '$sign${delta.abs().round()}% from yesterday';
  }

  double _hoursValue(Object? value, {required double fallback}) {
    if (_isLoadingStats || value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll('h', '')) ?? fallback;
  }

  String _formatHours(double value) => '${value.toStringAsFixed(1)}h';

  // ── Section label ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10, left: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _kTextHint,
        letterSpacing: 1.0,
      ),
    ),
  );
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color iconColor, iconBg;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 136,
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w400,
                color: Color(0xFF344054),
                height: 1.05,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w400,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StreakDayBadge extends StatelessWidget {
  final String day;
  final bool isComplete;

  const _StreakDayBadge({required this.day, required this.isComplete});

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isComplete ? const Color(0xFF5046C7) : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF5046C7), width: 1.1),
    ),
    child: isComplete
        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
        : Text(
            day,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5046C7),
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
  );
}

// ─── Daily Score Trend Card ───────────────────────────────────────────────────

class _DailyScoreTrendCard extends StatelessWidget {
  const _DailyScoreTrendCard({this.goodData, this.loading = false});

  /// Seven values (Mon..Sun) of good-posture %, 0..100.
  final List<double>? goodData;
  final bool loading;

  static const _fallback = [88.0, 94.0, 96.0, 74.0, 98.0, 92.0, 72.0];

  List<double> get _values {
    if (loading) return _fallback;
    final values = List<double>.filled(7, 0);
    if (goodData != null) {
      for (var i = 0; i < 7 && i < goodData!.length; i++) {
        values[i] = goodData![i].clamp(0, 100).toDouble();
      }
    }
    return values.any((v) => v > 0) ? values : _fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Score Trend',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 154,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 30,
                  height: 126,
                  child: _ScoreAxisLabels(),
                ),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 126,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _ScoreTrendPainter(_values),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _ScoreDayLabel('Mon'),
                          _ScoreDayLabel('Tue'),
                          _ScoreDayLabel('Wed'),
                          _ScoreDayLabel('Thu'),
                          _ScoreDayLabel('Fri'),
                          _ScoreDayLabel('Sat'),
                          _ScoreDayLabel('Sun'),
                        ],
                      ),
                    ],
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

// ─── Angle deviation throughout day (demo series) ────────────────────────────

class _AngleDeviationDayCard extends StatelessWidget {
  const _AngleDeviationDayCard();

  /// Demo curve: 8am → 8pm (6pm point has no x-label in the reference UI).
  static const _values = [75.0, 82.0, 78.0, 85.0, 93.0, 88.0, 80.0];
  static const _xLabels = ['8am', '10am', '12pm', '2pm', '4pm', '', '8pm'];
  static const _plotHeight = 132.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Angle Deviation Throughout Day',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                height: _plotHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      right: 4,
                      child: _angleYLabel('100'),
                    ),
                    Positioned(
                      top: _plotHeight * 0.5 - 7,
                      right: 4,
                      child: _angleYLabel('80'),
                    ),
                    Positioned(
                      top: _plotHeight * 0.75 - 7,
                      right: 4,
                      child: _angleYLabel('70'),
                    ),
                    Positioned(
                      top: _plotHeight - 14,
                      right: 4,
                      child: _angleYLabel('60'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: _plotHeight,
                      child: CustomPaint(
                        painter: _AngleDeviationDayPainter(
                          values: _values,
                          lineColor: _kAngleChartPurple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 0; i < _xLabels.length; i++)
                          Expanded(
                            child: Text(
                              _xLabels[i],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: _xLabels[i].isEmpty
                                    ? Colors.transparent
                                    : const Color(0xFF98A2B3),
                                height: 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: _kAngleInsightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  size: 22,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your posture tends to worsen in the afternoon. Consider '
                    'setting more frequent reminders during 2-6 PM.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kAngleInsightText,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _angleYLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      color: Color(0xFF98A2B3),
      height: 1,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _AngleDeviationDayPainter extends CustomPainter {
  _AngleDeviationDayPainter({
    required this.values,
    required this.lineColor,
  });

  final List<double> values;
  final Color lineColor;

  static const _yMin = 60.0;
  static const _yMax = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final gridPaint = Paint()
      ..color = const Color(0xFFE3EAF3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final v in [60.0, 70.0, 80.0, 100.0]) {
      final y = _yForValue(v, h);
      _angleDashLine(canvas, Offset(0, y), Offset(w, y), gridPaint);
    }

    for (var i = 0; i < values.length; i++) {
      final x = w * (i / (values.length - 1));
      _angleDashLine(canvas, Offset(x, 0), Offset(x, h), gridPaint);
    }

    final pts = List<Offset>.generate(values.length, (i) {
      final x = w * (i / (values.length - 1));
      final clamped = values[i].clamp(_yMin, _yMax);
      final y = _yForValue(clamped.toDouble(), h);
      return Offset(x, y);
    });

    final linePath = _smoothPath(pts);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    final fill = Paint()..color = lineColor;
    final ring = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final p in pts) {
      canvas.drawCircle(p, 5, fill);
      canvas.drawCircle(p, 5, ring);
    }
  }

  double _yForValue(double v, double h) {
    final t = (v - _yMin) / (_yMax - _yMin);
    return h * (1 - t);
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midX = (current.dx + next.dx) / 2;
      path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  void _angleDashLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 3.0;
    const gap = 3.0;
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final dir = d / len;
    var t = 0.0;
    while (t < len) {
      final end = (t + dash).clamp(0, len).toDouble();
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _AngleDeviationDayPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

class _ScoreAxisLabels extends StatelessWidget {
  const _ScoreAxisLabels();

  @override
  Widget build(BuildContext context) => const Stack(
    children: [
      Positioned(top: 0, right: 6, child: _AxisLabel('100')),
      Positioned(top: 56, right: 6, child: _AxisLabel('50')),
      Positioned(top: 86, right: 6, child: _AxisLabel('25')),
      Positioned(bottom: 0, right: 6, child: _AxisLabel('0')),
    ],
  );
}

class _AxisLabel extends StatelessWidget {
  final String label;

  const _AxisLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3), height: 1),
  );
}

class _ScoreDayLabel extends StatelessWidget {
  final String label;

  const _ScoreDayLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 14, color: Color(0xFF98A2B3), height: 1),
  );
}

class _ScoreTrendPainter extends CustomPainter {
  final List<double> values;

  const _ScoreTrendPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE3EAF3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final areaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x553B82F6), Color(0x103B82F6)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final pct in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = size.height * pct;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < 7; i++) {
      final x = size.width * (i / 6);
      _drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final points = List<Offset>.generate(values.length, (i) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height * (1 - values[i].clamp(0, 100) / 100);
      return Offset(x, y);
    });
    final linePath = _smoothPath(points);
    final areaPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(linePath, linePaint);
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midX = (current.dx + next.dx) / 2;
      path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 3.0;
    const gap = 3.0;
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    var current = 0.0;
    while (current < distance) {
      final next = (current + dash).clamp(0, distance).toDouble();
      canvas.drawLine(
        start + direction * current,
        start + direction * next,
        paint,
      );
      current += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

// ─── Heatmap Card ─────────────────────────────────────────────────────────────

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard();

  static const _heatColors = [
    Color(0xFFF3F4F6), // 0 – none
    Color(0xFFBFDBFE), // 1 – low
    Color(0xFF60A5FA), // 2 – medium
    Color(0xFF2563EB), // 3 – high
    Color(0xFF1D4ED8), // 4 – max
  ];

  Color _cell(int v) => _heatColors[v.clamp(0, 4)];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    margin: const EdgeInsets.only(bottom: 2),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        // Day-of-week header
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kTextHint,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        // Grid — aspect ratio 1 keeps cells square
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: _kHeatmap.length,
          itemBuilder: (_, i) => Container(
            decoration: BoxDecoration(
              color: _cell(_kHeatmap[i]),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'less',
              style: TextStyle(fontSize: 10, color: _kTextHint),
            ),
            const SizedBox(width: 5),
            ...[
              Color(0xFFF3F4F6),
              Color(0xFFBFDBFE),
              Color(0xFF2563EB),
              Color(0xFF1D4ED8),
            ].map(
              (c) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                    border: c == const Color(0xFFF3F4F6)
                        ? Border.all(color: _kBorder, width: 0.5)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'more',
              style: TextStyle(fontSize: 10, color: _kTextHint),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─── Session Item ─────────────────────────────────────────────────────────────

class _SessionItem extends StatelessWidget {
  final SessionData session;
  final VoidCallback onTap;
  const _SessionItem({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPosture = session.type == SessionType.posture;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
        decoration: _cardDecoration(radius: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isPosture ? _kBlueLight : _kGreenLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isPosture
                    ? Icons.accessibility_new_rounded
                    : Icons.vibration_rounded,
                color: isPosture ? _kBlue : _kGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time row
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
                        const _LiveTag(),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        session.time,
                        style: const TextStyle(fontSize: 10, color: _kTextHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Mini stats row
                  Row(
                    children: [
                      _MiniStat(value: session.duration, label: 'Duration'),
                      if (session.score != null) ...[
                        const SizedBox(width: 14),
                        _MiniStat(
                          value: '${session.score}%',
                          label: 'Good posture',
                        ),
                      ],
                      if (session.alerts != null) ...[
                        const SizedBox(width: 14),
                        _MiniStat(value: '${session.alerts}×', label: 'Alerts'),
                      ],
                      if (session.pattern != null) ...[
                        const SizedBox(width: 14),
                        _MiniStat(
                          value: '#${session.pattern}',
                          label: 'Pattern',
                        ),
                      ],
                    ],
                  ),

                  // Progress bar (posture only)
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

class _LiveTag extends StatelessWidget {
  const _LiveTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _kRed.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _kRed.withValues(alpha: 0.18)),
    ),
    child: const Text(
      'Live',
      style: TextStyle(color: _kRed, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kText,
          height: 1.2,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: _kTextHint, height: 1.3),
      ),
    ],
  );
}

// ─── Session Detail Screen ────────────────────────────────────────────────────

class SessionDetailScreen extends StatelessWidget {
  final SessionData session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final isPosture = session.type == SessionType.posture;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chevron_left_rounded, color: _kBlue, size: 28),
            ],
          ),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 14,
            color: _kBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: isPosture ? _kBlue : _kGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    isPosture ? '${session.score}%' : '#${session.pattern}',
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPosture ? 'Good posture score' : 'Vibration pattern',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            _label('Session details'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                _DetailStat(value: session.duration, label: 'Duration'),
                _DetailStat(value: session.date, label: 'Date'),
                if (isPosture) ...[
                  _DetailStat(
                    value: '${session.alerts}×',
                    label: 'Vibration alerts',
                  ),
                  _DetailStat(
                    value: '${100 - session.score!}%',
                    label: 'Needs work',
                  ),
                ] else ...[
                  const _DetailStat(value: 'Full', label: 'Completion'),
                  const _DetailStat(value: '20 min', label: 'Pattern time'),
                ],
              ],
            ),
            const SizedBox(height: 4),

            if (isPosture) ...[
              _label('Session timeline'),
              _timelineCard(),
              _label('vs your average'),
              _compareCard(session.score!),
            ] else ...[
              _label('Pattern info'),
              _patternInfoCard(session.pattern!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10, left: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _kTextHint,
        letterSpacing: 1.0,
      ),
    ),
  );

  Widget _timelineCard() => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        _TlItem(
          color: _kBlue,
          title: 'Session started',
          sub: '0:00 — device connected',
          isLast: false,
        ),
        _TlItem(
          color: _kRedLight,
          title: 'Alert — slouch detected',
          sub: '4:12 — vibration fired',
          isLast: false,
        ),
        _TlItem(
          color: _kGreen,
          title: 'Posture corrected',
          sub: '4:25 — good posture resumed',
          isLast: false,
        ),
        _TlItem(
          color: _kRedLight,
          title: 'Alert — forward lean',
          sub: '11:40 — vibration fired',
          isLast: false,
        ),
        _TlItem(
          color: _kBlue,
          title: 'Session ended',
          sub: '${session.duration} total',
          isLast: true,
        ),
      ],
    ),
  );

  Widget _compareCard(int score) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        _CompareRow(
          label: 'This session',
          value: '$score%',
          fill: score / 100,
          color: _kBlue,
        ),
        const SizedBox(height: 12),
        _CompareRow(
          label: 'Your average',
          value: '80%',
          fill: 0.80,
          color: _kBluePale,
        ),
      ],
    ),
  );

  Widget _patternInfoCard(int pattern) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        _InfoRow(label: 'Pattern #', value: '$pattern'),
        _InfoRow(label: 'Duration', value: session.duration),
        _InfoRow(label: 'Intensity', value: 'Medium'),
        _InfoRow(label: 'Status', value: 'Completed', valueColor: _kGreen),
      ],
    ),
  );
}

// ─── Detail Stat ──────────────────────────────────────────────────────────────

class _DetailStat extends StatelessWidget {
  final String value, label;
  const _DetailStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: _cardDecoration(radius: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: _kTextHint)),
      ],
    ),
  );
}

// ─── Timeline Item ────────────────────────────────────────────────────────────

class _TlItem extends StatelessWidget {
  final Color color;
  final String title, sub;
  final bool isLast;
  const _TlItem({
    required this.color,
    required this.title,
    required this.sub,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Dot + line
      SizedBox(
        width: 18,
        child: Column(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(width: 1.5, height: 32, color: const Color(0xFFE8E8F0)),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(fontSize: 11, color: _kTextHint),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ─── Compare Row ─────────────────────────────────────────────────────────────

class _CompareRow extends StatelessWidget {
  final String label, value;
  final double fill;
  final Color color;
  const _CompareRow({
    required this.label,
    required this.value,
    required this.fill,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: _kTextMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: fill,
          backgroundColor: const Color(0xFFF3F4F6),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 7,
        ),
      ),
    ],
  );
}

// ─── Info Row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = _kText,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _kTextMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}
