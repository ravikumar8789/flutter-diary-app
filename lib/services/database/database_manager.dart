import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../error_logging_service.dart';
import '../../models/error_models.dart';

class DatabaseManager {
  static Database? _database;
  static const int _version = 9;
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
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS001',
          severity: ErrorSeverity.critical,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'database_path': join(await getDatabasesPath(), _databaseName),
            'database_version': _version,
            'database_name': _databaseName,
          },
        ),
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
    try {
      if (oldVersion < 2) {
        // Migration from version 1 to 2: Add streaks and habits_daily tables
        await _createStreaksAndHabitsTables(db);
      }
      if (oldVersion < 3) {
        // Migration from version 2 to 3: Add today_* fields to streaks table
        await _addTodayFieldsToStreaks(db);
      }
      if (oldVersion < 4) {
        // Migration from version 3 to 4: Add users and user_settings tables
        await _createUsersAndUserSettingsTables(db);
      }
      if (oldVersion < 5) {
        // Migration from version 4 to 5: Add entity_type, entity_id to sync_queue
        await db.execute(
          "ALTER TABLE sync_queue ADD COLUMN entity_type TEXT DEFAULT 'entry'",
        );
        await db.execute('ALTER TABLE sync_queue ADD COLUMN entity_id TEXT');
        await db.execute(
          "UPDATE sync_queue SET entity_type='entry', entity_id=COALESCE(entry_id,'') WHERE entity_id IS NULL",
        );
      }
      if (oldVersion < 6) {
        await _createUserProfilesTable(db);
      }
      if (oldVersion < 7) {
        await _createYesterdayInsightTable(db);
      }
      if (oldVersion < 8) {
        await _createEntryInsightsLocalTable(db);
      }
      if (oldVersion < 9) {
        await _createCleanupTrigger(db);
      }
    } catch (e) {
      await ErrorLoggingService.logCriticalError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS003',
          severity: ErrorSeverity.critical,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'old_version': oldVersion,
            'new_version': newVersion,
          },
        ),
      );
      rethrow;
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
        entry_id TEXT,
        entity_type TEXT NOT NULL DEFAULT 'entry',
        entity_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Streaks table (local cache)
    await db.execute('''
      CREATE TABLE streaks (
        user_id TEXT PRIMARY KEY,
        current INTEGER DEFAULT 0,
        longest INTEGER DEFAULT 0,
        last_entry_date TEXT,
        freeze_credits INTEGER DEFAULT 0,
        grace_pieces_total REAL DEFAULT 0.0,
        today_date TEXT,
        today_diary INTEGER DEFAULT 0,
        today_affirmations INTEGER DEFAULT 0,
        today_gratitude INTEGER DEFAULT 0,
        today_self_care_count INTEGER DEFAULT 0,
        today_grace_pieces REAL DEFAULT 0.0,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        last_sync_at TEXT
      )
    ''');

    // Habits daily table (local cache)
    await db.execute('''
      CREATE TABLE habits_daily (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        wrote_entry INTEGER DEFAULT 0,
        filled_affirmations INTEGER DEFAULT 0,
        filled_gratitude INTEGER DEFAULT 0,
        self_care_completed_count INTEGER DEFAULT 0,
        grace_pieces_earned REAL DEFAULT 0.0,
        is_synced INTEGER DEFAULT 0,
        last_sync_at TEXT,
        UNIQUE(user_id, date)
      )
    ''');

    // Users table (local cache for user profile)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT,
        email_verified INTEGER DEFAULT 0,
        display_name TEXT,
        avatar_url TEXT,
        locale TEXT,
        timezone TEXT,
        marketing_opt_in INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        last_sync_at TEXT
      )
    ''');

    // User settings table (local cache)
    await db.execute('''
      CREATE TABLE user_settings (
        user_id TEXT PRIMARY KEY,
        reminder_enabled INTEGER DEFAULT 1,
        reminder_time_local TEXT,
        reminder_days TEXT DEFAULT '[1,2,3,4,5,6,7]',
        grace_system_enabled INTEGER DEFAULT 1,
        privacy_lock_enabled INTEGER DEFAULT 0,
        region_preference TEXT,
        export_format_default TEXT DEFAULT 'json',
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        last_sync_at TEXT
      )
    ''');

    // User profiles table (theme, font - local cache)
    await db.execute('''
      CREATE TABLE user_profiles (
        user_id TEXT PRIMARY KEY,
        theme_preference TEXT DEFAULT 'system',
        diary_font TEXT,
        font_size INTEGER,
        paper_style TEXT DEFAULT 'ruled',
        is_synced INTEGER DEFAULT 0,
        last_sync_at TEXT
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
    await db.execute(
      'CREATE INDEX idx_streaks_user ON streaks(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_habits_user_date ON habits_daily(user_id, date)',
    );
    await db.execute('CREATE INDEX idx_users_id ON users(id)');
    await db.execute(
      'CREATE INDEX idx_user_settings_user_id ON user_settings(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id)',
    );

    // Yesterday insight (single row per user, overwrite on fetch)
    await db.execute('''
      CREATE TABLE yesterday_insight (
        user_id TEXT PRIMARY KEY,
        id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        summary TEXT,
        insight_text TEXT,
        insight_details TEXT,
        sentiment_label TEXT,
        processed_at TEXT NOT NULL
      )
    ''');

    // Entry insights local (60-day cache for History screen)
    await db.execute('''
      CREATE TABLE entry_insights_local (
        entry_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        id TEXT NOT NULL,
        summary TEXT,
        insight_text TEXT,
        insight_details TEXT,
        sentiment_label TEXT,
        topics TEXT,
        processed_at TEXT NOT NULL
      )
    ''');

    await _createCleanupTrigger(db);
  }

  // Helper method to create cleanup trigger (60-day FILO retention)
  Future<void> _createCleanupTrigger(Database db) async {
    await db.execute('DROP TRIGGER IF EXISTS cleanup_old_entries_after_insert');
    await db.execute('''
      CREATE TRIGGER cleanup_old_entries_after_insert
      AFTER INSERT ON entries
      BEGIN
        DELETE FROM entry_affirmations
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_priorities
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_meals
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_gratitude
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_self_care
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_shower_bath
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_tomorrow_notes
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM sync_queue
        WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
        DELETE FROM entry_insights_local
        WHERE entry_date < date('now', 'localtime', '-60 days');
        DELETE FROM entries
        WHERE entry_date < date('now', 'localtime', '-60 days');
      END;
    ''');
  }

  // Helper method to create entry_insights_local table (migration v7 to v8)
  Future<void> _createEntryInsightsLocalTable(Database db) async {
    final exists = await _tableExists(db, 'entry_insights_local');
    if (!exists) {
      await db.execute('''
        CREATE TABLE entry_insights_local (
          entry_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          entry_date TEXT NOT NULL,
          id TEXT NOT NULL,
          summary TEXT,
          insight_text TEXT,
          insight_details TEXT,
          sentiment_label TEXT,
          topics TEXT,
          processed_at TEXT NOT NULL
        )
      ''');
    }
  }

  // Helper method to create yesterday_insight table (migration v6 to v7)
  Future<void> _createYesterdayInsightTable(Database db) async {
    final exists = await _tableExists(db, 'yesterday_insight');
    if (!exists) {
      await db.execute('''
        CREATE TABLE yesterday_insight (
          user_id TEXT PRIMARY KEY,
          id TEXT NOT NULL,
          entry_id TEXT NOT NULL,
          entry_date TEXT NOT NULL,
          summary TEXT,
          insight_text TEXT,
          insight_details TEXT,
          sentiment_label TEXT,
          processed_at TEXT NOT NULL
        )
      ''');
    }
  }

  // Helper method to create streaks and habits tables (for migration)
  Future<void> _createStreaksAndHabitsTables(Database db) async {
    // Check if tables already exist before creating
    final streaksExists = await _tableExists(db, 'streaks');
    final habitsExists = await _tableExists(db, 'habits_daily');

    if (!streaksExists) {
      await db.execute('''
        CREATE TABLE streaks (
          user_id TEXT PRIMARY KEY,
          current INTEGER DEFAULT 0,
          longest INTEGER DEFAULT 0,
          last_entry_date TEXT,
          freeze_credits INTEGER DEFAULT 0,
          grace_pieces_total REAL DEFAULT 0.0,
          updated_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          last_sync_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_streaks_user ON streaks(user_id)',
      );
    }

    if (!habitsExists) {
      await db.execute('''
        CREATE TABLE habits_daily (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          date TEXT NOT NULL,
          wrote_entry INTEGER DEFAULT 0,
          filled_affirmations INTEGER DEFAULT 0,
          filled_gratitude INTEGER DEFAULT 0,
          self_care_completed_count INTEGER DEFAULT 0,
          grace_pieces_earned REAL DEFAULT 0.0,
          is_synced INTEGER DEFAULT 0,
          last_sync_at TEXT,
          UNIQUE(user_id, date)
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_habits_user_date ON habits_daily(user_id, date)',
      );
    }
  }

  // Helper method to add today_* fields to streaks table (migration v2 to v3)
  Future<void> _addTodayFieldsToStreaks(Database db) async {
    try {
      // Add new columns if they don't exist
      await db.execute('ALTER TABLE streaks ADD COLUMN today_date TEXT');
    } catch (e) {
      // Column might already exist, ignore error
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }

    try {
      await db.execute('ALTER TABLE streaks ADD COLUMN today_diary INTEGER DEFAULT 0');
    } catch (e) {
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }

    try {
      await db.execute('ALTER TABLE streaks ADD COLUMN today_affirmations INTEGER DEFAULT 0');
    } catch (e) {
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }

    try {
      await db.execute('ALTER TABLE streaks ADD COLUMN today_gratitude INTEGER DEFAULT 0');
    } catch (e) {
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }

    try {
      await db.execute('ALTER TABLE streaks ADD COLUMN today_self_care_count INTEGER DEFAULT 0');
    } catch (e) {
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }

    try {
      await db.execute('ALTER TABLE streaks ADD COLUMN today_grace_pieces REAL DEFAULT 0.0');
    } catch (e) {
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }
  }

  // Helper method to create user_profiles table (migration v5 to v6)
  Future<void> _createUserProfilesTable(Database db) async {
    final exists = await _tableExists(db, 'user_profiles');
    if (!exists) {
      await db.execute('''
        CREATE TABLE user_profiles (
          user_id TEXT PRIMARY KEY,
          theme_preference TEXT DEFAULT 'system',
          diary_font TEXT,
          font_size INTEGER,
          paper_style TEXT DEFAULT 'ruled',
          is_synced INTEGER DEFAULT 0,
          last_sync_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id)',
      );
    }
  }

  // Helper method to create users and user_settings tables (migration v3 to v4)
  Future<void> _createUsersAndUserSettingsTables(Database db) async {
    final usersExists = await _tableExists(db, 'users');
    final userSettingsExists = await _tableExists(db, 'user_settings');

    if (!usersExists) {
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          email TEXT,
          email_verified INTEGER DEFAULT 0,
          display_name TEXT,
          avatar_url TEXT,
          locale TEXT,
          timezone TEXT,
          marketing_opt_in INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          last_sync_at TEXT
        )
      ''');
      await db.execute('CREATE INDEX idx_users_id ON users(id)');
    }

    if (!userSettingsExists) {
      await db.execute('''
        CREATE TABLE user_settings (
          user_id TEXT PRIMARY KEY,
          reminder_enabled INTEGER DEFAULT 1,
          reminder_time_local TEXT,
          reminder_days TEXT DEFAULT '[1,2,3,4,5,6,7]',
          grace_system_enabled INTEGER DEFAULT 1,
          privacy_lock_enabled INTEGER DEFAULT 0,
          region_preference TEXT,
          export_format_default TEXT DEFAULT 'json',
          updated_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          last_sync_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_user_settings_user_id ON user_settings(user_id)',
      );
    }
  }

  // Helper method to check if table exists
  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
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
    await db.delete('habits_daily');
    await db.delete('streaks');
    await db.delete('user_profiles');
    await db.delete('user_settings');
    await db.delete('users');
    await db.delete('yesterday_insight');
  }

  // Clean up old entries (60-day retention policy)
  Future<void> clearOldEntries({int retentionDays = 60}) async {
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
      await db.delete(
        'entries',
        where: 'entry_date < ?',
        whereArgs: [cutoffDateStr],
      );
    }
  }
}
