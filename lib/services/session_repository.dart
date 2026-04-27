import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/analytics/analytics_screen.dart';

/// Thin read layer over the `sessions` Supabase table.
///
/// All queries are scoped to the current `auth.uid()` via RLS (see
/// `lib/supabase/schema.sql`) so we never need to pass the user id
/// explicitly.
class SessionRepository {
  SessionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Convenience: this week only (Monday 00:00 local -> now).
  Future<List<SessionData>> fetchThisWeek({String? liveSessionId}) =>
      fetchByPeriod('week', liveSessionId: liveSessionId);

  /// period ∈ {'week', 'month', 'all'}.
  /// Unknown periods fall back to 'all' so the UI never breaks on a typo.
  Future<List<SessionData>> fetchByPeriod(
    String period, {
    String? liveSessionId,
  }) async {
    final since = _periodStart(period);

    final query = _client.from('sessions').select();
    final filtered = since != null
        ? query.gte('start_ts', since.toUtc().toIso8601String())
        : query;

    final rows = await filtered.order('start_ts', ascending: false);
    return _mapRows(rows as List<dynamic>, liveSessionId: liveSessionId);
  }

  /// Summary stats for the current week.
  /// Returned map keys match what the stat-card widgets expect:
  /// `goodPosturePct`, `trackedHours`, `sessionCount`, `therapyMinutes`,
  /// `deltaVsLastWeek` (map of the same four keys with signed deltas).
  Future<Map<String, dynamic>> fetchWeeklyStats() async {
    final now = DateTime.now();
    final thisWeekStart = _startOfWeek(now);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final thisWeekRows = await _fetchRowsBetween(thisWeekStart, now);
    final lastWeekRows = await _fetchRowsBetween(lastWeekStart, thisWeekStart);

    final thisWeek = _aggregate(thisWeekRows);
    final lastWeek = _aggregate(lastWeekRows);

    // trackedHours is a formatted string for display; deltas compare the raw
    // numeric value so up/down arrows are meaningful.
    final trackedDelta =
        thisWeek.trackedHoursNumeric - lastWeek.trackedHoursNumeric;

    return {
      'goodPosturePct': thisWeek.goodPosturePct,
      'trackedHours': thisWeek.trackedHours,
      'sessionCount': thisWeek.sessionCount,
      'therapyMinutes': thisWeek.therapyMinutes,
      'deltaVsLastWeek': {
        'goodPosturePct': thisWeek.goodPosturePct - lastWeek.goodPosturePct,
        'trackedHours': double.parse(trackedDelta.toStringAsFixed(1)),
        'sessionCount': thisWeek.sessionCount - lastWeek.sessionCount,
        'therapyMinutes': thisWeek.therapyMinutes - lastWeek.therapyMinutes,
      },
    };
  }

  /// Daily good-posture % for the last [days] calendar days (oldest first).
  /// Days with no posture sessions return 0 so bar chart shows a gap.
  Future<List<double>> fetchDailyScores(int days) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final rows = await _fetchRowsBetween(start, now, typeFilter: 'posture');

    final dailyDur = List<int>.filled(days, 0);
    final dailyWrong = List<int>.filled(days, 0);

    for (final row in rows) {
      final ts = _parseTs(row['start_ts']);
      if (ts == null) continue;
      final local = ts.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final idx = day
          .difference(DateTime(start.year, start.month, start.day))
          .inDays;
      if (idx < 0 || idx >= days) continue;
      dailyDur[idx] += _asInt(row['duration_sec']);
      dailyWrong[idx] += _asInt(row['wrong_dur_sec']);
    }

    return List<double>.generate(days, (i) {
      final dur = dailyDur[i];
      if (dur <= 0) return 0;
      final pct = (100 - (dailyWrong[i] / dur * 100)).clamp(0, 100);
      return pct.toDouble();
    });
  }

  // ── internals ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchRowsBetween(
    DateTime startInclusive,
    DateTime endExclusive, {
    String? typeFilter,
  }) async {
    var q = _client
        .from('sessions')
        .select()
        .gte('start_ts', startInclusive.toUtc().toIso8601String())
        .lt('start_ts', endExclusive.toUtc().toIso8601String());

    if (typeFilter != null) {
      q = q.eq('type', typeFilter);
    }

    final rows = await q.order('start_ts', ascending: false);
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  DateTime? _periodStart(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'week':
        return _startOfWeek(now);
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'all':
      default:
        return null;
    }
  }

  DateTime _startOfWeek(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    // DateTime.weekday: Monday = 1 ... Sunday = 7.
    return today.subtract(Duration(days: today.weekday - 1));
  }

  List<SessionData> _mapRows(List<dynamic> rows, {String? liveSessionId}) {
    final out = <SessionData>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i] as Map<String, dynamic>;
      final mapped = _rowToSession(row, i, liveSessionId: liveSessionId);
      if (mapped != null) out.add(mapped);
    }
    return out;
  }

  SessionData? _rowToSession(
    Map<String, dynamic> row,
    int index, {
    String? liveSessionId,
  }) {
    final typeStr = row['type']?.toString() ?? '';
    final isPosture = typeStr == 'posture';
    final type = isPosture ? SessionType.posture : SessionType.therapy;

    final durationSec = _asInt(row['duration_sec']);
    if (durationSec < 0) return null;

    final startTs = _parseTs(row['start_ts'])?.toLocal();
    if (startTs == null && durationSec == 0) return null;
    final wrongDurSec = isPosture ? _asInt(row['wrong_dur_sec']) : null;

    final score = isPosture
        ? _scoreFrom(durationSec, wrongDurSec ?? 0)
        : null;

    final pattern = isPosture ? null : _asIntOrNull(row['therapy_pattern']);
    final alerts = isPosture ? _asIntOrNull(row['wrong_count']) : null;
    final dbId = row['id']?.toString();
    final tsSynced = row['ts_synced'] == true;

    final postureEvents = isPosture
        ? _parsePostureEvents(row['posture_events'])
        : null;
    final therapyPatterns = isPosture
        ? null
        : _parseTherapyPatterns(row['therapy_patterns']);

    return SessionData(
      id: index,
      dbId: dbId,
      type: type,
      name: isPosture ? 'Posture training' : 'Vibration therapy',
      time: _formatRelativeTime(startTs),
      date: _formatShortDate(startTs),
      duration: _formatDuration(durationSec),
      durationSec: durationSec,
      alerts: alerts,
      score: score,
      pattern: pattern,
      wrongDurSec: wrongDurSec,
      isLive: dbId != null && dbId == liveSessionId,
      tsSynced: tsSynced,
      startTs: startTs,
      postureEvents: postureEvents,
      therapyPatterns: therapyPatterns,
    );
  }

  List<PostureEvent>? _parsePostureEvents(dynamic raw) {
    if (raw is! List) return null;
    final out = <PostureEvent>[];
    for (final entry in raw) {
      if (entry is Map) {
        out.add(PostureEvent.fromJson(entry.cast<String, dynamic>()));
      }
    }
    return out.isEmpty ? null : out;
  }

  List<int>? _parseTherapyPatterns(dynamic raw) {
    if (raw is! List) return null;
    final out = <int>[];
    for (final entry in raw) {
      if (entry is num) {
        out.add(entry.toInt());
      } else {
        final parsed = int.tryParse(entry?.toString() ?? '');
        if (parsed != null) out.add(parsed);
      }
    }
    return out.isEmpty ? null : out;
  }

  /// Mirrors the canonical formula from the BLE sync layer so numbers shown
  /// in Analytics match what is stored on device.
  int _scoreFrom(int durationSec, int wrongDurSec) {
    if (durationSec <= 0) return 100;
    return (100 - (wrongDurSec / durationSec * 100)).round().clamp(0, 100);
  }

  _Aggregate _aggregate(List<Map<String, dynamic>> rows) {
    int totalPostureDur = 0;
    int totalWrongDur = 0;
    int therapyMinutes = 0;
    int trackedSec = 0;

    for (final row in rows) {
      final type = row['type']?.toString() ?? '';
      final dur = _asInt(row['duration_sec']);
      trackedSec += dur;
      if (type == 'posture') {
        totalPostureDur += dur;
        totalWrongDur += _asInt(row['wrong_dur_sec']);
      } else if (type == 'therapy') {
        therapyMinutes += (dur / 60).round();
      }
    }

    final pct = totalPostureDur > 0
        ? (100 - (totalWrongDur / totalPostureDur * 100)).round().clamp(0, 100)
        : 0;

    final trackedHoursNum = trackedSec / 3600.0;
    return _Aggregate(
      goodPosturePct: pct,
      trackedHours: trackedHoursNum.toStringAsFixed(1),
      trackedHoursNumeric: trackedHoursNum,
      sessionCount: rows.length,
      therapyMinutes: therapyMinutes,
    );
  }

  DateTime? _parseTs(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _formatDuration(int durationSec) {
    if (durationSec < 60) return '${durationSec}s';
    final minutes = (durationSec / 60).round();
    return '$minutes min';
  }

  String _formatShortDate(DateTime? ts) {
    if (ts == null) return '—';
    const months = [
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
    return '${months[ts.month - 1]} ${ts.day}';
  }

  String _formatRelativeTime(DateTime? ts) {
    if (ts == null) return '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tsDay = DateTime(ts.year, ts.month, ts.day);
    final diffDays = today.difference(tsDay).inDays;

    final hour = ts.hour == 0 ? 12 : (ts.hour > 12 ? ts.hour - 12 : ts.hour);
    final minute = ts.minute.toString().padLeft(2, '0');
    final ampm = ts.hour >= 12 ? 'PM' : 'AM';
    final hhmm = '$hour:$minute $ampm';

    if (diffDays == 0) return 'Today · $hhmm';
    if (diffDays == 1) return 'Yesterday · $hhmm';
    return '${_formatShortDate(ts)} · $hhmm';
  }
}

class _Aggregate {
  _Aggregate({
    required this.goodPosturePct,
    required this.trackedHours,
    required this.trackedHoursNumeric,
    required this.sessionCount,
    required this.therapyMinutes,
  });

  final int goodPosturePct;
  final String trackedHours;
  final double trackedHoursNumeric;
  final int sessionCount;
  final int therapyMinutes;
}
