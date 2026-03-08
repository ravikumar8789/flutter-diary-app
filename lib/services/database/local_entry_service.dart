import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../database/database_manager.dart';
import '../../models/entry_models.dart';
import '../error_logging_service.dart';
import '../../models/error_models.dart';

class LocalEntryService {
  final DatabaseManager _dbManager = DatabaseManager();

  // Fetch today's entry (or any date)
  // Use local date as-is (entry_date is stored as date only, no time)
  Future<Entry?> getEntryByDate(String userId, DateTime date) async {
    final db = await _dbManager.database;
    // Use date as-is (local date from device)
    final dateOnly = DateTime(date.year, date.month, date.day);
    final dateStr = DateFormat('yyyy-MM-dd').format(dateOnly);

    final results = await db.query(
      'entries',
      where: 'user_id = ? AND entry_date = ?',
      whereArgs: [userId, dateStr],
    );

    if (results.isEmpty) return null;
    return Entry.fromJson(results.first);
  }

  // Fetch entry by id (for sync)
  Future<Entry?> getEntryById(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [entryId],
    );
    if (results.isEmpty) return null;
    return Entry.fromJson(results.first);
  }

  /// Load entry + affirmations, priorities, meals, gratitude, self_care, shower_bath, tomorrow_notes for sync
  Future<({
    Entry entry,
    EntryAffirmations? affirmations,
    EntryPriorities? priorities,
    EntryMeals? meals,
    EntryGratitude? gratitude,
    EntrySelfCare? selfCare,
    EntryShowerBath? showerBath,
    EntryTomorrowNotes? tomorrowNotes,
  })?> getFullEntryForSync(String entryId) async {
    final entry = await getEntryById(entryId);
    if (entry == null) return null;
    return (
      entry: entry,
      affirmations: await getAffirmations(entryId),
      priorities: await getPriorities(entryId),
      meals: await getMeals(entryId),
      gratitude: await getGratitude(entryId),
      selfCare: await getSelfCare(entryId),
      showerBath: await getShowerBath(entryId),
      tomorrowNotes: await getTomorrowNotes(entryId),
    );
  }

  // Upsert entry (insert or update)
  Future<void> upsertEntry(Entry entry) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entries',
        entry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Add to sync queue
      await _addToSyncQueue(entry.id, 'entries', 'upsert', entry.toJson());
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB010',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': entry.id,
          'user_id': entry.userId,
          'entry_date': entry.entryDate.toIso8601String(),
          'operation': 'upsert_entry_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert affirmations
  Future<void> upsertAffirmations(EntryAffirmations affirmations) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_affirmations',
        affirmations.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        affirmations.entryId,
        'entry_affirmations',
        'upsert',
        affirmations.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB011',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': affirmations.entryId,
          'affirmations_count': affirmations.affirmations.length,
          'operation': 'upsert_affirmations_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert priorities
  Future<void> upsertPriorities(EntryPriorities priorities) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_priorities',
        priorities.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        priorities.entryId,
        'entry_priorities',
        'upsert',
        priorities.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB012',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': priorities.entryId,
          'priorities_count': priorities.priorities.length,
          'operation': 'upsert_priorities_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert meals
  Future<void> upsertMeals(EntryMeals meals) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_meals',
        meals.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        meals.entryId,
        'entry_meals',
        'upsert',
        meals.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB013',
        severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': meals.entryId,
          'water_cups': meals.waterCups,
          'has_breakfast': meals.breakfast != null,
          'has_lunch': meals.lunch != null,
          'has_dinner': meals.dinner != null,
          'operation': 'upsert_meals_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert gratitude
  Future<void> upsertGratitude(EntryGratitude gratitude) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_gratitude',
        gratitude.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        gratitude.entryId,
        'entry_gratitude',
        'upsert',
        gratitude.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB014',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': gratitude.entryId,
          'grateful_items_count': gratitude.gratefulItems.length,
          'operation': 'upsert_gratitude_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert self care
  Future<void> upsertSelfCare(EntrySelfCare selfCare) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_self_care',
        selfCare.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        selfCare.entryId,
        'entry_self_care',
        'upsert',
        selfCare.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB015',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': selfCare.entryId,
          'self_care_data': {
            'sleep': selfCare.sleep,
            'get_up_early': selfCare.getUpEarly,
            'fresh_air': selfCare.freshAir,
            'learn_new': selfCare.learnNew,
            'balanced_diet': selfCare.balancedDiet,
            'podcast': selfCare.podcast,
            'me_moment': selfCare.meMoment,
            'hydrated': selfCare.hydrated,
            'read_book': selfCare.readBook,
            'exercise': selfCare.exercise,
          },
          'operation': 'upsert_self_care_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert shower bath
  Future<void> upsertShowerBath(EntryShowerBath showerBath) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_shower_bath',
        showerBath.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        showerBath.entryId,
        'entry_shower_bath',
        'upsert',
        showerBath.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB016',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': showerBath.entryId,
          'took_shower': showerBath.tookShower,
          'has_note': showerBath.note != null,
          'operation': 'upsert_shower_bath_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Upsert tomorrow notes
  Future<void> upsertTomorrowNotes(EntryTomorrowNotes tomorrowNotes) async {
    try {
      final db = await _dbManager.database;
      await db.insert(
        'entry_tomorrow_notes',
        tomorrowNotes.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _addToSyncQueue(
        tomorrowNotes.entryId,
        'entry_tomorrow_notes',
        'upsert',
        tomorrowNotes.toJson(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB017',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': tomorrowNotes.entryId,
          'tomorrow_notes_count': tomorrowNotes.tomorrowNotes.length,
          'operation': 'upsert_tomorrow_notes_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Get affirmations for entry
  Future<EntryAffirmations?> getAffirmations(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_affirmations',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntryAffirmations.fromJson(results.first);
  }

  // Get priorities for entry
  Future<EntryPriorities?> getPriorities(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_priorities',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntryPriorities.fromJson(results.first);
  }

  // Get meals for entry
  Future<EntryMeals?> getMeals(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_meals',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntryMeals.fromJson(results.first);
  }

  // Get gratitude for entry
  Future<EntryGratitude?> getGratitude(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_gratitude',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntryGratitude.fromJson(results.first);
  }

  // Get self care for entry
  Future<EntrySelfCare?> getSelfCare(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_self_care',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntrySelfCare.fromJson(results.first);
  }

  // Get shower bath for entry
  Future<EntryShowerBath?> getShowerBath(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_shower_bath',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntryShowerBath.fromJson(results.first);
  }

  // Get tomorrow notes for entry
  Future<EntryTomorrowNotes?> getTomorrowNotes(String entryId) async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entry_tomorrow_notes',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );

    if (results.isEmpty) return null;
    return EntryTomorrowNotes.fromJson(results.first);
  }

  // Get all entries from a date range
  Future<List<Entry>> getEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbManager.database;
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    final results = await db.query(
      'entries',
      where: 'user_id = ? AND entry_date BETWEEN ? AND ?',
      whereArgs: [userId, startStr, endStr],
      orderBy: 'entry_date DESC',
    );

    return results.map((json) => Entry.fromJson(json)).toList();
  }

  /// Get mood map for date range (lightweight query - only date + mood)
  /// Used for calendar view to show mood indicators without loading full entries
  Future<Map<String, int>> getMoodMapForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbManager.database;
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      final endStr = DateFormat('yyyy-MM-dd').format(end);

      // Query only entry_date and mood_score columns (lightweight)
      final results = await db.query(
        'entries',
        columns: ['entry_date', 'mood_score'],
        where: 'user_id = ? AND entry_date BETWEEN ? AND ?',
        whereArgs: [userId, startStr, endStr],
      );

      final moodMap = <String, int>{};
      for (var row in results) {
        final dateStr = row['entry_date'] as String;
        // Default mood to 3 if NULL (consistent with card display)
        final moodScore = row['mood_score'] as int? ?? 3;
        moodMap[dateStr] = moodScore;
      }

      return moodMap;
    } catch (e) {
      // Return empty map on error (graceful degradation)
      return {};
    }
  }

  /// Get distinct months that have entries (for Load More button)
  /// Returns list of month keys (e.g., ["2024-01", "2024-02"]) sorted oldest first
  Future<List<String>> getMonthsWithEntries(String userId) async {
    try {
      final db = await _dbManager.database;

      // Query distinct months using SQLite date functions
      final results = await db.rawQuery('''
        SELECT DISTINCT 
          strftime('%Y-%m', entry_date) as month_key
        FROM entries
        WHERE user_id = ?
        ORDER BY month_key ASC
      ''', [userId]);

      return results
          .map((row) => row['month_key'] as String?)
          .whereType<String>()
          .toList();
    } catch (e) {
      // Return empty list on error (graceful degradation)
      return [];
    }
  }

  // Mark entry as synced
  Future<void> markAsSynced(String entryId) async {
    try {
      final db = await _dbManager.database;
      await db.update(
        'entries',
        {'is_synced': 1, 'last_sync_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [entryId],
      );
      // Remove redundant sync_queue rows for this entry (SyncWorker uses entries.is_synced)
      await db.delete('sync_queue', where: 'entry_id = ?', whereArgs: [entryId]);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRDB018',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': entryId,
          'operation': 'mark_as_synced_local',
        },
        ),
      );
      rethrow;
    }
  }

  // Get sync queue
  Future<List<SyncQueueItem>> getSyncQueue() async {
    final db = await _dbManager.database;
    final results = await db.query('sync_queue', orderBy: 'created_at ASC');

    return results.map((json) => SyncQueueItem.fromJson(json)).toList();
  }

  /// Get sync queue items for streak, user_profile, user_settings (non-entry entities)
  Future<List<SyncQueueItem>> getSyncQueueForEntityTypes(
    List<String> entityTypes,
  ) async {
    if (entityTypes.isEmpty) return [];
    final db = await _dbManager.database;
    final placeholders = entityTypes.map((_) => '?').join(',');
    final results = await db.query(
      'sync_queue',
      where: 'entity_type IN ($placeholders)',
      whereArgs: entityTypes,
      orderBy: 'created_at ASC',
    );
    return results.map((json) => SyncQueueItem.fromJson(json)).toList();
  }

  /// Get sync queue items by entity types with retry filter (retry_count < 10)
  Future<List<SyncQueueItem>> getSyncQueueByEntityTypes(
    List<String> entityTypes,
  ) async {
    if (entityTypes.isEmpty) return [];
    final db = await _dbManager.database;
    final placeholders = entityTypes.map((_) => '?').join(',');
    final results = await db.query(
      'sync_queue',
      where:
          'entity_type IN ($placeholders) AND (retry_count IS NULL OR retry_count < 10)',
      whereArgs: entityTypes,
      orderBy: 'created_at ASC',
    );
    return results.map((json) => SyncQueueItem.fromJson(json)).toList();
  }

  /// Check if sync queue has items for given entity types (retry_count < 10)
  Future<bool> hasSyncQueueItems(List<String> entityTypes) async {
    if (entityTypes.isEmpty) return false;
    final db = await _dbManager.database;
    final placeholders = entityTypes.map((_) => '?').join(',');
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sync_queue WHERE entity_type IN ($placeholders) AND (retry_count IS NULL OR retry_count < 10)',
      entityTypes,
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  /// Add streak to sync queue when local streaks row has is_synced=0.
  /// Dedupes: removes existing pending streak for same user before adding.
  static Future<void> addStreakToSyncQueue(String userId) async {
    final db = await DatabaseManager().database;
    final streak = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (streak.isEmpty) return;
    final row = streak.first;
    if ((row['is_synced'] as int? ?? 1) == 1) return;

    final localService = LocalEntryService();
    await db.delete(
      'sync_queue',
      where: "entity_type = 'streak' AND entity_id = ?",
      whereArgs: [userId],
    );
    final rowMap = Map<String, dynamic>.from(row);
    await localService.addToSyncQueue(
      entityType: 'streak',
      entityId: userId,
      tableName: 'streaks',
      operation: 'upsert',
      data: rowMap,
    );
  }

  // Remove sync queue item
  Future<void> removeSyncQueueItem(int id) async {
    final db = await _dbManager.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // Increment retry count
  Future<void> incrementRetryCount(int id) async {
    final db = await _dbManager.database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  // Mark sync item as failed
  Future<void> markSyncItemFailed(int id) async {
    final db = await _dbManager.database;
    await db.update(
      'sync_queue',
      {'retry_count': 999}, // Mark as failed
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Add to sync queue (entry-centric, calls generic addToSyncQueue)
  Future<void> _addToSyncQueue(
    String entryId,
    String tableName,
    String operation,
    Map<String, dynamic> data,
  ) async {
    await addToSyncQueue(
      entityType: 'entry',
      entityId: entryId,
      tableName: tableName,
      operation: operation,
      data: data,
      entryId: entryId,
    );
  }

  /// Add to sync queue (generic, supports entry, streak, user_profile, user_settings)
  Future<void> addToSyncQueue({
    required String entityType,
    required String entityId,
    required String tableName,
    required String operation,
    required Map<String, dynamic> data,
    String? entryId,
  }) async {
    final db = await _dbManager.database;
    await db.insert('sync_queue', {
      'entry_id': entityType == 'entry' ? entityId : (entryId ?? ''),
      'entity_type': entityType,
      'entity_id': entityId,
      'table_name': tableName,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  // Clean up old entries (60-day retention policy)
  Future<void> clearOldEntries({int retentionDays = 60}) async {
    await _dbManager.clearOldEntries(retentionDays: retentionDays);
  }

  // Check if there are unsynced entries (smart sync optimization)
  Future<bool> hasUnsyncedEntries() async {
    final db = await _dbManager.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM entries WHERE is_synced = 0',
    );
    final count = (result.first['count'] as int?) ?? 0;
    return count > 0;
  }

  // Get all unsynced entries for sync processing
  Future<List<Entry>> getUnsyncedEntries() async {
    final db = await _dbManager.database;
    final results = await db.query(
      'entries',
      where: 'is_synced = 0',
      orderBy: 'updated_at ASC',
    );
    return results.map((json) => Entry.fromJson(json)).toList();
  }
}

// Sync queue item model
class SyncQueueItem {
  final int id;
  final String? entryId;
  final String entityType;
  final String entityId;
  final String tableName;
  final String operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  SyncQueueItem({
    required this.id,
    this.entryId,
    required this.entityType,
    required this.entityId,
    required this.tableName,
    required this.operation,
    required this.data,
    required this.createdAt,
    required this.retryCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entry_id': entryId ?? '',
    'entity_type': entityType,
    'entity_id': entityId,
    'table_name': tableName,
    'operation': operation,
    'data': jsonEncode(data),
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as int,
      entryId: json['entry_id'] as String?,
      entityType: json['entity_type'] as String? ?? 'entry',
      entityId: json['entity_id'] as String? ?? json['entry_id'] as String? ?? '',
      tableName: json['table_name'] as String,
      operation: json['operation'] as String,
      data: jsonDecode(json['data'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }
}
