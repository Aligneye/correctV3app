import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SessionDatabase {
  SessionDatabase._();
  static final SessionDatabase instance = SessionDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    await initialize();
    return _db!;
  }

  Future<void> initialize() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aligneye_sessions.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id              TEXT PRIMARY KEY,
            user_id         TEXT NOT NULL,
            type            TEXT NOT NULL,
            start_ts        TEXT NOT NULL,
            duration_sec    INTEGER NOT NULL,
            wrong_count     INTEGER,
            wrong_dur_sec   INTEGER,
            therapy_pattern INTEGER,
            ts_synced       INTEGER NOT NULL DEFAULT 0,
            posture_events  TEXT,
            therapy_patterns TEXT,
            created_at      TEXT NOT NULL,
            sync_status     INTEGER NOT NULL DEFAULT 0,
            remote_id       TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_sessions_user_start ON sessions (user_id, start_ts DESC)',
        );
      },
    );
  }

  // ---------- UUID generation ----------

  static String generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ---------- Write operations ----------

  Future<String> insertSession(Map<String, dynamic> row) async {
    final db = await database;
    final id = row['id'] as String? ?? generateId();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('sessions', {
      'id': id,
      'user_id': row['user_id'],
      'type': row['type'],
      'start_ts': row['start_ts'],
      'duration_sec': row['duration_sec'],
      'wrong_count': row['wrong_count'],
      'wrong_dur_sec': row['wrong_dur_sec'],
      'therapy_pattern': row['therapy_pattern'],
      'ts_synced': (row['ts_synced'] == true || row['ts_synced'] == 1) ? 1 : 0,
      'posture_events': _encodeJson(row['posture_events']),
      'therapy_patterns': _encodeJson(row['therapy_patterns']),
      'created_at': row['created_at'] as String? ?? now,
      'sync_status': row['sync_status'] as int? ?? 0,
      'remote_id': row['remote_id'] as String?,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateSession(String id, Map<String, dynamic> fields) async {
    final db = await database;
    final update = <String, dynamic>{};
    if (fields.containsKey('duration_sec')) {
      update['duration_sec'] = fields['duration_sec'];
    }
    if (fields.containsKey('wrong_count')) {
      update['wrong_count'] = fields['wrong_count'];
    }
    if (fields.containsKey('wrong_dur_sec')) {
      update['wrong_dur_sec'] = fields['wrong_dur_sec'];
    }
    if (fields.containsKey('therapy_pattern')) {
      update['therapy_pattern'] = fields['therapy_pattern'];
    }
    if (fields.containsKey('ts_synced')) {
      update['ts_synced'] =
          (fields['ts_synced'] == true || fields['ts_synced'] == 1) ? 1 : 0;
    }
    if (fields.containsKey('posture_events')) {
      update['posture_events'] = _encodeJson(fields['posture_events']);
    }
    if (fields.containsKey('therapy_patterns')) {
      update['therapy_patterns'] = _encodeJson(fields['therapy_patterns']);
    }
    if (update.isEmpty) return;
    // Mark as dirty unless explicitly set.
    if (!fields.containsKey('sync_status')) {
      update['sync_status'] = 2;
    } else {
      update['sync_status'] = fields['sync_status'];
    }
    await db.update('sessions', update, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSynced(String localId, String remoteId) async {
    final db = await database;
    await db.update(
      'sessions',
      {'sync_status': 1, 'remote_id': remoteId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertFromRemote(Map<String, dynamic> remoteRow) async {
    final db = await database;
    final remoteId = remoteRow['id']?.toString();
    if (remoteId == null) return;

    final userId = remoteRow['user_id']?.toString() ?? '';
    final type = remoteRow['type']?.toString() ?? '';
    final startTs = remoteRow['start_ts']?.toString() ?? '';

    // Check if we already have this by remote_id.
    final byRemote = await db.query(
      'sessions',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (byRemote.isNotEmpty) {
      final localId = byRemote.first['id'] as String;
      await db.update('sessions', {
        'duration_sec': remoteRow['duration_sec'],
        'wrong_count': remoteRow['wrong_count'],
        'wrong_dur_sec': remoteRow['wrong_dur_sec'],
        'therapy_pattern': remoteRow['therapy_pattern'],
        'ts_synced': (remoteRow['ts_synced'] == true) ? 1 : 0,
        'posture_events': _encodeJson(remoteRow['posture_events']),
        'therapy_patterns': _encodeJson(remoteRow['therapy_patterns']),
        'sync_status': 1,
      }, where: 'id = ?', whereArgs: [localId]);
      return;
    }

    // Check by dedupe window.
    if (startTs.isNotEmpty) {
      final existing = await findExistingByStartTs(
        userId, type, DateTime.parse(startTs), const Duration(seconds: 10),
      );
      if (existing != null) {
        await db.update('sessions', {
          'duration_sec': remoteRow['duration_sec'],
          'wrong_count': remoteRow['wrong_count'],
          'wrong_dur_sec': remoteRow['wrong_dur_sec'],
          'therapy_pattern': remoteRow['therapy_pattern'],
          'ts_synced': (remoteRow['ts_synced'] == true) ? 1 : 0,
          'posture_events': _encodeJson(remoteRow['posture_events']),
          'therapy_patterns': _encodeJson(remoteRow['therapy_patterns']),
          'sync_status': 1,
          'remote_id': remoteId,
        }, where: 'id = ?', whereArgs: [existing]);
        return;
      }
    }

    // Insert as new synced row.
    await insertSession({
      'id': generateId(),
      'user_id': userId,
      'type': type,
      'start_ts': startTs,
      'duration_sec': remoteRow['duration_sec'] ?? 0,
      'wrong_count': remoteRow['wrong_count'],
      'wrong_dur_sec': remoteRow['wrong_dur_sec'],
      'therapy_pattern': remoteRow['therapy_pattern'],
      'ts_synced': remoteRow['ts_synced'],
      'posture_events': remoteRow['posture_events'],
      'therapy_patterns': remoteRow['therapy_patterns'],
      'created_at': remoteRow['created_at']?.toString(),
      'sync_status': 1,
      'remote_id': remoteId,
    });
  }

  // ---------- Read operations ----------

  Future<List<Map<String, dynamic>>> fetchByUser(
    String userId, {
    DateTime? since,
  }) async {
    final db = await database;
    final where = StringBuffer('user_id = ?');
    final args = <dynamic>[userId];
    if (since != null) {
      where.write(' AND start_ts >= ?');
      args.add(since.toUtc().toIso8601String());
    }
    final rows = await db.query(
      'sessions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'start_ts DESC',
    );
    return rows.map(_decodeRow).toList();
  }

  Future<List<Map<String, dynamic>>> fetchBetween(
    String userId,
    DateTime start,
    DateTime end, {
    String? typeFilter,
  }) async {
    final db = await database;
    final where = StringBuffer('user_id = ? AND start_ts >= ? AND start_ts < ?');
    final args = <dynamic>[
      userId,
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String(),
    ];
    if (typeFilter != null) {
      where.write(' AND type = ?');
      args.add(typeFilter);
    }
    final rows = await db.query(
      'sessions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'start_ts DESC',
    );
    return rows.map(_decodeRow).toList();
  }

  // ---------- Sync operations ----------

  Future<List<Map<String, dynamic>>> fetchUnsynced(String userId) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'user_id = ? AND sync_status != 1',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_decodeRow).toList();
  }

  // ---------- Dedup ----------

  Future<String?> findExistingByStartTs(
    String userId,
    String type,
    DateTime startTs,
    Duration window,
  ) async {
    final db = await database;
    final windowStart = startTs.subtract(window).toUtc().toIso8601String();
    final windowEnd = startTs.add(window).toUtc().toIso8601String();
    final rows = await db.query(
      'sessions',
      columns: ['id'],
      where: 'user_id = ? AND type = ? AND start_ts >= ? AND start_ts <= ?',
      whereArgs: [userId, type, windowStart, windowEnd],
      orderBy: 'start_ts DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  // ---------- Helpers ----------

  String? _encodeJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }

  Map<String, dynamic> _decodeRow(Map<String, dynamic> row) {
    final result = Map<String, dynamic>.from(row);
    result['ts_synced'] = (row['ts_synced'] == 1);
    if (row['posture_events'] is String) {
      try {
        result['posture_events'] = jsonDecode(row['posture_events'] as String);
      } catch (_) {
        result['posture_events'] = null;
      }
    }
    if (row['therapy_patterns'] is String) {
      try {
        result['therapy_patterns'] =
            jsonDecode(row['therapy_patterns'] as String);
      } catch (_) {
        result['therapy_patterns'] = null;
      }
    }
    return result;
  }

  Future<bool> hasDataForUser(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM sessions WHERE user_id = ?',
      [userId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  @visibleForTesting
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
