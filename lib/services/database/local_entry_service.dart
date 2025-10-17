import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../database/database_manager.dart';
import '../../models/entry_models.dart';

class LocalEntryService {
  final DatabaseManager _dbManager = DatabaseManager();

  // Fetch today's entry (or any date)
  Future<Entry?> getEntryByDate(String userId, DateTime date) async {
    final db = await _dbManager.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final results = await db.query(
      'entries',
      where: 'user_id = ? AND entry_date = ?',
      whereArgs: [userId, dateStr],
    );

    if (results.isEmpty) return null;
    return Entry.fromJson(results.first);
  }

  // Upsert entry (insert or update)
  Future<void> upsertEntry(Entry entry) async {
    final db = await _dbManager.database;
    await db.insert(
      'entries',
      entry.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Add to sync queue
    await _addToSyncQueue(entry.id, 'entries', 'upsert', entry.toJson());
  }

  // Upsert affirmations
  Future<void> upsertAffirmations(EntryAffirmations affirmations) async {
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
  }

  // Upsert priorities
  Future<void> upsertPriorities(EntryPriorities priorities) async {
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
  }

  // Upsert meals
  Future<void> upsertMeals(EntryMeals meals) async {
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
  }

  // Upsert gratitude
  Future<void> upsertGratitude(EntryGratitude gratitude) async {
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
  }

  // Upsert self care
  Future<void> upsertSelfCare(EntrySelfCare selfCare) async {
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
  }

  // Upsert shower bath
  Future<void> upsertShowerBath(EntryShowerBath showerBath) async {
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
  }

  // Upsert tomorrow notes
  Future<void> upsertTomorrowNotes(EntryTomorrowNotes tomorrowNotes) async {
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

  // Mark entry as synced
  Future<void> markAsSynced(String entryId) async {
    final db = await _dbManager.database;
    await db.update(
      'entries',
      {'is_synced': 1, 'last_sync_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  // Get sync queue
  Future<List<SyncQueueItem>> getSyncQueue() async {
    final db = await _dbManager.database;
    final results = await db.query('sync_queue', orderBy: 'created_at ASC');

    return results.map((json) => SyncQueueItem.fromJson(json)).toList();
  }

  // Remove sync queue item
  Future<void> removeSyncQueueItem(int id) async {
    final db = await _dbManager.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // Increment retry count
  Future<void> incrementRetryCount(int id) async {
    final db = await _dbManager.database;
    await db.update(
      'sync_queue',
      {'retry_count': 'retry_count + 1'},
      where: 'id = ?',
      whereArgs: [id],
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

  // Add to sync queue
  Future<void> _addToSyncQueue(
    String entryId,
    String tableName,
    String operation,
    Map<String, dynamic> data,
  ) async {
    final db = await _dbManager.database;
    await db.insert('sync_queue', {
      'entry_id': entryId,
      'table_name': tableName,
      'operation': operation,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }
}

// Sync queue item model
class SyncQueueItem {
  final int id;
  final String entryId;
  final String tableName;
  final String operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  SyncQueueItem({
    required this.id,
    required this.entryId,
    required this.tableName,
    required this.operation,
    required this.data,
    required this.createdAt,
    required this.retryCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entry_id': entryId,
    'table_name': tableName,
    'operation': operation,
    'data': jsonEncode(data),
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'],
      entryId: json['entry_id'],
      tableName: json['table_name'],
      operation: json['operation'],
      data: jsonDecode(json['data']),
      createdAt: DateTime.parse(json['created_at']),
      retryCount: json['retry_count'],
    );
  }
}
