import 'package:sqflite/sqflite.dart';
import 'data_fetch_service.dart';
import 'error_logging_service.dart';
import 'database/database_manager.dart';
import '../models/entry_models.dart';

/// Service for prefetching 7 days of data
/// 
/// Used after logout/login to ensure local database has recent data
/// for calculations and UI display
class DataPrefetchService {
  /// Prefetch 7 days of data for user
  /// 
  /// Fetches:
  /// - Last 7 days of entries with ALL related data (joins)
  /// - Last 7 days of habits_daily (deprecated, but kept for compatibility)
  /// - Current streak data
  /// 
  /// Uses local device date (consistent with prefetchTodayData() and entry storage).
  /// Fetches in parallel for better performance.
  /// Does not throw exceptions - errors are logged but app continues.
  static Future<void> prefetch7DaysData(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      // Use local device date (extract date components only, no timezone conversion)
      // entry_date is stored as date only, so we use local date to match user's device date
      // This ensures consistency with prefetchTodayData() and entry storage
      final now = DateTime.now();
      final todayLocal = DateTime(now.year, now.month, now.day);
      final weekStartLocal = todayLocal.subtract(const Duration(days: 6)); // Last 7 days
      
      // Fetch in parallel for better performance
      await Future.wait([
        _fetchEntriesWithJoins(userId, weekStartLocal, todayLocal, dataFetchService),
        _fetchHabits(userId, weekStartLocal, todayLocal, dataFetchService),
        _fetchStreaks(userId, dataFetchService),
      ]);
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS164',
        errorMessage: 'Failed to prefetch 7 days data: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'prefetch7DaysData',
          'timezone': DateTime.now().timeZoneName,
          'utc_offset': DateTime.now().timeZoneOffset.toString(),
        },
      );
      // Don't rethrow - allow app to continue even if prefetch fails
      // Data will be fetched on-demand when screens need it
    }
  }
  
  /// Prefetch today's data for user
  /// 
  /// Fetches today's entry with ALL related data (joins) for multi-device sync.
  /// Called on every startup to ensure today's data is fresh.
  /// 
  /// Does not throw exceptions - errors are logged but app continues.
  static Future<void> prefetchTodayData(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      // Use local device date (extract date components only, no timezone conversion)
      // entry_date is stored as date only, so we use local date to match user's device date
      final now = DateTime.now();
      final todayLocal = DateTime(now.year, now.month, now.day);
      
      // Fetch today's data with joins
      final entries = await dataFetchService.fetchEntriesWithJoins(
        userId: userId,
        startDate: todayLocal,
        endDate: todayLocal,
      );
      
      // If no entry found, return early (no logging - expected behavior)
      if (entries.isEmpty) {
        return;
      }
      
      // Store today's entry with all related data
      await _storeEntriesWithRelatedData(entries, userId);
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS171',
        errorMessage: 'Failed to prefetch today\'s data: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'prefetchTodayData',
          'timezone': DateTime.now().timeZoneName,
          'utc_offset': DateTime.now().timeZoneOffset.toString(),
        },
      );
      // Don't rethrow - allow app to continue even if prefetch fails
      // Data will be fetched on-demand when screens need it
    }
  }
  
  /// Fetch entries for date range with joins and store in local DB
  static Future<void> _fetchEntriesWithJoins(
    String userId,
    DateTime startDate,
    DateTime endDate,
    DataFetchService dataFetchService,
  ) async {
    try {
      // Fetch entries with all related data using joins
      final entries = await dataFetchService.fetchEntriesWithJoins(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
      
      // Store entries with all related data in local DB
      if (entries.isNotEmpty) {
        await _storeEntriesWithRelatedData(entries, userId);
      }
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS165',
        errorMessage: 'Failed to prefetch entries with joins: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'timezone': DateTime.now().timeZoneName,
          'utc_offset': DateTime.now().timeZoneOffset.toString(),
        },
      );
      // Don't rethrow - continue with other fetches
    }
  }
  
  /// Fetch habits for date range
  static Future<void> _fetchHabits(
    String userId,
    DateTime startDate,
    DateTime endDate,
    DataFetchService dataFetchService,
  ) async {
    try {
      await dataFetchService.fetchHabitsDaily(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS166',
        errorMessage: 'Failed to prefetch habits: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        },
      );
      // Don't rethrow - continue with other fetches
    }
  }
  
  /// Fetch streak data
  static Future<void> _fetchStreaks(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      await dataFetchService.fetchStreaks(userId);
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS167',
        errorMessage: 'Failed to prefetch streaks: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
        },
      );
      // Don't rethrow - continue with other fetches
    }
  }
  
  /// Store entries with all related data in local DB
  /// 
  /// Uses direct DB inserts (bypasses LocalEntryService) to avoid sync queue pollution.
  /// Data fetched from Supabase is already synced, so we mark it as synced and don't add to sync queue.
  static Future<void> _storeEntriesWithRelatedData(
    List<Map<String, dynamic>> entries,
    String userId,
  ) async {
    final db = await DatabaseManager().database;
    final nowUtc = DateTime.now().toUtc();
    final syncTimeStr = nowUtc.toIso8601String();
    
    // Store entries one by one (transaction per entry for better error isolation)
    for (final entryData in entries) {
      try {
        // Parse entry with timezone validation
        Entry entry;
        try {
          entry = Entry.fromSupabaseJson(entryData);
        } catch (e) {
          // Date parsing failed - log as HIGH severity
          await ErrorLoggingService.logHighError(
            errorCode: 'ERRSYS181',
            errorMessage: 'Date parsing failed in entry: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            errorContext: {
              'user_id': userId,
              'entry_id': entryData['id'],
              'entry_date': entryData['entry_date'],
              'created_at': entryData['created_at'],
              'updated_at': entryData['updated_at'],
              'timezone': DateTime.now().timeZoneName,
            },
          );
          // Skip this entry
          continue;
        }
        
        final entryId = entry.id;
        
        // Use transaction for atomicity per entry
        await db.transaction((txn) async {
          // Clear sync queue entries for this entry_id BEFORE storing
          // Server data takes precedence over local unsynced changes
          await txn.delete(
            'sync_queue',
            where: 'entry_id = ?',
            whereArgs: [entryId],
          );
          
          // Store entry (mark as synced since it's from Supabase)
          final entryJson = entry.toJson();
          entryJson['is_synced'] = 1;
          entryJson['last_sync_at'] = syncTimeStr;
          
          await txn.insert(
            'entries',
            entryJson,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          
          // Store related data (only if exists)
          // Store affirmations
          if (entryData['entry_affirmations'] != null) {
            try {
              final affirmationsData = Map<String, dynamic>.from(
                entryData['entry_affirmations'] as Map<String, dynamic>,
              );
              // Ensure entry_id matches the parent entry
              affirmationsData['entry_id'] = entryId;
              final affirmations = EntryAffirmations.fromSupabaseJson(affirmationsData);
              await txn.insert(
                'entry_affirmations',
                affirmations.toJson(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              // Log error but continue with other tables
              ErrorLoggingService.logHighError(
                errorCode: 'ERRSYS173',
                errorMessage: 'Failed to store entry_affirmations: ${e.toString()}',
                stackTrace: StackTrace.current.toString(),
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'table': 'entry_affirmations',
                },
              );
            }
          }
          
          // Store priorities
          if (entryData['entry_priorities'] != null) {
            try {
              final prioritiesData = Map<String, dynamic>.from(
                entryData['entry_priorities'] as Map<String, dynamic>,
              );
              prioritiesData['entry_id'] = entryId;
              final priorities = EntryPriorities.fromSupabaseJson(prioritiesData);
              await txn.insert(
                'entry_priorities',
                priorities.toJson(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              ErrorLoggingService.logHighError(
                errorCode: 'ERRSYS174',
                errorMessage: 'Failed to store entry_priorities: ${e.toString()}',
                stackTrace: StackTrace.current.toString(),
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'table': 'entry_priorities',
                },
              );
            }
          }
          
          // Store meals
          if (entryData['entry_meals'] != null) {
            try {
              final mealsData = Map<String, dynamic>.from(
                entryData['entry_meals'] as Map<String, dynamic>,
              );
              mealsData['entry_id'] = entryId;
              final meals = EntryMeals.fromSupabaseJson(mealsData);
              await txn.insert(
                'entry_meals',
                meals.toJson(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              ErrorLoggingService.logHighError(
                errorCode: 'ERRSYS175',
                errorMessage: 'Failed to store entry_meals: ${e.toString()}',
                stackTrace: StackTrace.current.toString(),
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'table': 'entry_meals',
                },
              );
            }
          }
          
          // Store gratitude
          if (entryData['entry_gratitude'] != null) {
            try {
              final gratitudeData = Map<String, dynamic>.from(
                entryData['entry_gratitude'] as Map<String, dynamic>,
              );
              gratitudeData['entry_id'] = entryId;
              final gratitude = EntryGratitude.fromSupabaseJson(gratitudeData);
              await txn.insert(
                'entry_gratitude',
                gratitude.toJson(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              ErrorLoggingService.logHighError(
                errorCode: 'ERRSYS176',
                errorMessage: 'Failed to store entry_gratitude: ${e.toString()}',
                stackTrace: StackTrace.current.toString(),
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'table': 'entry_gratitude',
                },
              );
            }
          }
          
          // Store self-care
          if (entryData['entry_self_care'] != null) {
            try {
              final selfCareData = Map<String, dynamic>.from(
                entryData['entry_self_care'] as Map<String, dynamic>,
              );
              selfCareData['entry_id'] = entryId;
              final selfCare = EntrySelfCare.fromSupabaseJson(selfCareData);
              await txn.insert(
                'entry_self_care',
                selfCare.toJson(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              ErrorLoggingService.logHighError(
                errorCode: 'ERRSYS177',
                errorMessage: 'Failed to store entry_self_care: ${e.toString()}',
                stackTrace: StackTrace.current.toString(),
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'table': 'entry_self_care',
                },
              );
            }
          }
          
          // Store tomorrow notes
          if (entryData['entry_tomorrow_notes'] != null) {
            try {
              final tomorrowNotesData = Map<String, dynamic>.from(
                entryData['entry_tomorrow_notes'] as Map<String, dynamic>,
              );
              tomorrowNotesData['entry_id'] = entryId;
              final tomorrowNotes = EntryTomorrowNotes.fromSupabaseJson(tomorrowNotesData);
              await txn.insert(
                'entry_tomorrow_notes',
                tomorrowNotes.toJson(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              ErrorLoggingService.logHighError(
                errorCode: 'ERRSYS178',
                errorMessage: 'Failed to store entry_tomorrow_notes: ${e.toString()}',
                stackTrace: StackTrace.current.toString(),
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'table': 'entry_tomorrow_notes',
                },
              );
            }
          }
        });
        
      } catch (e) {
        // Log entry-level error but continue with other entries
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS179',
          errorMessage: 'Failed to parse/store entry: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'user_id': userId,
            'entry_id': entryData['id'],
            'operation': 'store_entry_with_related_data',
          },
        );
        // Continue with next entry
      }
    }
  }
}
