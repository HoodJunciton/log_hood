import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../core/log_entry.dart';
import '../core/log_level.dart';
import 'log_output.dart';

class DatabaseOutput implements LogOutput {
  static const String _tableName = 'logs';
  static const int _schemaVersion = 1;
  
  final String databaseName;
  final int maxEntries;
  final Duration? cleanupInterval;
  final bool enableIndexing;
  
  Database? _database;
  Timer? _cleanupTimer;

  DatabaseOutput({
    this.databaseName = 'loghood.db',
    this.maxEntries = 100000,
    this.cleanupInterval = const Duration(hours: 1),
    this.enableIndexing = true,
  });

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    _startCleanupTimer();
    return _database!;
  }

  void _startCleanupTimer() {
    if (cleanupInterval != null) {
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(cleanupInterval!, (_) => _cleanup());
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, databaseName);

    return await openDatabase(
      fullPath,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        logger TEXT,
        metadata TEXT,
        stack_trace TEXT,
        error TEXT,
        device_id TEXT,
        user_id TEXT,
        session_id TEXT,
        platform TEXT,
        app_version TEXT,
        build_number TEXT,
        context TEXT,
        tags TEXT,
        thread_name TEXT,
        process_id INTEGER
      )
    ''');

    if (enableIndexing) {
      await db.execute('CREATE INDEX idx_timestamp ON $_tableName (timestamp DESC)');
      await db.execute('CREATE INDEX idx_level ON $_tableName (level)');
      await db.execute('CREATE INDEX idx_logger ON $_tableName (logger)');
      await db.execute('CREATE INDEX idx_user_id ON $_tableName (user_id)');
      await db.execute('CREATE INDEX idx_session_id ON $_tableName (session_id)');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < _schemaVersion) {
      // Add migration logic as needed
    }
  }

  @override
  Future<void> write(LogEntry entry) async {
    final db = await database;
    await db.insert(
      _tableName,
      _entryToMap(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    
    for (final entry in entries) {
      batch.insert(
        _tableName,
        _entryToMap(entry),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _entryToMap(LogEntry entry) {
    return {
      'id': entry.id,
      'timestamp': entry.timestamp.millisecondsSinceEpoch,
      'level': entry.level.name,
      'message': entry.message,
      'logger': entry.logger,
      'metadata': entry.metadata != null ? jsonEncode(entry.metadata) : null,
      'stack_trace': entry.stackTrace,
      'error': entry.error,
      'device_id': entry.deviceId,
      'user_id': entry.userId,
      'session_id': entry.sessionId,
      'platform': entry.platform,
      'app_version': entry.appVersion,
      'build_number': entry.buildNumber,
      'context': entry.context != null ? jsonEncode(entry.context) : null,
      'tags': entry.tags != null ? jsonEncode(entry.tags) : null,
      'thread_name': entry.threadName,
      'process_id': entry.processId,
    };
  }

  LogEntry _mapToEntry(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      level: LogLevel.fromString(map['level']),
      message: map['message'],
      logger: map['logger'],
      metadata: map['metadata'] != null ? jsonDecode(map['metadata']) : null,
      stackTrace: map['stack_trace'],
      error: map['error'],
      deviceId: map['device_id'],
      userId: map['user_id'],
      sessionId: map['session_id'],
      platform: map['platform'],
      appVersion: map['app_version'],
      buildNumber: map['build_number'],
      context: map['context'] != null ? jsonDecode(map['context']) : null,
      tags: map['tags'] != null ? List<String>.from(jsonDecode(map['tags'])) : null,
      threadName: map['thread_name'],
      processId: map['process_id'],
    );
  }

  Future<void> _cleanup() async {
    final db = await database;
    
    // Get count of entries
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName')
    ) ?? 0;

    if (count > maxEntries) {
      // Delete oldest entries
      final toDelete = count - maxEntries;
      await db.execute('''
        DELETE FROM $_tableName 
        WHERE id IN (
          SELECT id FROM $_tableName 
          ORDER BY timestamp ASC 
          LIMIT ?
        )
      ''', [toDelete]);
    }

    // Vacuum to reclaim space
    await db.execute('VACUUM');
  }

  Future<List<LogEntry>> query({
    DateTime? startTime,
    DateTime? endTime,
    List<LogLevel>? levels,
    String? logger,
    String? userId,
    String? sessionId,
    String? searchText,
    List<String>? tags,
    int? limit = 100,
    int? offset = 0,
    bool descending = true,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (startTime != null) {
      conditions.add('timestamp >= ?');
      args.add(startTime.millisecondsSinceEpoch);
    }

    if (endTime != null) {
      conditions.add('timestamp <= ?');
      args.add(endTime.millisecondsSinceEpoch);
    }

    if (levels != null && levels.isNotEmpty) {
      final placeholders = List.filled(levels.length, '?').join(',');
      conditions.add('level IN ($placeholders)');
      args.addAll(levels.map((l) => l.name));
    }

    if (logger != null) {
      conditions.add('logger LIKE ?');
      args.add('%$logger%');
    }

    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }

    if (sessionId != null) {
      conditions.add('session_id = ?');
      args.add(sessionId);
    }

    if (searchText != null && searchText.isNotEmpty) {
      conditions.add('(message LIKE ? OR error LIKE ?)');
      args.add('%$searchText%');
      args.add('%$searchText%');
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final orderBy = descending ? 'timestamp DESC' : 'timestamp ASC';

    final results = await db.rawQuery('''
      SELECT * FROM $_tableName
      $whereClause
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);

    return results.map(_mapToEntry).toList();
  }

  Future<Map<String, int>> getStatistics({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (startTime != null) {
      conditions.add('timestamp >= ?');
      args.add(startTime.millisecondsSinceEpoch);
    }

    if (endTime != null) {
      conditions.add('timestamp <= ?');
      args.add(endTime.millisecondsSinceEpoch);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT level, COUNT(*) as count
      FROM $_tableName
      $whereClause
      GROUP BY level
    ''', args);

    final stats = <String, int>{};
    for (final row in results) {
      stats[row['level'] as String] = row['count'] as int;
    }

    return stats;
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete(_tableName);
  }

  Future<void> deleteOlderThan(Duration age) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(age);
    
    await db.delete(
      _tableName,
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> flush() async {
    // Database writes are immediate
  }

  @override
  Future<void> close() async {
    _cleanupTimer?.cancel();
    await _database?.close();
    _database = null;
  }
}