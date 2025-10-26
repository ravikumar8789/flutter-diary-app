import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../error_logging_service.dart';

class DatabaseManager {
  static Database? _database;
  static const int _version = 1;
  static const String _databaseName = 'diary_app.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);

      return await openDatabase(
        path,
        version: _version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      // Log error to Supabase
      await ErrorLoggingService.logCriticalError(
        errorCode: 'ERRSYS001',
        errorMessage: 'Database initialization failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'database_path': join(await getDatabasesPath(), _databaseName),
          'database_version': _version,
          'database_name': _databaseName,
        },
      );

      throw Exception('Database initialization failed (ERRSYS001): $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await _createTables(db);
    } catch (e) {
      // Log error with code ERRSYS002
      throw Exception('Table creation failed (ERRSYS002): $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    // For now, we'll recreate tables if needed
    if (oldVersion < newVersion) {
      await _createTables(db);
    }
  }

  Future<void> _createTables(Database db) async {
    // Main entries table
    await db.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        diary_text TEXT,
        mood_score INTEGER CHECK (mood_score >= 1 AND mood_score <= 5),
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        last_sync_at TEXT
      )
    ''');

    // Entry affirmations (JSONB format)
    await db.execute('''
      CREATE TABLE entry_affirmations (
        entry_id TEXT PRIMARY KEY,
        affirmations TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Entry priorities (JSONB format)
    await db.execute('''
      CREATE TABLE entry_priorities (
        entry_id TEXT PRIMARY KEY,
        priorities TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Entry meals
    await db.execute('''
      CREATE TABLE entry_meals (
        entry_id TEXT PRIMARY KEY,
        breakfast TEXT,
        lunch TEXT,
        dinner TEXT,
        water_cups INTEGER DEFAULT 0 CHECK (water_cups >= 0 AND water_cups <= 8),
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Entry gratitude (JSONB format)
    await db.execute('''
      CREATE TABLE entry_gratitude (
        entry_id TEXT PRIMARY KEY,
        grateful_items TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Entry self care
    await db.execute('''
      CREATE TABLE entry_self_care (
        entry_id TEXT PRIMARY KEY,
        sleep INTEGER DEFAULT 0,
        get_up_early INTEGER DEFAULT 0,
        fresh_air INTEGER DEFAULT 0,
        learn_new INTEGER DEFAULT 0,
        balanced_diet INTEGER DEFAULT 0,
        podcast INTEGER DEFAULT 0,
        me_moment INTEGER DEFAULT 0,
        hydrated INTEGER DEFAULT 0,
        read_book INTEGER DEFAULT 0,
        exercise INTEGER DEFAULT 0,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Entry shower/bath
    await db.execute('''
      CREATE TABLE entry_shower_bath (
        entry_id TEXT PRIMARY KEY,
        took_shower INTEGER DEFAULT 0,
        note TEXT,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Entry tomorrow notes (JSONB format)
    await db.execute('''
      CREATE TABLE entry_tomorrow_notes (
        entry_id TEXT PRIMARY KEY,
        tomorrow_notes TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');

    // Sync queue for offline changes
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Create indexes for performance
    await db.execute(
      'CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date)',
    );
    await db.execute(
      'CREATE INDEX idx_entries_sync ON entries(is_synced, updated_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_entry ON sync_queue(entry_id, created_at)',
    );
  }

  // Helper method to close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Helper method to clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('sync_queue');
    await db.delete('entry_tomorrow_notes');
    await db.delete('entry_shower_bath');
    await db.delete('entry_self_care');
    await db.delete('entry_gratitude');
    await db.delete('entry_meals');
    await db.delete('entry_priorities');
    await db.delete('entry_affirmations');
    await db.delete('entries');
  }

  // Clean up old entries (7-day retention policy)
  Future<void> clearOldEntries({int retentionDays = 7}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    final cutoffDateStr = cutoffDate.toIso8601String().split(
      'T',
    )[0]; // Format as YYYY-MM-DD

    // Get entries to delete
    final entriesToDelete = await db.query(
      'entries',
      columns: ['id'],
      where: 'entry_date < ?',
      whereArgs: [cutoffDateStr],
    );

    if (entriesToDelete.isNotEmpty) {
      final entryIds = entriesToDelete.map((e) => e['id'] as String).toList();

      // Delete related data first (foreign key constraints)
      for (final entryId in entryIds) {
        await db.delete(
          'entry_affirmations',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'entry_priorities',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'entry_meals',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'entry_gratitude',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'entry_self_care',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'entry_shower_bath',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'entry_tomorrow_notes',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
        await db.delete(
          'sync_queue',
          where: 'entry_id = ?',
          whereArgs: [entryId],
        );
      }

      // Delete main entries
      final deletedCount = await db.delete(
        'entries',
        where: 'entry_date < ?',
        whereArgs: [cutoffDateStr],
      );
    }
  }
}
