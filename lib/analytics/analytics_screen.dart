import 'package:flutter/material.dart';
import 'package:correctv1/services/device_manager.dart';
import 'package:correctv1/services/session_repository.dart';
import 'package:correctv1/theme/app_theme.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

enum SessionType { posture, therapy }

class SessionData {
  final int id;
  final SessionType type;
  final String name;
  final String time;
  final String date;
  final String duration;
  final int? alerts;
  final int? score;
  final int? pattern;

  const SessionData({
    required this.id,
    required this.type,
    required this.name,
    required this.time,
    required this.date,
    required this.duration,
    this.alerts,
    this.score,
    this.pattern,
  });
}

const List<String> _kDays     = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<int>    _kHeatmap  = [0,1,2,3,4,2,1, 2,3,4,3,2,1,0, 1,2,3,4,3,2,1, 2,3,2,3,4,3,2];

// ─── Palette ─────────────────────────────────────────────────────────────────

const _kBlue      = AppTheme.brandPrimary;           // #2563EB
const _kBlueLight = Color(0xFFEFF6FF);
const _kBluePale  = Color(0xFFBFDBFE);
const _kGreen     = AppTheme.successText;             // #16A34A
const _kGreenLight = AppTheme.successBg;              // #F0FDF4
const _kRed       = AppTheme.destructive;             // #EF4444
const _kRedLight  = Color(0xFFFCA5A5);
const _kBg        = Color(0xFFF7F8FC);
const _kCard      = Colors.white;
const _kBorder    = Color(0xFFEEEEF0);
const _kText      = Color(0xFF1A1A2E);
const _kTextMuted = Color(0xFF9A9AAA);
const _kTextHint  = Color(0xFFBBBBCC);

const _kCardShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 8,  offset: Offset(0, 2)),
  BoxShadow(color: Color(0x05000000), blurRadius: 2,  offset: Offset(0, 1)),
];

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

  static const _periodLabels = ['This week', 'Month', 'All time'];
  static const _periodKeys   = ['week', 'month', 'all'];

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
    _reloadAll();
  }

  @override
  void dispose() {
    _deviceManager.syncCompletedTick.removeListener(_onSyncFinished);
    _deviceManager.isSyncing.removeListener(_onSyncingChanged);
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
    await Future.wait([
      _loadSessions(),
      _loadStats(),
      _loadDailyScores(),
    ]);
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() => _isLoadingSessions = true);
    try {
      final rows = await _repo.fetchByPeriod(_periodKeys[_period]);
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
            _buildHeader(),
            const Divider(height: 1, thickness: 0.5, color: _kBorder),
            if (isSyncing) _buildSyncingBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Summary'),
                    _buildSummaryGrid(),
                    _sectionLabel('Daily posture'),
                    _BarChartCard(
                      goodData: _dailyScores,
                      loading: _isLoadingDaily,
                    ),
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
              fontSize: 12, fontWeight: FontWeight.w500, color: _kBlue,
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
              fontSize: 14, fontWeight: FontWeight.w600, color: _kText,
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
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: _kText, letterSpacing: -0.4, height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Your posture progress',
            style: TextStyle(fontSize: 13, color: _kTextMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Period selector
          Row(
            children: List.generate(_periodLabels.length, (i) {
              final active = _period == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    if (_period == i) return;
                    setState(() => _period = i);
                    _loadSessions();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? _kBlue : _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? _kBlue : _kBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _periodLabels[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: active ? Colors.white : _kTextMuted,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Summary grid ────────────────────────────────────────────────────────────

  Widget _buildSummaryGrid() {
    // While stats are loading we keep the same grid footprint so the layout
    // doesn't jump; show a dash for values and muted deltas.
    final stats = _weeklyStats;
    final deltas = (stats?['deltaVsLastWeek'] as Map?) ?? const {};

    String valueOr(String key, String fallback) {
      if (_isLoadingStats || stats == null) return fallback;
      final v = stats[key];
      if (v == null) return fallback;
      return v.toString();
    }

    String deltaText(String key, String unit) {
      if (_isLoadingStats || stats == null) return '—';
      final d = deltas[key];
      if (d == null) return '—';
      final num n = d is num ? d : num.tryParse(d.toString()) ?? 0;
      if (n == 0) return 'No change';
      final absVal = n.abs();
      final absStr = absVal is int
          ? absVal.toString()
          : absVal.toStringAsFixed(1);
      final arrow = n > 0 ? 'more' : 'less';
      return '$absStr$unit $arrow';
    }

    bool deltaUp(String key) {
      if (_isLoadingStats || stats == null) return true;
      final d = deltas[key];
      if (d == null) return true;
      final num n = d is num ? d : num.tryParse(d.toString()) ?? 0;
      return n >= 0;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          value: valueOr('goodPosturePct', '—'),
          unit: '%',
          label: 'Good posture',
          deltaText: deltaText('goodPosturePct', '%'),
          deltaUp: deltaUp('goodPosturePct'),
        ),
        _StatCard(
          value: valueOr('trackedHours', '—'),
          unit: 'h',
          label: 'Tracked time',
          deltaText: deltaText('trackedHours', 'h'),
          deltaUp: deltaUp('trackedHours'),
        ),
        _StatCard(
          value: valueOr('sessionCount', '—'),
          unit: '',
          label: 'Sessions done',
          deltaText: deltaText('sessionCount', ''),
          deltaUp: deltaUp('sessionCount'),
        ),
        _StatCard(
          value: valueOr('therapyMinutes', '—'),
          unit: 'm',
          label: 'Therapy time',
          deltaText: deltaText('therapyMinutes', 'min'),
          deltaUp: deltaUp('therapyMinutes'),
        ),
      ],
    );
  }

  // ── Section label ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10, left: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: _kTextHint, letterSpacing: 1.0,
      ),
    ),
  );
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, unit, label, deltaText;
  final bool deltaUp;

  const _StatCard({
    required this.value, required this.unit,
    required this.label, required this.deltaText,
    required this.deltaUp,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Value + unit
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _kText, height: 1),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(unit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kTextHint),
              ),
            ],
          ],
        ),
        // Label
        Text(label,
          style: const TextStyle(fontSize: 11.5, color: _kTextMuted, fontWeight: FontWeight.w500),
        ),
        // Delta
        Row(
          children: [
            Icon(
              deltaUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: deltaUp ? _kGreen : _kRed,
            ),
            const SizedBox(width: 3),
            Text(deltaText,
              style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w500,
                color: deltaUp ? _kGreen : _kRed,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─── Bar Chart Card ───────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({this.goodData, this.loading = false});

  /// Seven values (Mon..Sun) of good-posture %, 0..100. Missing days are 0.
  final List<double>? goodData;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // Normalize incoming data to exactly 7 samples so the row layout never
    // has to handle ragged inputs.
    final good = List<double>.filled(7, 0);
    if (goodData != null) {
      for (var i = 0; i < 7 && i < goodData!.length; i++) {
        good[i] = goodData![i].clamp(0, 100).toDouble();
      }
    }
    final bad = List<double>.generate(7, (i) => 100 - good[i]);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Good vs needs work',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
              Text('Mon–Sun',
                style: TextStyle(fontSize: 11, color: _kTextHint)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_kBlue),
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      const maxH = 80.0;
                      final gH = (good[i] / 100) * maxH;
                      final bH = (bad[i] / 100) * maxH;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: gH,
                                decoration: const BoxDecoration(
                                  color: _kBlue,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              Container(height: 1, color: _kBg),
                              Container(
                                height: bH,
                                decoration: const BoxDecoration(
                                  color: _kRedLight,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(_kDays[i],
                                style: const TextStyle(
                                  fontSize: 10, color: _kTextHint,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _LegendDot(color: _kBlue,    label: 'Good'),
              SizedBox(width: 14),
              _LegendDot(color: _kRedLight, label: 'Needs work'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _kTextMuted)),
    ],
  );
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
          children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
            child: Center(
              child: Text(d,
                style: const TextStyle(
                  fontSize: 10, color: _kTextHint,
                  fontWeight: FontWeight.w600, letterSpacing: 0.2,
                ),
              ),
            ),
          )).toList(),
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
            const Text('less', style: TextStyle(fontSize: 10, color: _kTextHint)),
            const SizedBox(width: 5),
            ...[
              Color(0xFFF3F4F6),
              Color(0xFFBFDBFE),
              Color(0xFF2563EB),
              Color(0xFF1D4ED8),
            ].map((c) => Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                  border: c == const Color(0xFFF3F4F6)
                    ? Border.all(color: _kBorder, width: 0.5)
                    : null,
                ),
              ),
            )),
            const SizedBox(width: 5),
            const Text('more', style: TextStyle(fontSize: 10, color: _kTextHint)),
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
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isPosture ? _kBlueLight : _kGreenLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isPosture ? Icons.accessibility_new_rounded : Icons.vibration_rounded,
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
                            fontSize: 13.5, fontWeight: FontWeight.w600, color: _kText,
                          ),
                          overflow: TextOverflow.ellipsis,
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

                  // Mini stats row
                  Row(
                    children: [
                      _MiniStat(value: session.duration, label: 'Duration'),
                      if (session.score != null) ...[
                        const SizedBox(width: 14),
                        _MiniStat(value: '${session.score}%', label: 'Good posture'),
                      ],
                      if (session.alerts != null) ...[
                        const SizedBox(width: 14),
                        _MiniStat(value: '${session.alerts}×', label: 'Alerts'),
                      ],
                      if (session.pattern != null) ...[
                        const SizedBox(width: 14),
                        _MiniStat(value: '#${session.pattern}', label: 'Pattern'),
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
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCDD), size: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText, height: 1.2),
      ),
      Text(label,
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
          style: TextStyle(fontSize: 14, color: _kBlue, fontWeight: FontWeight.w500),
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
                      fontSize: 60, fontWeight: FontWeight.w700,
                      color: Colors.white, height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPosture ? 'Good posture score' : 'Vibration pattern',
                    style: TextStyle(
                      fontSize: 13.5, color: Colors.white.withValues(alpha: 0.8),
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
                _DetailStat(value: session.date,     label: 'Date'),
                if (isPosture) ...[
                  _DetailStat(value: '${session.alerts}×',         label: 'Vibration alerts'),
                  _DetailStat(value: '${100 - session.score!}%',    label: 'Needs work'),
                ] else ...[
                  const _DetailStat(value: 'Full',   label: 'Completion'),
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
        fontSize: 11, fontWeight: FontWeight.w600,
        color: _kTextHint, letterSpacing: 1.0,
      ),
    ),
  );

  Widget _timelineCard() => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        _TlItem(color: _kBlue,     title: 'Session started',        sub: '0:00 — device connected',     isLast: false),
        _TlItem(color: _kRedLight, title: 'Alert — slouch detected', sub: '4:12 — vibration fired',      isLast: false),
        _TlItem(color: _kGreen,    title: 'Posture corrected',       sub: '4:25 — good posture resumed',  isLast: false),
        _TlItem(color: _kRedLight, title: 'Alert — forward lean',    sub: '11:40 — vibration fired',     isLast: false),
        _TlItem(color: _kBlue,     title: 'Session ended',           sub: '${session.duration} total',   isLast: true),
      ],
    ),
  );

  Widget _compareCard(int score) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        _CompareRow(label: 'This session', value: '$score%', fill: score / 100, color: _kBlue),
        const SizedBox(height: 12),
        _CompareRow(label: 'Your average', value: '80%',     fill: 0.80,        color: _kBluePale),
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
        _InfoRow(label: 'Duration',  value: session.duration),
        _InfoRow(label: 'Intensity', value: 'Medium'),
        _InfoRow(label: 'Status',    value: 'Completed', valueColor: _kGreen),
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
        Text(value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kText, height: 1.2),
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
    required this.color, required this.title,
    required this.sub, required this.isLast,
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
              width: 10, height: 10,
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
              Text(title,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kText),
              ),
              const SizedBox(height: 2),
              Text(sub,
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
    required this.label, required this.value,
    required this.fill, required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: _kTextMuted)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kText)),
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
  const _InfoRow({required this.label, required this.value, this.valueColor = _kText});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _kTextMuted)),
        Text(value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    ),
  );
}
