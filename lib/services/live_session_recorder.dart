import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/bluetooth/aligneye_device_service.dart';

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

  static const Duration _updateInterval = Duration(seconds: 5);
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
    if (!enabled) {
      unawaited(_finishActiveSession());
    }
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
      unawaited(_finishActiveSession());
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
    final row = <String, dynamic>{
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
    };

    try {
      final existing = await _findExistingSession(type, startAt);
      String? id;
      if (existing != null) {
        id = existing.id;
        await _client.from('sessions').update(row).eq('id', id);
        debugPrint(
          'LiveSessionRecorder: reusing existing $type session id=$id',
        );
      } else {
        id = await _insertSession(row);
        debugPrint(
          'LiveSessionRecorder: inserted new $type session id=$id',
        );
      }
      if (id == null || id.isEmpty) {
        debugPrint('LiveSessionRecorder: session id is null/empty, aborting');
        return;
      }

      _active = _LiveSession(id: id, type: type, startedAt: startAt)
        ..wrongCount = type == 'posture' ? reading.liveSessionBadCount : 0
        ..therapyPattern = initialPattern
        ..therapyPatternSequence = initialPattern != null ? [initialPattern] : [];
      _activeSessionId.value = id;
      _lastBadPosture = type == 'posture' && reading.isBadPosture;
      _badPostureStartedAt = _lastBadPosture ? now : null;
      if (_lastBadPosture) {
        _active!.pendingSlouchOffsetSec = 0;
      }
      _lastUpdateAt = now;
      _onSessionChanged?.call();
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
        // Mark as still-bad-at-end with the firmware's sentinel so the UI
        // renders an open-ended slouch instead of a zero-length pair.
        active.postureEvents.add({'s': slouchOffset, 'c': 0xFFFF});
        active.pendingSlouchOffsetSec = null;
      }
    }

    final duration = DateTime.now().difference(active.startedAt);
    if (duration < _minimumSessionDuration) {
      await _deleteShortSession(active);
    } else {
      await _persistActiveSession(force: true);
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
      await _client.from('sessions').delete().eq('id', active.id);
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
      final pattern = _patternIndexFrom(reading.therapyPattern);
      if (pattern != null) {
        active.therapyPattern = pattern;
        // Append only on transitions so the sequence mirrors the firmware's
        // pattern-played history rather than duplicating the same index for
        // every BLE tick.
        final seq = active.therapyPatternSequence;
        if (seq.isEmpty || seq.last != pattern) {
          seq.add(pattern);
        }
      }
      return;
    }

    final now = DateTime.now();
    final elapsedSec = now
        .difference(active.startedAt)
        .inSeconds
        .clamp(0, 0xFFFE)
        .toInt();

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
        final durationSec = now
            .difference(active.startedAt)
            .inSeconds
            .clamp(1, 1 << 30)
            .toInt();
        final wrongDurationSec =
            active.wrongDurationSec +
            (_badPostureStartedAt == null
                ? 0
                : now
                      .difference(_badPostureStartedAt!)
                      .inSeconds
                      .clamp(0, 1 << 30)
                      .toInt());
        await _client
            .from('sessions')
            .update({
              'duration_sec': durationSec,
              'wrong_count': active.type == 'posture'
                  ? active.wrongCount
                  : null,
              'wrong_dur_sec': active.type == 'posture'
                  ? wrongDurationSec
                  : null,
              'therapy_pattern': active.type == 'therapy'
                  ? active.therapyPattern
                  : null,
              'posture_events': active.type == 'posture'
                  ? active.postureEvents
                  : null,
              'therapy_patterns':
                  active.type == 'therapy' && active.therapyPatternSequence.isNotEmpty
                  ? active.therapyPatternSequence
                  : null,
            })
            .eq('id', active.id);
        _lastUpdateAt = now;
        _onSessionChanged?.call();
      } while (_dirtyWhileWriting);
    } catch (e) {
      debugPrint('LiveSessionRecorder: failed to update session: $e');
    } finally {
      _writeInFlight = false;
    }
  }

  Future<String?> _insertSession(Map<String, dynamic> row) async {
    final inserted = await _client
        .from('sessions')
        .insert(row)
        .select('id')
        .single();
    return inserted['id']?.toString();
  }

  Future<_ExistingSession?> _findExistingSession(
    String type,
    DateTime startAt,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final windowStart = startAt.subtract(const Duration(seconds: 10));
    final windowEnd = startAt.add(const Duration(seconds: 10));
    final rows = await _client
        .from('sessions')
        .select('id,start_ts')
        .eq('user_id', user.id)
        .eq('type', type)
        .gte('start_ts', windowStart.toUtc().toIso8601String())
        .lte('start_ts', windowEnd.toUtc().toIso8601String())
        .order('start_ts', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;
    final row = rows.first;
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return _ExistingSession(id: id);
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
    final match = RegExp(r'S\d+:(\d+)').firstMatch(pattern);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}

class _ExistingSession {
  _ExistingSession({required this.id});

  final String id;
}

class _LiveSession {
  _LiveSession({required this.id, required this.type, required this.startedAt});

  final String id;
  final String type;
  final DateTime startedAt;
  int wrongCount = 0;
  int wrongDurationSec = 0;
  int? therapyPattern;

  /// Posture event timeline. Each entry is the {s,c} pair the firmware
  /// would have written: `s` = slouch start (sec from session start),
  /// `c` = correction time (or 0xFFFF if not yet corrected).
  final List<Map<String, int>> postureEvents = <Map<String, int>>[];

  /// Offset (sec from session start) of an in-flight slouch that hasn't
  /// been corrected yet. `null` while posture is good.
  int? pendingSlouchOffsetSec;

  /// Therapy patterns played during the session, in order seen.
  List<int> therapyPatternSequence = <int>[];
}
