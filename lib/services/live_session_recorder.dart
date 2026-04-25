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
    final row = <String, dynamic>{
      'user_id': user.id,
      'type': type,
      'start_ts': startAt.toUtc().toIso8601String(),
      'duration_sec': initialDurationSec,
      'wrong_count': type == 'posture' ? reading.liveSessionBadCount : null,
      'wrong_dur_sec': type == 'posture' ? 0 : null,
      'therapy_pattern': type == 'therapy'
          ? _patternIndexFrom(reading.therapyPattern)
          : null,
      'ts_synced': true,
    };

    try {
      final existing = await _findExistingSession(type, startAt);
      final id = existing?.id ?? await _insertSession(row);
      if (id == null || id.isEmpty) return;

      if (existing != null) {
        await _client.from('sessions').update(row).eq('id', id);
      }

      _active = _LiveSession(id: id, type: type, startedAt: startAt)
        ..wrongCount = type == 'posture' ? reading.liveSessionBadCount : 0
        ..therapyPattern = type == 'therapy'
            ? _patternIndexFrom(reading.therapyPattern)
            : null;
      _activeSessionId.value = id;
      _lastBadPosture = type == 'posture' && reading.isBadPosture;
      _badPostureStartedAt = _lastBadPosture ? now : null;
      _lastUpdateAt = now;
      _onSessionChanged?.call();
      debugPrint(
        'LiveSessionRecorder: started $type session id=$id '
        'elapsed=${initialDurationSec}s',
      );
    } catch (e) {
      debugPrint('LiveSessionRecorder: failed to start session: $e');
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
      if (pattern != null) active.therapyPattern = pattern;
      return;
    }

    if (reading.isBadPosture && !_lastBadPosture) {
      active.wrongCount++;
      _badPostureStartedAt = DateTime.now();
    } else if (!reading.isBadPosture &&
        _lastBadPosture &&
        _badPostureStartedAt != null) {
      active.wrongDurationSec += DateTime.now()
          .difference(_badPostureStartedAt!)
          .inSeconds
          .clamp(0, 1 << 30)
          .toInt();
      _badPostureStartedAt = null;
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
    final windowStart = startAt.subtract(const Duration(seconds: 10));
    final windowEnd = startAt.add(const Duration(seconds: 10));
    final rows = await _client
        .from('sessions')
        .select('id,start_ts')
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
    final epoch = reading.liveSessionStartEpoch;
    if (epoch > 1704067200) {
      return DateTime.fromMillisecondsSinceEpoch(
        epoch * 1000,
        isUtc: true,
      ).toLocal();
    }

    final elapsed = reading.liveSessionElapsedSeconds;
    if (elapsed > 0) {
      return now.subtract(Duration(seconds: elapsed));
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
}
