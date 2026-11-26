import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../features/learning/models/lesson_models.dart';
import '../../features/watch/models/news_models.dart';
import 'web_kv_store.dart';

class PendingSyncItem {
  final int id;
  final String actionType;
  final Map<String, dynamic> payload;

  PendingSyncItem({
    required this.id,
    required this.actionType,
    required this.payload,
  });

  factory PendingSyncItem.fromJson(Map<String, dynamic> json) {
    return PendingSyncItem(
      id: json['id'] as int,
      actionType: json['actionType'] as String,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'payload': payload,
      };
}

class LocalDatabase {
  static const _dbName = 'dailystack_offline.db';
  static const _dbVersion = 1;

  static const _webLessonsKey = 'dailystack_lessons_v1';
  static const _webNewsKey = 'dailystack_news_v1';
  static const _webPendingKey = 'dailystack_pending_v1';
  static const _webMetaPrefix = 'dailystack_meta_';

  Database? _db;
  final WebKvStore _webStore = WebKvStore();

  Map<String, dynamic> _readWebMap(String storageKey) {
    final raw = _webStore.read(storageKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  List<PendingSyncItem> _readWebPendingQueue() {
    final raw = _webStore.read(_webPendingKey);
    if (raw == null || raw.isEmpty) return <PendingSyncItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => PendingSyncItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      }
    } catch (_) {}
    return <PendingSyncItem>[];
  }

  void _writeWebPendingQueue(List<PendingSyncItem> items) {
    _webStore.write(
      _webPendingKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

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
    if (lessons.isEmpty) return;
    if (kIsWeb) {
      final map = _readWebMap(_webLessonsKey);
      for (final lesson in lessons) {
        map[lesson.id.toString()] = lesson.toJson();
      }
      _webStore.write(_webLessonsKey, jsonEncode(map));
      return;
    }
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
    if (kIsWeb) {
      final map = _readWebMap(_webLessonsKey);
      final raw = map[lessonId.toString()];
      if (raw == null) return null;
      try {
        if (raw is Map) {
          return LessonDetail.fromJson(Map<String, dynamic>.from(raw));
        }
        if (raw is String) {
          return LessonDetail.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
        }
      } catch (_) {}
      return null;
    }
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
    if (news.isEmpty) return;
    if (kIsWeb) {
      final map = _readWebMap(_webNewsKey);
      for (final item in news) {
        map[item.id.toString()] = item.toJson();
      }
      _webStore.write(_webNewsKey, jsonEncode(map));
      return;
    }
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
    if (kIsWeb) {
      final map = _readWebMap(_webNewsKey);
      final entries = <TechNewsSummary>[];
      for (final val in map.values) {
        try {
          if (val is Map) {
            entries.add(
              TechNewsSummary.fromJson(Map<String, dynamic>.from(val)),
            );
          } else if (val is String) {
            entries.add(
              TechNewsSummary.fromJson(
                jsonDecode(val) as Map<String, dynamic>,
              ),
            );
          }
        } catch (_) {}
      }
      entries.sort((a, b) => b.id.compareTo(a.id));
      return entries;
    }
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
    if (kIsWeb) {
      final queue = _readWebPendingQueue();
      final nextId = queue.isEmpty
          ? 1
          : (queue.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
      queue.add(
        PendingSyncItem(
          id: nextId,
          actionType: actionType,
          payload: Map<String, dynamic>.from(payload),
        ),
      );
      _writeWebPendingQueue(queue);
      return;
    }
    final db = await database;
    await db.insert('pending_sync_queue', {
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PendingSyncItem>> getPendingActions() async {
    if (kIsWeb) {
      return _readWebPendingQueue();
    }
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
    if (kIsWeb) {
      final idSet = ids.toSet();
      final queue = _readWebPendingQueue()
        ..removeWhere((item) => idSet.contains(item.id));
      _writeWebPendingQueue(queue);
      return;
    }
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'pending_sync_queue',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> getPendingCount() async {
    if (kIsWeb) return _readWebPendingQueue().length;
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM pending_sync_queue',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> setLastSyncTimestamp(String timestamp) async {
    await setMetadata('lastServerTimestamp', timestamp);
  }

  Future<String?> getLastSyncTimestamp() async {
    return getMetadata('lastServerTimestamp');
  }

  Future<void> setMetadata(String key, String value) async {
    if (kIsWeb) {
      _webStore.write('$_webMetaPrefix$key', value);
      return;
    }
    final db = await database;
    await db.insert(
      'sync_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMetadata(String key) async {
    if (kIsWeb) return _webStore.read('$_webMetaPrefix$key');
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
    if (kIsWeb) {
      _webStore.clearAll();
      return;
    }
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_lessons');
    batch.delete('cached_news');
    batch.delete('pending_sync_queue');
    batch.delete('sync_metadata');
    await batch.commit(noResult: true);
  }
}
