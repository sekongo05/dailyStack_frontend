import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../features/learning/models/lesson_models.dart';
import '../../features/watch/models/news_models.dart';

class PendingSyncItem {
  final int id;
  final String actionType;
  final Map<String, dynamic> payload;

  PendingSyncItem({
    required this.id,
    required this.actionType,
    required this.payload,
  });
}

class LocalDatabase {
  static const _dbName = 'dailystack_offline.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_lessons (
            id INTEGER PRIMARY KEY,
            json_payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_news (
            id INTEGER PRIMARY KEY,
            json_payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> cacheLessons(List<LessonDetail> lessons) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final lesson in lessons) {
      batch.insert(
        'cached_lessons',
        {
          'id': lesson.id,
          'json_payload': jsonEncode(lesson.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<LessonDetail?> getCachedLesson(int lessonId) async {
    final db = await database;
    final rows = await db.query(
      'cached_lessons',
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = jsonDecode(rows.first['json_payload'] as String);
    return LessonDetail.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> cacheNews(List<TechNewsSummary> news) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in news) {
      batch.insert(
        'cached_news',
        {
          'id': item.id,
          'json_payload': jsonEncode(item.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TechNewsSummary>> getCachedNews() async {
    final db = await database;
    final rows = await db.query('cached_news', orderBy: 'id DESC');
    return rows
        .map((r) => TechNewsSummary.fromJson(
              jsonDecode(r['json_payload'] as String) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> enqueueSyncAction(
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    final db = await database;
    await db.insert('pending_sync_queue', {
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PendingSyncItem>> getPendingActions() async {
    final db = await database;
    final rows = await db.query('pending_sync_queue', orderBy: 'id ASC');
    return rows
        .map((r) => PendingSyncItem(
              id: r['id'] as int,
              actionType: r['action_type'] as String,
              payload:
                  jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> clearPendingActions(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'pending_sync_queue',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM pending_sync_queue',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> setLastSyncTimestamp(String timestamp) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {'key': 'lastServerTimestamp', 'value': timestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getLastSyncTimestamp() async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: ['lastServerTimestamp'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> clearAll() async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_lessons');
    batch.delete('cached_news');
    batch.delete('pending_sync_queue');
    batch.delete('sync_metadata');
    await batch.commit(noResult: true);
  }
}

