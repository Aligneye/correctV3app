import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/services/session_database.dart';
import 'package:correctv1/services/session_sync_service.dart';
import 'package:correctv1/services/therapy_pattern_names.dart';

class LiveSessionRecorder {
  LiveSessionRecorder({
    required AlignEyeDeviceService deviceService,
    required ValueNotifier<String?> activeSessionId,
    SupabaseClient? client,
    VoidCallback? onSessionChanged,
  }) : _deviceService = deviceService,
       _activeSessionId = activeSessionId,
       _client = client ?? Supabase.instance.client,
       _onSessionChanged = onSessionChanged;

  final AlignEyeDeviceService _deviceService;
  final ValueNotifier<String?> _activeSessionId;
  final SupabaseClient _client;
  final VoidCallback? _onSessionChanged;

  StreamSubscription<PostureReading>? _readingSub;
  bool _started = false;
  _LiveSession? _active;
  bool _lastBadPosture = false;
  DateTime? _badPostureStartedAt;
  DateTime? _lastUpdateAt;
  bool _writeInFlight = false;
  bool _dirtyWhileWriting = false;
  bool _transitionInFlight = false;
  bool _enabled = false;

  // Context the app stashes right before asking the device to start therapy.
  // Consumed (and cleared) on the next THERAPY session start so that the
  // row mirrors the user's selections on Supabase. Only meaningful for
  // therapy; posture sessions ignore it.
  _TherapyLaunchContext? _pendingTherapyContext;

  // Cadence the recorder persists to SQLite during an active session. Short
  // enough that the UI feels live (duration counter and pattern history
  // update several times per firmware pattern advance) but long enough to
  // avoid write amplification on the phone's flash.
  static const Duration _updateInterval = Duration(milliseconds: 1500);
  static const Duration _minimumSessionDuration = Duration(seconds: 30);

  void start() {
    if (_started) return;
    _started = true;
    _deviceService.connectionStatus.addListener(_handleConnectionStatus);
    _readingSub = _deviceService.readings.listen(_handleReading);
  }

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    debugPrint('LiveSessionRecorder: enabled=$enabled');
    // Intentionally do NOT finish the active session when disabled. Disabling
    // happens around BLE sync windows and during brief disconnects; forcing
    // a "finish" here truncates the in-progress session's duration and opens
    // the door for a duplicate row to appear on reconnect. The session gets
    // finalized naturally when:
    //   - the device reports a non-therapy/non-posture mode (mode switch), or
    //   - the BLE connection drops (handled in _handleConnectionStatus).
  }

  /// Stash the therapy context picked on the app (target point, intensity,
  /// planned duration) so the next therapy session started by the device
  /// can mirror it on Supabase. Context expires after 60s to avoid sticking
  /// stale values to an unrelated session.
  void primeTherapyContext({
    String? targetPoint,
    int? intensityLevel,
    int? plannedDurationMinutes,
  }) {
    _pendingTherapyContext = _TherapyLaunchContext(
      capturedAt: DateTime.now(),
      targetPoint: targetPoint,
      intensityLevel: intensityLevel,
      plannedDurationSec: plannedDurationMinutes == null
          ? null
          : plannedDurationMinutes * 60,
    );
    debugPrint(
      'LiveSessionRecorder: primed therapy context '
      'point=$targetPoint level=$intensityLevel dur=${plannedDurationMinutes}m',
    );
  }

  _TherapyLaunchContext? _consumeTherapyContext() {
    final ctx = _pendingTherapyContext;
    if (ctx == null) return null;
    if (DateTime.now().difference(ctx.capturedAt) >
        const Duration(seconds: 60)) {
      _pendingTherapyContext = null;
      return null;
    }
    _pendingTherapyContext = null;
    return ctx;
  }

  Future<void> dispose() async {
    if (_started) {
      _deviceService.connectionStatus.removeListener(_handleConnectionStatus);
      _started = false;
    }
    await _readingSub?.cancel();
    _readingSub = null;
  }

  void _handleConnectionStatus() {
    if (_deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      // BLE dropped. Persist whatever we have so far so the row on disk
      // reflects the latest observed duration, but KEEP _active in memory.
      // If the connection comes back while the session is still running,
      // _handleReading will see it's the same in-memory session and keep
      // appending — no data loss, no duplicate row.
      if (_active != null) {
        unawaited(_persistActiveSession(force: true));
      }
    }
  }

  void _handleReading(PostureReading reading) {
    if (_deviceService.connectionStatus.value !=
        DeviceConnectionStatus.connected) {
      return;
    }
    if (!_enabled) return;

    final type = _typeForMode(reading.mode);
    if (type == null) {
      unawaited(_finishActiveSession());
      return;
    }

    final active = _active;
    if (_transitionInFlight) return;
    if (active == null || active.type != type) {
      debugPrint(
        'LiveSessionRecorder: mode=${reading.mode} → type=$type, '
        'active=${active?.type}, switching session',
      );
      unawaited(_switchSession(type, reading));
      return;
    }

    _updateCounters(reading);
    if (_shouldPersistUpdate()) {
      unawaited(_persistActiveSession());
    }
  }

  Future<void> _switchSession(String type, PostureReading reading) async {
    if (_transitionInFlight) return;
    _transitionInFlight = true;
    try {
      await _finishActiveSession();
      await _startSession(type, reading);
    } finally {
      _transitionInFlight = false;
    }
  }

  Future<void> _startSession(String type, PostureReading reading) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('LiveSessionRecorder: no user, cannot create live session');
      return;
    }

    final now = DateTime.now();
    final startAt = _startTimeFor(reading, now);
    final initialDurationSec = _durationFrom(reading, startAt, now);
    final initialPattern = type == 'therapy'
        ? _patternIndexFrom(reading.therapyPattern)
        : null;
    final initialPatternEvents = type == 'therapy' && initialPattern != null
        ? <Map<String, int>>[
            {'p': initialPattern, 's': 0, 'd': initialDurationSec},
          ]
        : null;

    // Therapy-only context. Prefer live device values, fall back to what the
    // user selected in the app before starting. `primeTherapyContext` is the
    // only path for the acupressure point — it's app-only.
    final therapyCtx = type == 'therapy' ? _consumeTherapyContext() : null;
    final initialIntensity = type == 'therapy'
        ? ((reading.therapyIntensityLevel >= 1 &&
                  reading.therapyIntensityLevel <= 3)
              ? reading.therapyIntensityLevel
              : therapyCtx?.intensityLevel)
        : null;
    final initialPlanSequence =
        type == 'therapy' && reading.therapyPatternSequence.isNotEmpty
        ? List<int>.from(reading.therapyPatternSequence)
        : null;
    final initialPlannedDurationSec = type == 'therapy'
        ? therapyCtx?.plannedDurationSec
        : null;
    final initialTargetPoint = type == 'therapy'
        ? therapyCtx?.targetPoint
        : null;

    try {
      final db = SessionDatabase.instance;
      final existingId = await db.findExistingByStartTs(
        user.id,
        type,
        startAt,
        const Duration(seconds: 10),
      );

      String id;
      if (existingId != null) {
        id = existingId;
        await db.updateSession(id, {
          'duration_sec': initialDurationSec,
          'wrong_count': type == 'posture' ? reading.liveSessionBadCount : null,
          'wrong_dur_sec': type == 'posture' ? 0 : null,
          'therapy_pattern': initialPattern,
          'ts_synced': true,
          'posture_events': type == 'posture' ? <Map<String, int>>[] : null,
          'therapy_patterns': type == 'therapy' && initialPattern != null
              ? <int>[initialPattern]
              : null,
          'therapy_pattern_events': initialPatternEvents,
          'therapy_intensity_level': initialIntensity,
          'therapy_target_point': initialTargetPoint,
          'planned_duration_sec': initialPlannedDurationSec,
          'planned_pattern_sequence': initialPlanSequence,
        });
        debugPrint(
          'LiveSessionRecorder: reusing existing $type session id=$id',
        );
      } else {
        id = await db.insertSession({
          'user_id': user.id,
          'type': type,
          'start_ts': startAt.toUtc().toIso8601String(),
          'duration_sec': initialDurationSec,
          'wrong_count': type == 'posture' ? reading.liveSessionBadCount : null,
          'wrong_dur_sec': type == 'posture' ? 0 : null,
          'therapy_pattern': initialPattern,
          'ts_synced': true,
          'posture_events': type == 'posture' ? <Map<String, int>>[] : null,
          'therapy_patterns': type == 'therapy' && initialPattern != null
              ? <int>[initialPattern]
              : null,
          'therapy_pattern_events': initialPatternEvents,
          'therapy_intensity_level': initialIntensity,
          'therapy_target_point': initialTargetPoint,
          'planned_duration_sec': initialPlannedDurationSec,
          'planned_pattern_sequence': initialPlanSequence,
          'sync_status': 0,
        });
        debugPrint('LiveSessionRecorder: inserted new $type session id=$id');
      }

      _active = _LiveSession(id: id, type: type, startedAt: startAt)
        ..wrongCount = type == 'posture' ? reading.liveSessionBadCount : 0
        ..therapyPattern = initialPattern
        ..durationSec = initialDurationSec
        ..therapyPatternSequence = initialPattern != null
            ? [initialPattern]
            : []
        ..therapyPatternEvents = initialPatternEvents ?? <Map<String, int>>[]
        ..therapyIntensityLevel = initialIntensity
        ..therapyTargetPoint = initialTargetPoint
        ..plannedDurationSec = initialPlannedDurationSec
        ..plannedPatternSequence = initialPlanSequence;
      _activeSessionId.value = id;
      _lastBadPosture = type == 'posture' && reading.isBadPosture;
      _badPostureStartedAt = _lastBadPosture ? now : null;
      if (_lastBadPosture) {
        _active!.pendingSlouchOffsetSec = 0;
      }
      _lastUpdateAt = now;
      _onSessionChanged?.call();
      SessionSyncService.instance.triggerSync();
      debugPrint(
        'LiveSessionRecorder: started $type session id=$id '
        'elapsed=${initialDurationSec}s startAt=$startAt',
      );
    } catch (e, st) {
      debugPrint('LiveSessionRecorder: failed to start session: $e\n$st');
    }
  }

  Future<void> _finishActiveSession() async {
    final active = _active;
    if (active == null) return;

    if (active.type == 'posture' && _badPostureStartedAt != null) {
      active.wrongDurationSec += DateTime.now()
          .difference(_badPostureStartedAt!)
          .inSeconds
          .clamp(0, 1 << 30)
          .toInt();
      _badPostureStartedAt = null;

      final slouchOffset = active.pendingSlouchOffsetSec;
      if (slouchOffset != null) {
        active.postureEvents.add({'s': slouchOffset, 'c': 0xFFFF});
        active.pendingSlouchOffsetSec = null;
      }
    }

    final durationSec = _currentDurationSec(active, DateTime.now());
    if (durationSec < _minimumSessionDuration.inSeconds) {
      await _deleteShortSession(active);
    } else {
      await _persistActiveSession(force: true);
      SessionSyncService.instance.triggerSync();
    }

    debugPrint('LiveSessionRecorder: finished ${active.type} session');
    _active = null;
    _activeSessionId.value = null;
    _lastBadPosture = false;
    _badPostureStartedAt = null;
    _onSessionChanged?.call();
  }

  Future<void> _deleteShortSession(_LiveSession active) async {
    try {
      await SessionDatabase.instance.deleteSession(active.id);
      debugPrint(
        'LiveSessionRecorder: deleted short ${active.type} session '
        'id=${active.id}',
      );
    } catch (e) {
      debugPrint('LiveSessionRecorder: failed to delete short session: $e');
    }
  }

  void _updateCounters(PostureReading reading) {
    final active = _active;
    if (active == null) return;

    if (active.type == 'therapy') {
      if (reading.therapyIntensityLevel >= 1 &&
          reading.therapyIntensityLevel <= 3) {
        active.therapyIntensityLevel = reading.therapyIntensityLevel;
      }
      if (reading.therapyPatternSequence.isNotEmpty) {
        active.plannedPatternSequence = List<int>.from(
          reading.therapyPatternSequence,
        );
      }
      final pattern = _patternIndexFrom(reading.therapyPattern);
      if (pattern != null) {
        final elapsedSec = _durationFrom(
          reading,
          active.startedAt,
          DateTime.now(),
        );
        active.durationSec = elapsedSec;
        active.therapyPattern = pattern;
        final seq = active.therapyPatternSequence;
        if (seq.isEmpty || seq.last != pattern) {
          if (active.therapyPatternEvents.isNotEmpty) {
            final previous = active.therapyPatternEvents.last;
            final previousStart = previous['s'] ?? 0;
            previous['d'] = (elapsedSec - previousStart)
                .clamp(0, 1 << 30)
                .toInt();
          }
          seq.add(pattern);
          active.therapyPatternEvents.add({
            'p': pattern,
            's': elapsedSec,
            'd': 0,
          });
        }
      }
      return;
    }

    final now = DateTime.now();
    final elapsedSec = _durationFrom(
      reading,
      active.startedAt,
      now,
    ).clamp(0, 0xFFFE).toInt();
    active.durationSec = elapsedSec;

    if (reading.isBadPosture && !_lastBadPosture) {
      active.wrongCount++;
      _badPostureStartedAt = now;
      active.pendingSlouchOffsetSec = elapsedSec;
    } else if (!reading.isBadPosture &&
        _lastBadPosture &&
        _badPostureStartedAt != null) {
      active.wrongDurationSec += now
          .difference(_badPostureStartedAt!)
          .inSeconds
          .clamp(0, 1 << 30)
          .toInt();
      _badPostureStartedAt = null;

      final slouchOffset = active.pendingSlouchOffsetSec;
      if (slouchOffset != null) {
        active.postureEvents.add({'s': slouchOffset, 'c': elapsedSec});
        active.pendingSlouchOffsetSec = null;
      }
    }
    _lastBadPosture = reading.isBadPosture;
  }

  bool _shouldPersistUpdate() {
    final last = _lastUpdateAt;
    return last == null || DateTime.now().difference(last) >= _updateInterval;
  }

  Future<void> _persistActiveSession({bool force = false}) async {
    final active = _active;
    if (active == null) return;
    if (!force && !_shouldPersistUpdate()) return;

    if (_writeInFlight) {
      _dirtyWhileWriting = true;
      return;
    }

    _writeInFlight = true;
    try {
      do {
        _dirtyWhileWriting = false;
        final now = DateTime.now();
        final durationSec = _currentDurationSec(active, now);
        final therapyPatternEvents = active.type == 'therapy'
            ? _closedTherapyPatternEvents(active, durationSec)
            : null;
        final wrongDurationSec =
            active.wrongDurationSec +
            (_badPostureStartedAt == null
                ? 0
                : now
                      .difference(_badPostureStartedAt!)
                      .inSeconds
                      .clamp(0, 1 << 30)
                      .toInt());
        await SessionDatabase.instance.updateSession(active.id, {
          'duration_sec': durationSec,
          'wrong_count': active.type == 'posture' ? active.wrongCount : null,
          'wrong_dur_sec': active.type == 'posture' ? wrongDurationSec : null,
          'therapy_pattern': active.type == 'therapy'
              ? active.therapyPattern
              : null,
          'posture_events': active.type == 'posture'
              ? active.postureEvents
              : null,
          'therapy_patterns':
              active.type == 'therapy' &&
                  active.therapyPatternSequence.isNotEmpty
              ? active.therapyPatternSequence
              : null,
          'therapy_pattern_events':
              active.type == 'therapy' && therapyPatternEvents != null
              ? therapyPatternEvents
              : null,
          'therapy_intensity_level': active.type == 'therapy'
              ? active.therapyIntensityLevel
              : null,
          'therapy_target_point': active.type == 'therapy'
              ? active.therapyTargetPoint
              : null,
          'planned_duration_sec': active.type == 'therapy'
              ? active.plannedDurationSec
              : null,
          'planned_pattern_sequence': active.type == 'therapy'
              ? active.plannedPatternSequence
              : null,
        });
        _lastUpdateAt = now;
        _onSessionChanged?.call();
      } while (_dirtyWhileWriting);
      // Kick the Supabase push after every local persist. The sync service
      // debounces internally (500 ms) so rapid updates coalesce into one
      // network round-trip.
      SessionSyncService.instance.triggerSync();
    } catch (e) {
      debugPrint('LiveSessionRecorder: failed to update session: $e');
    } finally {
      _writeInFlight = false;
    }
  }

  DateTime _startTimeFor(PostureReading reading, DateTime now) {
    final elapsed = reading.liveSessionElapsedSeconds;
    final epoch = reading.liveSessionStartEpoch;

    if (epoch > 1704067200 && elapsed > 0) {
      final epochStart = DateTime.fromMillisecondsSinceEpoch(
        epoch * 1000,
        isUtc: true,
      ).toLocal();
      final elapsedStart = now.subtract(Duration(seconds: elapsed));
      if ((epochStart.difference(elapsedStart).inSeconds).abs() <= 10) {
        return epochStart;
      }
      return elapsedStart;
    }

    if (elapsed > 0) {
      return now.subtract(Duration(seconds: elapsed));
    }

    if (epoch > 1704067200) {
      return DateTime.fromMillisecondsSinceEpoch(
        epoch * 1000,
        isUtc: true,
      ).toLocal();
    }

    return now;
  }

  int _durationFrom(PostureReading reading, DateTime startAt, DateTime now) {
    if (reading.liveSessionElapsedSeconds > 0) {
      return reading.liveSessionElapsedSeconds;
    }
    return now.difference(startAt).inSeconds.clamp(1, 1 << 30).toInt();
  }

  int _currentDurationSec(_LiveSession active, DateTime now) {
    final wallClockSec = now
        .difference(active.startedAt)
        .inSeconds
        .clamp(1, 1 << 30)
        .toInt();
    final durationSec = active.durationSec > wallClockSec
        ? active.durationSec
        : wallClockSec;
    active.durationSec = durationSec;
    return durationSec;
  }

  String? _typeForMode(String mode) {
    final normalized = mode.trim().toUpperCase();
    if (normalized == 'TRAINING' || normalized == 'POSTURE') {
      return 'posture';
    }
    if (normalized == 'THERAPY') {
      return 'therapy';
    }
    return null;
  }

  int? _patternIndexFrom(String pattern) {
    final byName = therapyPatternIndexFromName(pattern);
    if (byName != null) return byName;

    final match = RegExp(
      r'(?:pattern|patt|p)[\s:#-]*(\d+)',
      caseSensitive: false,
    ).firstMatch(pattern);
    if (match != null) {
      final devicePattern = int.tryParse(match.group(1)!);
      if (devicePattern == null) return null;
      if (devicePattern >= 1 && devicePattern <= kTherapyPatternNames.length) {
        return devicePattern - 1;
      }
      return therapyPatternIndexFromDeviceNumber(devicePattern);
    }
    return null;
  }

  List<Map<String, int>>? _closedTherapyPatternEvents(
    _LiveSession active,
    int durationSec,
  ) {
    if (active.therapyPatternEvents.isEmpty) return null;
    final events = active.therapyPatternEvents
        .map((event) => Map<String, int>.from(event))
        .toList(growable: false);
    final last = events.last;
    final lastStart = last['s'] ?? 0;
    last['d'] = (durationSec - lastStart).clamp(0, 1 << 30).toInt();
    return events;
  }
}

class _LiveSession {
  _LiveSession({required this.id, required this.type, required this.startedAt});

  final String id;
  final String type;
  final DateTime startedAt;
  int wrongCount = 0;
  int wrongDurationSec = 0;
  int durationSec = 0;
  int? therapyPattern;

  final List<Map<String, int>> postureEvents = <Map<String, int>>[];
  int? pendingSlouchOffsetSec;
  List<int> therapyPatternSequence = <int>[];
  List<Map<String, int>> therapyPatternEvents = <Map<String, int>>[];

  // Therapy-only context mirrored on Supabase.
  int? therapyIntensityLevel;
  String? therapyTargetPoint;
  int? plannedDurationSec;
  List<int>? plannedPatternSequence;
}

/// Launch context provided by [TherapyPage] right before it asks the device
/// to enter therapy mode. We keep it in the recorder until the first
/// therapy reading arrives so the inserted row carries the user's choices.
class _TherapyLaunchContext {
  _TherapyLaunchContext({
    required this.capturedAt,
    required this.targetPoint,
    required this.intensityLevel,
    required this.plannedDurationSec,
  });

  final DateTime capturedAt;
  final String? targetPoint;
  final int? intensityLevel;
  final int? plannedDurationSec;
}
