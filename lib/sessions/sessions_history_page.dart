import 'package:flutter/material.dart';

import 'package:correctv1/analytics/analytics_screen.dart';
import 'package:correctv1/services/device_manager.dart';
import 'package:correctv1/services/session_repository.dart';
import 'package:correctv1/theme/app_theme.dart';

const _kBg = Color(0xFFF7F8FC);
const _kCard = Colors.white;
const _kBorder = Color(0xFFEEEEF0);
const _kText = Color(0xFF1A1A2E);
const _kTextMuted = Color(0xFF6B7280);
const _kTextHint = Color(0xFFBBBBCC);
const _kBlue = AppTheme.brandPrimary;
const _kBlueLight = Color(0xFFEFF6FF);
const _kGreen = AppTheme.successText;
const _kGreenLight = AppTheme.successBg;
const _kRed = AppTheme.destructive;

enum _Filter { all, posture, therapy }

class SessionsHistoryPage extends StatefulWidget {
  const SessionsHistoryPage({super.key});

  @override
  State<SessionsHistoryPage> createState() => _SessionsHistoryPageState();
}

class _SessionsHistoryPageState extends State<SessionsHistoryPage> {
  final SessionRepository _repo = SessionRepository();
  final DeviceManager _deviceManager = DeviceManager();

  List<SessionData> _sessions = const <SessionData>[];
  bool _isLoading = true;
  int _lastSyncTick = 0;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _lastSyncTick = _deviceManager.syncCompletedTick.value;
    _deviceManager.syncCompletedTick.addListener(_onSyncTick);
    _deviceManager.activeSessionId.addListener(_onActiveSessionChanged);
    _deviceManager.isSyncing.addListener(_onSyncingChanged);
    _load();
  }

  @override
  void dispose() {
    _deviceManager.syncCompletedTick.removeListener(_onSyncTick);
    _deviceManager.activeSessionId.removeListener(_onActiveSessionChanged);
    _deviceManager.isSyncing.removeListener(_onSyncingChanged);
    super.dispose();
  }

  void _onSyncTick() {
    final tick = _deviceManager.syncCompletedTick.value;
    if (tick == _lastSyncTick) return;
    _lastSyncTick = tick;
    _load();
  }

  void _onActiveSessionChanged() {
    if (!mounted) return;
    _load();
  }

  void _onSyncingChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rows = await _repo.fetchByPeriod(
        'all',
        liveSessionId: _deviceManager.activeSessionId.value,
      );
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('SessionsHistoryPage: _load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<SessionData> get _filtered {
    switch (_filter) {
      case _Filter.posture:
        return _sessions.where((s) => s.type == SessionType.posture).toList();
      case _Filter.therapy:
        return _sessions.where((s) => s.type == SessionType.therapy).toList();
      case _Filter.all:
        return _sessions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final groups = _groupByDay(filtered);
    final isSyncing = _deviceManager.isSyncing.value;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            if (isSyncing) const _SyncingPill(),
            _buildFilterRow(),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(_kBlue),
                        ),
                      )
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : _buildList(groups),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _sessions.length;
    final postureCount =
        _sessions.where((s) => s.type == SessionType.posture).length;
    final therapyCount = total - postureCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      color: _kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF4B5563),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'All sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  value: '$total',
                  label: 'Total',
                  color: _kBlue,
                ),
              ),
              Container(width: 1, height: 28, color: _kBorder),
              Expanded(
                child: _SummaryStat(
                  value: '$postureCount',
                  label: 'Posture',
                  color: _kBlue,
                ),
              ),
              Container(width: 1, height: 28, color: _kBorder),
              Expanded(
                child: _SummaryStat(
                  value: '$therapyCount',
                  label: 'Therapy',
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    Widget chip(String label, _Filter value, {IconData? icon}) {
      final selected = _filter == value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _kBlue : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _kBlue : _kBorder,
              width: 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x222F7BFF),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : _kTextMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _kTextMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chip('All', _Filter.all),
          const SizedBox(width: 8),
          chip('Posture', _Filter.posture, icon: Icons.accessibility_new_rounded),
          const SizedBox(width: 8),
          chip('Therapy', _Filter.therapy, icon: Icons.graphic_eq),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 0.5),
          ),
          child: Column(
            children: const [
              Icon(Icons.history_rounded, size: 44, color: _kTextHint),
              SizedBox(height: 12),
              Text(
                'No sessions yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Wear your Aligneye Pod and start a posture or therapy '
                'session — it’ll show up here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _kTextMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<_DayGroup> groups) {
    final children = <Widget>[];
    for (final group in groups) {
      children.add(_DayHeader(group: group));
      for (var i = 0; i < group.sessions.length; i++) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SessionTile(
              session: group.sessions[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionDetailScreen(session: group.sessions[i]),
                ),
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 8));
      }
      children.add(const SizedBox(height: 12));
    }
    children.add(const SizedBox(height: 80));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }

  List<_DayGroup> _groupByDay(List<SessionData> sessions) {
    final map = <DateTime, List<SessionData>>{};
    for (final s in sessions) {
      final ts = s.startTs;
      final key = ts == null
          ? DateTime(1970)
          : DateTime(ts.year, ts.month, ts.day);
      map.putIfAbsent(key, () => <SessionData>[]).add(s);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        _DayGroup(
          day: key,
          sessions: map[key]!,
        ),
    ];
  }
}

class _DayGroup {
  _DayGroup({required this.day, required this.sessions});
  final DateTime day;
  final List<SessionData> sessions;

  bool get isUnknownDay => day.year == 1970;

  String formatHeader() {
    if (isUnknownDay) return 'No timestamp';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdayLong(day.weekday);
    return '${_monthShort(day.month)} ${day.day}, ${day.year}';
  }

  int get totalDurationSec =>
      sessions.fold(0, (sum, s) => sum + s.durationSec);

  String formatTotalDuration() {
    final total = totalDurationSec;
    if (total <= 0) return '—';
    if (total < 60) return '${total}s';
    final m = total ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }
}

String _weekdayLong(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[(weekday - 1).clamp(0, 6)];
}

String _monthShort(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[(month - 1).clamp(0, 11)];
}

class _DayHeader extends StatelessWidget {
  final _DayGroup group;
  const _DayHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Text(
            group.formatHeader(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kText,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kBlueLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${group.sessions.length}',
              style: const TextStyle(
                fontSize: 10,
                color: _kBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            group.formatTotalDuration(),
            style: const TextStyle(
              fontSize: 11.5,
              color: _kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _kTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionData session;
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPosture = session.type == SessionType.posture;
    final accent = isPosture ? _kBlue : _kGreen;
    final accentBg = isPosture ? _kBlueLight : _kGreenLight;
    final timeStr = _formatTime(session.startTs) ?? '—';

    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder, width: 0.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isPosture
                      ? Icons.accessibility_new_rounded
                      : Icons.graphic_eq,
                  size: 22,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (session.isLive) const _LivePill(),
                        if (!session.tsSynced && !session.isLive)
                          const _UnsyncedTimePill(),
                        if (!session.cloudSynced && !session.isLive)
                          const _CloudPendingIcon(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: _kTextHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _kTextMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: _kTextHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.duration,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _kTextMuted,
                          ),
                        ),
                        if (isPosture && session.alerts != null) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 12,
                            color: _kRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.alerts}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _kTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isPosture && session.score != null) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: session.score! / 100,
                          backgroundColor: const Color(0xFFEEEEF8),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 3.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPosture
                        ? '${session.score ?? 0}%'
                        : '#${session.pattern ?? 0}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      height: 1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPosture ? 'good' : 'pattern',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _kTextHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatTime(DateTime? ts) {
    if (ts == null) return null;
    final hour = ts.hour == 0 ? 12 : (ts.hour > 12 ? ts.hour - 12 : ts.hour);
    final minute = ts.minute.toString().padLeft(2, '0');
    final ampm = ts.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kRed.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: _kRed,
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

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.55 + 0.45 * t),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _UnsyncedTimePill extends StatelessWidget {
  const _UnsyncedTimePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFE2A8)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off, size: 10, color: Color(0xFFB45309)),
          SizedBox(width: 3),
          Text(
            'time',
            style: TextStyle(
              color: Color(0xFFB45309),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudPendingIcon extends StatelessWidget {
  const _CloudPendingIcon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 6),
      child: Icon(
        Icons.cloud_off_rounded,
        size: 14,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _SyncingPill extends StatelessWidget {
  const _SyncingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kBlueLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            'Syncing offline sessions from device…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kBlue,
            ),
          ),
        ],
      ),
    );
  }
}
