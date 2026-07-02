import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/models/usage_session.dart';

abstract class FocusTraceLocalDataSource {
  Future<void> insertSession(UsageSession session);

  Future<void> insertSessions(List<UsageSession> sessions);

  Future<List<UsageSession>> getSessionsForDate(DateTime date);

  Future<String?> readSetting(String key);

  Future<void> writeSetting(String key, String value);

  Future<void> clearAllData();
}

class SqfliteFocusTraceLocalDataSource implements FocusTraceLocalDataSource {
  SqfliteFocusTraceLocalDataSource({
    this.databaseName = 'focus_trace.db',
    DatabaseFactory? databaseFactoryOverride,
    Future<Directory> Function()? applicationSupportDirectoryProvider,
  }) : _databaseFactoryOverride = databaseFactoryOverride,
       _applicationSupportDirectoryProvider =
           applicationSupportDirectoryProvider;

  final String databaseName;
  final DatabaseFactory? _databaseFactoryOverride;
  final Future<Directory> Function()? _applicationSupportDirectoryProvider;
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final factory = await _databaseFactory;
    final path = await _databasePath();

    final opened = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE usage_sessions (
  id TEXT PRIMARY KEY,
  platform TEXT NOT NULL,
  app_name TEXT NOT NULL,
  package_name TEXT,
  process_name TEXT,
  window_title TEXT,
  started_at INTEGER NOT NULL,
  ended_at INTEGER,
  duration_seconds INTEGER NOT NULL,
  category TEXT,
  created_at INTEGER NOT NULL
)
''');
          await db.execute('''
CREATE INDEX idx_usage_sessions_started_at
ON usage_sessions(started_at)
''');
          await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
        },
      ),
    );

    _database = opened;
    return opened;
  }

  Future<DatabaseFactory> get _databaseFactory async {
    final override = _databaseFactoryOverride;
    if (override != null) {
      return override;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }

    return databaseFactory;
  }

  Future<String> _databasePath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final provider =
          _applicationSupportDirectoryProvider ??
          getApplicationSupportDirectory;
      final directory = await provider();
      await directory.create(recursive: true);
      return p.join(directory.path, databaseName);
    }

    return p.join(await getDatabasesPath(), databaseName);
  }

  @override
  Future<void> insertSession(UsageSession session) async {
    final db = await _db;
    await db.insert(
      'usage_sessions',
      _sessionToRow(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertSessions(List<UsageSession> sessions) async {
    if (sessions.isEmpty) {
      return;
    }

    final db = await _db;
    await db.transaction((txn) async {
      for (final session in sessions) {
        await txn.insert(
          'usage_sessions',
          _sessionToRow(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<UsageSession>> getSessionsForDate(DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final db = await _db;
    final rows = await db.query(
      'usage_sessions',
      where: 'started_at < ? AND (ended_at IS NULL OR ended_at > ?)',
      whereArgs: [to.millisecondsSinceEpoch, from.millisecondsSinceEpoch],
      orderBy: 'started_at ASC',
    );
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<String?> readSetting(String key) async {
    final db = await _db;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    final db = await _db;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearAllData() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('usage_sessions');
      await txn.delete('settings');
    });
  }

  Map<String, Object?> _sessionToRow(UsageSession session) {
    return {
      'id': session.id,
      'platform': session.platform.name,
      'app_name': session.appName,
      'package_name': session.packageName,
      'process_name': session.processName,
      'window_title': session.windowTitle,
      'started_at': session.startedAt.millisecondsSinceEpoch,
      'ended_at': session.endedAt?.millisecondsSinceEpoch,
      'duration_seconds': session.durationSeconds,
      'category': session.category,
      'created_at': session.createdAt.millisecondsSinceEpoch,
    };
  }

  UsageSession _sessionFromRow(Map<String, Object?> row) {
    return UsageSession(
      id: row['id'] as String,
      platform: UsagePlatform.fromName(row['platform'] as String?),
      appName: row['app_name'] as String,
      packageName: row['package_name'] as String?,
      processName: row['process_name'] as String?,
      windowTitle: row['window_title'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      durationSeconds: row['duration_seconds'] as int,
      category: row['category'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}
