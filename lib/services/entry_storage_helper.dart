import 'package:sqflite/sqflite.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import '../models/entry_models.dart';
import 'database/database_manager.dart';

/// Shared helper for storing entries with related data in local DB.
/// Used by DataFetchService and DataPrefetchService to avoid circular imports.
class EntryStorageHelper {
  /// Store entries with timestamp merge: only overwrite when Supabase.updated_at > local.updated_at.
  static Future<void> storeEntriesWithRelatedDataWithMerge(
    List<Map<String, dynamic>> entries,
    String userId,
  ) async {
    final db = await DatabaseManager().database;
    final toStore = <Map<String, dynamic>>[];
    for (final entryData in entries) {
      try {
        final entryId = entryData['id'] as String?;
        if (entryId == null) continue;
        final supabaseUpdated = entryData['updated_at'] as String?;
        if (supabaseUpdated == null) {
          toStore.add(entryData);
          continue;
        }
        final localRows = await db.query('entries', where: 'id = ?', whereArgs: [entryId], limit: 1);
        if (localRows.isEmpty) {
          toStore.add(entryData);
          continue;
        }
        final localUpdated = localRows.first['updated_at'] as String?;
        if (localUpdated == null || DateTime.parse(supabaseUpdated).isAfter(DateTime.parse(localUpdated))) {
          toStore.add(entryData);
        }
      } catch (_) {
        toStore.add(entryData);
      }
    }
    if (toStore.isNotEmpty) {
      await storeEntriesWithRelatedData(toStore, userId);
    }
  }

  static Future<void> storeEntriesWithRelatedData(
    List<Map<String, dynamic>> entries,
    String userId,
  ) async {
    final db = await DatabaseManager().database;
    final nowUtc = DateTime.now().toUtc();
    final syncTimeStr = nowUtc.toIso8601String();

    for (final entryData in entries) {
      try {
        Entry entry;
        try {
          entry = Entry.fromSupabaseJson(entryData);
        } catch (e) {
          await ErrorLoggingService.logHighError(
            error: ErrorContext.fromException(
              errorCode: 'ERRSYS181',
              severity: ErrorSeverity.high,
              exception: e,
              stackTrace: StackTrace.current,
              errorContext: {
                'user_id': userId,
                'entry_id': entryData['id'],
                'operation': 'store_entry_with_related_data',
              },
            ),
          );
          continue;
        }

        final entryId = entry.id;

        await db.transaction((txn) async {
          await txn.delete('sync_queue', where: 'entry_id = ?', whereArgs: [entryId]);

          final entryJson = entry.toJson();
          entryJson['is_synced'] = 1;
          entryJson['last_sync_at'] = syncTimeStr;

          await txn.insert('entries', entryJson, conflictAlgorithm: ConflictAlgorithm.replace);

          if (entryData['entry_affirmations'] != null) {
            try {
              final d = Map<String, dynamic>.from(entryData['entry_affirmations'] as Map<String, dynamic>);
              d['entry_id'] = entryId;
              await txn.insert('entry_affirmations', EntryAffirmations.fromSupabaseJson(d).toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              ErrorLoggingService.logHighError(error: ErrorContext.fromException(errorCode: 'ERRSYS173', severity: ErrorSeverity.high, exception: e, stackTrace: StackTrace.current, errorContext: {'user_id': userId, 'entry_id': entryId, 'table': 'entry_affirmations'}));
            }
          }
          if (entryData['entry_priorities'] != null) {
            try {
              final d = Map<String, dynamic>.from(entryData['entry_priorities'] as Map<String, dynamic>);
              d['entry_id'] = entryId;
              await txn.insert('entry_priorities', EntryPriorities.fromSupabaseJson(d).toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              ErrorLoggingService.logHighError(error: ErrorContext.fromException(errorCode: 'ERRSYS174', severity: ErrorSeverity.high, exception: e, stackTrace: StackTrace.current, errorContext: {'user_id': userId, 'entry_id': entryId, 'table': 'entry_priorities'}));
            }
          }
          if (entryData['entry_meals'] != null) {
            try {
              final d = Map<String, dynamic>.from(entryData['entry_meals'] as Map<String, dynamic>);
              d['entry_id'] = entryId;
              await txn.insert('entry_meals', EntryMeals.fromSupabaseJson(d).toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              ErrorLoggingService.logHighError(error: ErrorContext.fromException(errorCode: 'ERRSYS175', severity: ErrorSeverity.high, exception: e, stackTrace: StackTrace.current, errorContext: {'user_id': userId, 'entry_id': entryId, 'table': 'entry_meals'}));
            }
          }
          if (entryData['entry_gratitude'] != null) {
            try {
              final d = Map<String, dynamic>.from(entryData['entry_gratitude'] as Map<String, dynamic>);
              d['entry_id'] = entryId;
              await txn.insert('entry_gratitude', EntryGratitude.fromSupabaseJson(d).toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              ErrorLoggingService.logHighError(error: ErrorContext.fromException(errorCode: 'ERRSYS176', severity: ErrorSeverity.high, exception: e, stackTrace: StackTrace.current, errorContext: {'user_id': userId, 'entry_id': entryId, 'table': 'entry_gratitude'}));
            }
          }
          if (entryData['entry_self_care'] != null) {
            try {
              final d = Map<String, dynamic>.from(entryData['entry_self_care'] as Map<String, dynamic>);
              d['entry_id'] = entryId;
              await txn.insert('entry_self_care', EntrySelfCare.fromSupabaseJson(d).toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              ErrorLoggingService.logHighError(error: ErrorContext.fromException(errorCode: 'ERRSYS177', severity: ErrorSeverity.high, exception: e, stackTrace: StackTrace.current, errorContext: {'user_id': userId, 'entry_id': entryId, 'table': 'entry_self_care'}));
            }
          }
          if (entryData['entry_tomorrow_notes'] != null) {
            try {
              final d = Map<String, dynamic>.from(entryData['entry_tomorrow_notes'] as Map<String, dynamic>);
              d['entry_id'] = entryId;
              await txn.insert('entry_tomorrow_notes', EntryTomorrowNotes.fromSupabaseJson(d).toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              ErrorLoggingService.logHighError(error: ErrorContext.fromException(errorCode: 'ERRSYS178', severity: ErrorSeverity.high, exception: e, stackTrace: StackTrace.current, errorContext: {'user_id': userId, 'entry_id': entryId, 'table': 'entry_tomorrow_notes'}));
            }
          }
        });
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRSYS179',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {'user_id': userId, 'entry_id': entryData['id'], 'operation': 'store_entry_with_related_data'},
          ),
        );
      }
    }
  }
}
