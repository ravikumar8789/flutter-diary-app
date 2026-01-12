import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../repositories/data_repository.dart';
import '../models/entry_models.dart';
import '../models/analytics_models.dart';
import 'error_logging_service.dart';
import 'analytics_service.dart';
import 'database/database_manager.dart';

/// Centralized data fetching service
/// 
/// All data fetching operations go through this service.
/// Uses DataRepository for caching and deduplication.
class DataFetchService {
  final DataRepository _repository;
  final SupabaseClient _supabase;

  DataFetchService({
    required DataRepository repository,
    SupabaseClient? supabase,
  })  : _repository = repository,
        _supabase = supabase ?? Supabase.instance.client;

  /// Fetch entries with date range
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  /// Automatically handles deduplication if same query is in-flight.
  Future<List<Entry>> fetchEntries({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Generate cache key
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];
    final key = 'entries_${userId}_${startDateStr}_${endDateStr}';

    try {
      return await _repository.fetch<List<Entry>>(
        key: key,
        fetcher: () async {
          try {
            final response = await _supabase
                .from('entries')
                .select('*')
                .eq('user_id', userId)
                .gte('entry_date', startDateStr)
                .lte('entry_date', endDateStr)
                .order('entry_date', ascending: false);

            final entries = (response as List)
                .map((e) => Entry.fromSupabaseJson(e as Map<String, dynamic>))
                .toList();

            return entries;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA200',
              errorMessage: 'DB query failed (entries): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'start_date': startDateStr,
                'end_date': endDateStr,
                'table': 'entries',
                'operation': 'fetch_entries',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA201',
        errorMessage: 'Fetch entries failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_entries',
        },
      );
      rethrow;
    }
  }

  /// Fetch habits_daily with date range
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  /// Automatically handles deduplication if same query is in-flight.
  /// Uses local-first approach: reads from local SQLite first, then Supabase if missing.
  Future<List<HabitsDaily>> fetchHabitsDaily({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Generate cache key
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];
    final key = 'habits_${userId}_${startDateStr}_${endDateStr}';

    try {
      return await _repository.fetch<List<HabitsDaily>>(
        key: key,
        fetcher: () async {
          try {
            // Local-first: Try to read from local SQLite first
            final db = await DatabaseManager().database;
            final localHabits = await db.query(
              'habits_daily',
              where: 'user_id = ? AND date >= ? AND date <= ?',
              whereArgs: [userId, startDateStr, endDateStr],
              orderBy: 'date DESC',
            );

            // Check if we have all dates covered
            final localDates = localHabits.map((h) => h['date'] as String).toSet();
            final allDates = <String>{};
            var currentDate = startDate;
            while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
              allDates.add(currentDate.toIso8601String().split('T')[0]);
              currentDate = currentDate.add(const Duration(days: 1));
            }

            // If we have all dates locally, return local data
            if (localDates.length == allDates.length && localHabits.isNotEmpty) {
              return localHabits.map((h) {
                return HabitsDaily(
                  id: h['id'] as String,
                  userId: h['user_id'] as String,
                  date: DateTime.parse(h['date'] as String),
                  wroteEntry: (h['wrote_entry'] as int? ?? 0) == 1,
                  filledAffirmations: (h['filled_affirmations'] as int? ?? 0) == 1,
                  filledGratitude: (h['filled_gratitude'] as int? ?? 0) == 1,
                  selfCareCompletedCount: h['self_care_completed_count'] as int? ?? 0,
                  gracePiecesEarned: (h['grace_pieces_earned'] as num? ?? 0.0).toDouble(),
                );
              }).toList();
            }

            // If missing, fetch from Supabase
            final response = await _supabase
                .from('habits_daily')
                .select('*')
                .eq('user_id', userId)
                .gte('date', startDateStr)
                .lte('date', endDateStr)
                .order('date', ascending: false);

            final habits = (response as List)
                .map((e) => HabitsDaily.fromJson(e as Map<String, dynamic>))
                .toList();

            // Cache in local SQLite
            for (final habit in habits) {
              await db.insert(
                'habits_daily',
                {
                  'id': habit.id,
                  'user_id': habit.userId,
                  'date': habit.date.toIso8601String().split('T')[0],
                  'wrote_entry': habit.wroteEntry ? 1 : 0,
                  'filled_affirmations': habit.filledAffirmations ? 1 : 0,
                  'filled_gratitude': habit.filledGratitude ? 1 : 0,
                  'self_care_completed_count': habit.selfCareCompletedCount,
                  'grace_pieces_earned': habit.gracePiecesEarned,
                  'is_synced': 1,
                  'last_sync_at': DateTime.now().toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            return habits;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA210',
              errorMessage: 'DB query failed (habits_daily): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'start_date': startDateStr,
                'end_date': endDateStr,
                'table': 'habits_daily',
                'operation': 'fetch_habits_daily',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA211',
        errorMessage: 'Fetch habits daily failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_habits_daily',
        },
      );
      rethrow;
    }
  }

  /// Batch fetch multiple data types in parallel
  /// 
  /// Fetches entries and habits_daily simultaneously.
  /// Uses Future.wait for parallel execution.
  Future<BatchData> fetchBatch({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final results = await Future.wait([
        fetchEntries(
          userId: userId,
          startDate: startDate,
          endDate: endDate,
        ),
        fetchHabitsDaily(
          userId: userId,
          startDate: startDate,
          endDate: endDate,
        ),
      ]);

      return BatchData(
        entries: results[0] as List<Entry>,
        habits: results[1] as List<HabitsDaily>,
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA203',
        errorMessage: 'Batch fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'operation': 'fetch_batch',
        },
      );
      rethrow;
    }
  }

  /// Fetch monthly insights list with caching
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  /// Automatically handles deduplication if same query is in-flight.
  Future<List<MonthMetadata>> fetchMonthlyInsightsList({
    required String userId,
  }) async {
    final key = 'monthly_insights_list_$userId';

    try {
      return await _repository.fetch<List<MonthMetadata>>(
        key: key,
        fetcher: () async {
          try {
            final service = AnalyticsService();
            return await service.getMonthlyInsightsList(userId);
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA205',
              errorMessage: 'DB query failed (monthly insights list): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'table': 'monthly_insights',
                'operation': 'fetch_monthly_insights_list',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA206',
        errorMessage: 'Fetch monthly insights list failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_monthly_insights_list',
        },
      );
      rethrow;
    }
  }

  /// Fetch monthly analytics with caching
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  /// Automatically handles deduplication if same query is in-flight.
  Future<MonthlyAnalyticsData> fetchMonthlyAnalytics({
    required String userId,
    required DateTime monthStart,
  }) async {
    final monthKey = '${monthStart.year}-${monthStart.month}';
    final key = 'monthly_analytics_${userId}_$monthKey';

    try {
      return await _repository.fetch<MonthlyAnalyticsData>(
        key: key,
        fetcher: () async {
          try {
            final service = AnalyticsService();
            return await service.getMonthlyAnalytics(monthStart);
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA207',
              errorMessage: 'DB query failed (monthly analytics): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'month_start': monthStart.toIso8601String(),
                'operation': 'fetch_monthly_analytics',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA208',
        errorMessage: 'Fetch monthly analytics failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'month_start': monthStart.toIso8601String(),
          'cache_key': key,
          'operation': 'fetch_monthly_analytics',
        },
      );
      rethrow;
    }
  }

  // ============================================================================
  // USER & SETTINGS METHODS
  // ============================================================================

  /// Fetch user profile from users table
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    final key = 'user_profile_$userId';

    try {
      return await _repository.fetch<Map<String, dynamic>?>(
        key: key,
        fetcher: () async {
          try {
            final response = await _supabase
                .from('users')
                .select('*')
                .eq('id', userId)
                .maybeSingle();

            return response;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA220',
              errorMessage: 'DB query failed (user profile): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'table': 'users',
                'operation': 'fetch_user_profile',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA221',
        errorMessage: 'Fetch user profile failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_user_profile',
        },
      );
      rethrow;
    }
  }

  /// Fetch user settings
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  Future<Map<String, dynamic>?> fetchUserSettings(String userId) async {
    final key = 'user_settings_$userId';

    try {
      return await _repository.fetch<Map<String, dynamic>?>(
        key: key,
        fetcher: () async {
          try {
            final response = await _supabase
                .from('user_settings')
                .select('*')
                .eq('user_id', userId)
                .maybeSingle();

            return response;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA222',
              errorMessage: 'DB query failed (user settings): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'table': 'user_settings',
                'operation': 'fetch_user_settings',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA223',
        errorMessage: 'Fetch user settings failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_user_settings',
        },
      );
      rethrow;
    }
  }

  /// Fetch streaks data
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  /// Uses local-first approach: reads from local SQLite first, then Supabase if missing/stale.
  Future<Map<String, dynamic>?> fetchStreaks(String userId) async {
    final key = 'streaks_$userId';

    try {
      return await _repository.fetch<Map<String, dynamic>?>(
        key: key,
        fetcher: () async {
          try {
            // Local-first: Try to read from local SQLite first
            final db = await DatabaseManager().database;
            final localStreak = await db.query(
              'streaks',
              where: 'user_id = ?',
              whereArgs: [userId],
              limit: 1,
            );

            if (localStreak.isNotEmpty) {
              final streak = localStreak.first;
              // Check if stale (older than 15 minutes)
              final lastSyncAt = streak['last_sync_at'] as String?;
              if (lastSyncAt != null) {
                final lastSync = DateTime.parse(lastSyncAt);
                final now = DateTime.now();
                if (now.difference(lastSync).inMinutes < 15) {
                  // Return local data if fresh
                  return {
                    'user_id': streak['user_id'],
                    'current': streak['current'],
                    'longest': streak['longest'],
                    'last_entry_date': streak['last_entry_date'],
                    'freeze_credits': streak['freeze_credits'],
                    'grace_pieces_total': streak['grace_pieces_total'],
                    'updated_at': streak['updated_at'],
                  };
                }
              }
            }

            // If missing or stale, fetch from Supabase
            final response = await _supabase
                .from('streaks')
                .select('*')
                .eq('user_id', userId)
                .maybeSingle();

            if (response != null) {
              // Cache in local SQLite
              await db.insert(
                'streaks',
                {
                  'user_id': response['user_id'],
                  'current': response['current'] ?? 0,
                  'longest': response['longest'] ?? 0,
                  'last_entry_date': response['last_entry_date'],
                  'freeze_credits': response['freeze_credits'] ?? 0,
                  'grace_pieces_total': response['grace_pieces_total'] ?? 0.0,
                  'updated_at': response['updated_at'] ?? DateTime.now().toIso8601String(),
                  'is_synced': 1,
                  'last_sync_at': DateTime.now().toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } else {
              // Create default record in local SQLite if doesn't exist
              await db.insert(
                'streaks',
                {
                  'user_id': userId,
                  'current': 0,
                  'longest': 0,
                  'last_entry_date': null,
                  'freeze_credits': 0,
                  'grace_pieces_total': 0.0,
                  'updated_at': DateTime.now().toIso8601String(),
                  'is_synced': 1,
                  'last_sync_at': DateTime.now().toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            return response;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA224',
              errorMessage: 'DB query failed (streaks): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'table': 'streaks',
                'operation': 'fetch_streaks',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA225',
        errorMessage: 'Fetch streaks failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_streaks',
        },
      );
      rethrow;
    }
  }

  // ============================================================================
  // EXTENDED ENTRY METHODS
  // ============================================================================

  /// Fetch single entry by date
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  Future<Entry?> fetchEntryByDate(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final key = 'entry_${userId}_$dateStr';

    try {
      return await _repository.fetch<Entry?>(
        key: key,
        fetcher: () async {
          try {
            final response = await _supabase
                .from('entries')
                .select('*')
                .eq('user_id', userId)
                .eq('entry_date', dateStr)
                .maybeSingle();

            if (response == null) return null;
            return Entry.fromSupabaseJson(response);
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA226',
              errorMessage: 'DB query failed (entry by date): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'date': dateStr,
                'table': 'entries',
                'operation': 'fetch_entry_by_date',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA227',
        errorMessage: 'Fetch entry by date failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'date': dateStr,
          'cache_key': key,
          'operation': 'fetch_entry_by_date',
        },
      );
      rethrow;
    }
  }

  /// Fetch entries with JOINs (for HistoryService)
  /// 
  /// Returns entries with all related data using JOIN query.
  /// Returns cached data if available, otherwise fetches from DB.
  Future<List<Map<String, dynamic>>> fetchEntriesWithJoins({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];
    final key = 'entries_joins_${userId}_${startDateStr}_${endDateStr}';

    try {
      return await _repository.fetch<List<Map<String, dynamic>>>(
        key: key,
        fetcher: () async {
          try {
            final response = await _supabase
                .from('entries')
                .select('''
                  *,
                  entry_self_care(*),
                  entry_meals(*),
                  entry_affirmations(*),
                  entry_gratitude(*),
                  entry_priorities(*),
                  entry_tomorrow_notes(*)
                ''')
                .eq('user_id', userId)
                .gte('entry_date', startDateStr)
                .lte('entry_date', endDateStr)
                .order('entry_date', ascending: false);

            return (response as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA228',
              errorMessage: 'DB query failed (entries with JOINs): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'start_date': startDateStr,
                'end_date': endDateStr,
                'table': 'entries',
                'operation': 'fetch_entries_with_joins',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA229',
        errorMessage: 'Fetch entries with JOINs failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': startDateStr,
          'end_date': endDateStr,
          'cache_key': key,
          'operation': 'fetch_entries_with_joins',
        },
      );
      rethrow;
    }
  }

  /// Fetch entries with specific select columns
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  Future<List<Map<String, dynamic>>> fetchEntriesWithSelect({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String select,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];
    final key = 'entries_select_${userId}_${startDateStr}_${endDateStr}_${select.hashCode}';

    try {
      return await _repository.fetch<List<Map<String, dynamic>>>(
        key: key,
        fetcher: () async {
          try {
            final response = await _supabase
                .from('entries')
                .select(select)
                .eq('user_id', userId)
                .gte('entry_date', startDateStr)
                .lte('entry_date', endDateStr)
                .order('entry_date', ascending: false);

            return (response as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA230',
              errorMessage: 'DB query failed (entries with select): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'start_date': startDateStr,
                'end_date': endDateStr,
                'select': select,
                'table': 'entries',
                'operation': 'fetch_entries_with_select',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA231',
        errorMessage: 'Fetch entries with select failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': startDateStr,
          'end_date': endDateStr,
          'select': select,
          'cache_key': key,
          'operation': 'fetch_entries_with_select',
        },
      );
      rethrow;
    }
  }

  // ============================================================================
  // EXTENDED HABITS METHODS
  // ============================================================================

  /// Fetch ALL habits_daily for user
  /// 
  /// DEPRECATED: This method is expensive (fetches 365+ records).
  /// Not needed for Enhanced Option 1 (we use incremental updates).
  /// Use fetchHabitsDaily() with date range instead.
  @Deprecated('Use fetchHabitsDaily() with date range instead. This method is expensive.')
  Future<List<HabitsDaily>> fetchAllHabitsDaily(String userId) async {
    // Return empty list - this method should not be used
    // If needed, use fetchHabitsDaily() with appropriate date range
    return <HabitsDaily>[];
  }

  /// Fetch single day habits
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  /// Uses local-first approach: reads from local SQLite first, then Supabase if missing.
  Future<HabitsDaily?> fetchHabitsForDate(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final key = 'habits_${userId}_$dateStr';

    try {
      return await _repository.fetch<HabitsDaily?>(
        key: key,
        fetcher: () async {
          try {
            // Local-first: Try to read from local SQLite first
            final db = await DatabaseManager().database;
            final localHabits = await db.query(
              'habits_daily',
              where: 'user_id = ? AND date = ?',
              whereArgs: [userId, dateStr],
              limit: 1,
            );

            if (localHabits.isNotEmpty) {
              final habit = localHabits.first;
              return HabitsDaily(
                id: habit['id'] as String,
                userId: habit['user_id'] as String,
                date: DateTime.parse(habit['date'] as String),
                wroteEntry: (habit['wrote_entry'] as int? ?? 0) == 1,
                filledAffirmations: (habit['filled_affirmations'] as int? ?? 0) == 1,
                filledGratitude: (habit['filled_gratitude'] as int? ?? 0) == 1,
                selfCareCompletedCount: habit['self_care_completed_count'] as int? ?? 0,
                gracePiecesEarned: (habit['grace_pieces_earned'] as num? ?? 0.0).toDouble(),
              );
            }

            // If missing, fetch from Supabase
            final response = await _supabase
                .from('habits_daily')
                .select('*')
                .eq('user_id', userId)
                .eq('date', dateStr)
                .maybeSingle();

            if (response == null) return null;

            final habit = HabitsDaily.fromJson(response);

            // Cache in local SQLite
            await db.insert(
              'habits_daily',
              {
                'id': habit.id,
                'user_id': habit.userId,
                'date': habit.date.toIso8601String().split('T')[0],
                'wrote_entry': habit.wroteEntry ? 1 : 0,
                'filled_affirmations': habit.filledAffirmations ? 1 : 0,
                'filled_gratitude': habit.filledGratitude ? 1 : 0,
                'self_care_completed_count': habit.selfCareCompletedCount,
                'grace_pieces_earned': habit.gracePiecesEarned,
                'is_synced': 1,
                'last_sync_at': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            return habit;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA234',
              errorMessage: 'DB query failed (habits for date): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'date': dateStr,
                'table': 'habits_daily',
                'operation': 'fetch_habits_for_date',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA235',
        errorMessage: 'Fetch habits for date failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'cache_key': key,
          'operation': 'fetch_habits_for_date',
        },
      );
      rethrow;
    }
  }

  // ============================================================================
  // ANALYTICS METHODS
  // ============================================================================

  /// Fetch weekly analytics
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  Future<WeeklyAnalyticsData> fetchWeeklyAnalytics({
    required String userId,
    required DateTime weekStart,
  }) async {
    final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
    final key = 'weekly_analytics_${userId}_$weekKey';

    try {
      return await _repository.fetch<WeeklyAnalyticsData>(
        key: key,
        fetcher: () async {
          try {
            final service = AnalyticsService();
            return await service.getWeeklyAnalytics(weekStart);
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA236',
              errorMessage: 'DB query failed (weekly analytics): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'week_start': weekStart.toIso8601String(),
                'operation': 'fetch_weekly_analytics',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA237',
        errorMessage: 'Fetch weekly analytics failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'week_start': weekStart.toIso8601String(),
          'cache_key': key,
          'operation': 'fetch_weekly_analytics',
        },
      );
      rethrow;
    }
  }

  /// Fetch entry insights
  /// 
  /// Returns cached data if available, otherwise fetches from DB.
  Future<List<EntryInsights>> fetchEntryInsights({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? entryId,
  }) async {
    // Generate cache key
    String key;
    if (entryId != null) {
      key = 'entry_insights_${userId}_$entryId';
    } else if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      key = 'entry_insights_${userId}_${startStr}_$endStr';
    } else {
      key = 'entry_insights_${userId}_all';
    }

    try {
      return await _repository.fetch<List<EntryInsights>>(
        key: key,
        fetcher: () async {
          try {
            var query = _supabase
                .from('entry_insights')
                .select('''
                  id,
                  entry_id,
                  summary,
                  insight_text,
                  insight_details,
                  sentiment_label,
                  sentiment_score,
                  topics,
                  processed_at,
                  status,
                  entries!inner(entry_date, user_id)
                ''')
                .eq('entries.user_id', userId)
                .eq('status', 'success');

            if (entryId != null) {
              query = query.eq('entry_id', entryId);
            } else if (startDate != null && endDate != null) {
              final startStr = startDate.toIso8601String().split('T')[0];
              final endStr = endDate.toIso8601String().split('T')[0];
              query = query
                  .gte('entries.entry_date', startStr)
                  .lte('entries.entry_date', endStr);
            }

            final response = await query.order('processed_at', ascending: false);

            return (response as List)
                .map((e) {
                  final json = e as Map<String, dynamic>;
                  return EntryInsights.fromJson(json);
                })
                .toList();
          } catch (e) {
            await ErrorLoggingService.logHighError(
              errorCode: 'ERRDATA238',
              errorMessage: 'DB query failed (entry insights): ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'entry_id': entryId,
                'start_date': startDate?.toIso8601String(),
                'end_date': endDate?.toIso8601String(),
                'table': 'entry_insights',
                'operation': 'fetch_entry_insights',
              },
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA239',
        errorMessage: 'Fetch entry insights failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'entry_id': entryId,
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'cache_key': key,
          'operation': 'fetch_entry_insights',
        },
      );
      rethrow;
    }
  }

  // ============================================================================
  // CACHE INVALIDATION METHODS
  // ============================================================================

  /// Invalidate entries cache for a user
  /// 
  /// Call this when entries are created/updated/deleted.
  void invalidateEntriesCache(String userId, DateTime? date) {
    _repository.invalidateEntries(userId, date);
  }

  /// Invalidate habits cache for a user
  /// 
  /// Call this when habits are created/updated/deleted.
  /// 
  /// NOTE: Removed auto-invalidation of home summary to prevent cascade.
  /// Home summary will be invalidated separately if needed.
  void invalidateHabitsCache(String userId, DateTime? date) {
    _repository.invalidateHabits(userId, date);
    // REMOVED: Auto-invalidation of home summary to prevent cascade
    // Call invalidateHomeSummaryCache() separately if needed
  }

  /// Invalidate home summary cache for a user
  /// 
  /// Call this when data affecting home summary changes.
  void invalidateHomeSummaryCache(String userId) {
    _repository.invalidateHomeSummary(userId);
  }

  /// Invalidate monthly cache for a user
  /// 
  /// Call this when monthly data changes (entry saved, monthly insight generated).
  void invalidateMonthlyCache(String userId, DateTime? monthStart) {
    _repository.invalidateMonthly(userId, monthStart);
  }

  /// Invalidate user settings cache
  /// 
  /// Call this when user settings are updated.
  void invalidateUserSettingsCache(String userId) {
    try {
      final key = 'user_settings_$userId';
      _repository.invalidate(key);
    } catch (e) {
      ErrorLoggingService.logLowError(
        errorCode: 'ERRDATA240',
        errorMessage: 'Invalidate user settings cache failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'invalidate_user_settings_cache',
        },
      );
    }
  }

  /// Invalidate streaks cache
  /// 
  /// Call this when streaks are updated.
  /// 
  /// NOTE: Removed auto-invalidation of home summary to prevent cascade.
  /// Home summary will be invalidated separately if needed.
  void invalidateStreaksCache(String userId) {
    try {
      final key = 'streaks_$userId';
      _repository.invalidate(key);
      // REMOVED: Auto-invalidation of home summary to prevent cascade
      // Call invalidateHomeSummaryCache() separately if needed
    } catch (e) {
      ErrorLoggingService.logLowError(
        errorCode: 'ERRDATA241',
        errorMessage: 'Invalidate streaks cache failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'invalidate_streaks_cache',
        },
      );
    }
  }

  /// Invalidate all user data cache
  /// 
  /// Call this when user logs out or major data changes occur.
  void invalidateAllUserCache(String userId) {
    try {
      // Invalidate all cache keys for this user
      invalidateEntriesCache(userId, null);
      invalidateHabitsCache(userId, null);
      invalidateStreaksCache(userId);
      invalidateUserSettingsCache(userId);
      invalidateHomeSummaryCache(userId);
      invalidateMonthlyCache(userId, null);
      
      // Also invalidate all habits cache (for fetchAllHabitsDaily)
      final allHabitsKey = 'habits_all_$userId';
      _repository.invalidate(allHabitsKey);
    } catch (e) {
      ErrorLoggingService.logLowError(
        errorCode: 'ERRDATA242',
        errorMessage: 'Invalidate all user cache failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'invalidate_all_user_cache',
        },
      );
    }
  }
}

/// Batch data result
class BatchData {
  final List<Entry> entries;
  final List<HabitsDaily> habits;

  BatchData({
    required this.entries,
    required this.habits,
  });
}

