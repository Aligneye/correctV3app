import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/services/session_database.dart';

/// Background service that pushes locally-stored sessions to Supabase.
///
/// Runs on a periodic timer and can be triggered on-demand after local writes.
/// Errors are caught silently — unsynced rows remain and retry next cycle.
class SessionSyncService {
  SessionSyncService._();
  static final SessionSyncService instance = SessionSyncService._();

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  bool _syncing = false;

  static const Duration _interval = Duration(seconds: 30);
  static const Duration _debounce = Duration(seconds: 2);

  SupabaseClient get _client => Supabase.instance.client;

  void start() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_interval, (_) => _run());
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void triggerSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _run);
  }

  Future<void> _run() async {
    if (_syncing) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    _syncing = true;
    try {
      await _pushUnsynced(user.id);
    } catch (e) {
      debugPrint('SessionSyncService: push error: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushUnsynced(String userId) async {
    final db = SessionDatabase.instance;
    final rows = await db.fetchUnsynced(userId);
    if (rows.isEmpty) return;

    debugPrint('SessionSyncService: pushing ${rows.length} unsynced rows');

    for (final row in rows) {
      final localId = row['id'] as String?;
      if (localId == null) continue;

      final remoteId = row['remote_id'] as String?;
      final syncStatus = row['sync_status'] as int? ?? 0;

      final payload = <String, dynamic>{
        'user_id': row['user_id'],
        'type': row['type'],
        'start_ts': row['start_ts'],
        'duration_sec': row['duration_sec'],
        'wrong_count': row['wrong_count'],
        'wrong_dur_sec': row['wrong_dur_sec'],
        'therapy_pattern': row['therapy_pattern'],
        'ts_synced': row['ts_synced'] == true || row['ts_synced'] == 1,
        'posture_events': row['posture_events'],
        'therapy_patterns': row['therapy_patterns'],
      };

      try {
        if (remoteId == null && syncStatus == 0) {
          // New row — insert into Supabase and store returned ID.
          final inserted = await _client
              .from('sessions')
              .insert(payload)
              .select('id')
              .single();
          final newRemoteId = inserted['id']?.toString();
          if (newRemoteId != null) {
            await db.markSynced(localId, newRemoteId);
            debugPrint('SessionSyncService: pushed new → remote=$newRemoteId');
          }
        } else if (remoteId != null && syncStatus == 2) {
          // Dirty row — update in Supabase.
          await _client.from('sessions').update(payload).eq('id', remoteId);
          await db.markSynced(localId, remoteId);
          debugPrint('SessionSyncService: pushed update → remote=$remoteId');
        }
      } catch (e) {
        // Network error or Supabase rejection — skip this row, retry next cycle.
        debugPrint('SessionSyncService: failed to push id=$localId: $e');
        break;
      }
    }
  }
}
