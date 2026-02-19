import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../repositories/data_repository.dart';
import '../models/entry_models.dart';
import '../models/analytics_models.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'analytics_service.dart';
import 'database/database_manager.dart';
import 'user_data_service.dart';

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
  }) : _repository = repository,
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA200',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'start_date': startDateStr,
                  'end_date': endDateStr,
                  'table': 'entries',
                  'operation': 'fetch_entries',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA201',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'cache_key': key,
            'operation': 'fetch_entries',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch habits_daily with date range
  ///
  /// DEPRECATED: This method is deprecated. habits_daily table removed from Supabase.
  /// Use streaks.today_* fields instead. This method now only returns today's data from local DB.
  ///
  /// Returns today's data from local SQLite only (if available).
  /// No longer fetches from Supabase or historical data.
  @Deprecated(
    'Use streaks.today_* fields instead. This method only returns today\'s local data.',
  )
  Future<List<HabitsDaily>> fetchHabitsDaily({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // DEPRECATED: Only return today's data from local DB (if available)
    // No longer fetches from Supabase or historical data
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;

      // Only return today's data from local DB
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );

      if (todayHabits.isEmpty) {
        return <HabitsDaily>[];
      }

      return todayHabits.map((h) {
        return HabitsDaily(
          id: h['id'] as String,
          userId: h['user_id'] as String,
          date: DateTime.parse(h['date'] as String),
          wroteEntry: (h['wrote_entry'] as int? ?? 0) == 1,
          filledAffirmations: (h['filled_affirmations'] as int? ?? 0) == 1,
          filledGratitude: (h['filled_gratitude'] as int? ?? 0) == 1,
          selfCareCompletedCount: h['self_care_completed_count'] as int? ?? 0,
          gracePiecesEarned: (h['grace_pieces_earned'] as num? ?? 0.0)
              .toDouble(),
        );
      }).toList();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA211',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetch_habits_daily_deprecated',
          },
        ),
      );
      return <HabitsDaily>[];
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
        fetchEntries(userId: userId, startDate: startDate, endDate: endDate),
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA203',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'operation': 'fetch_batch',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA205',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'table': 'monthly_insights',
                  'operation': 'fetch_monthly_insights_list',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA206',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'cache_key': key,
            'operation': 'fetch_monthly_insights_list',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA207',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'month_start': monthStart.toIso8601String(),
                  'operation': 'fetch_monthly_analytics',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA208',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'month_start': monthStart.toIso8601String(),
            'cache_key': key,
            'operation': 'fetch_monthly_analytics',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA220',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'table': 'users',
                  'operation': 'fetch_user_profile',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA221',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'cache_key': key,
            'operation': 'fetch_user_profile',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA222',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'table': 'user_settings',
                  'operation': 'fetch_user_settings',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA223',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'cache_key': key,
            'operation': 'fetch_user_settings',
          },
        ),
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

              // CRITICAL: If local has unsynced changes, do NOT overwrite with Supabase
              // (Supabase may be stale; sync is debounced 3s)
              final isSynced = (streak['is_synced'] as int? ?? 0) == 1;
              if (!isSynced) {
                return {
                  'user_id': streak['user_id'],
                  'current': streak['current'],
                  'longest': streak['longest'],
                  'last_entry_date': streak['last_entry_date'],
                  'freeze_credits': streak['freeze_credits'],
                  'grace_pieces_total': streak['grace_pieces_total'],
                  'updated_at': streak['updated_at'],
                  'today_date': streak['today_date'],
                  'today_diary': streak['today_diary'],
                  'today_affirmations': streak['today_affirmations'],
                  'today_gratitude': streak['today_gratitude'],
                  'today_self_care_count': streak['today_self_care_count'],
                  'today_grace_pieces': streak['today_grace_pieces'],
                };
              }

              // CRITICAL: Check if date changed (more important than time-based staleness)
              final lastEntryDateStr = streak['last_entry_date'] as String?;
              bool dateChanged = false;

              if (lastEntryDateStr != null) {
                try {
                  final lastEntryDate = DateTime.parse(lastEntryDateStr);
                  final today = DateTime.now();
                  final todayDateOnly = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );
                  final lastDateOnly = DateTime(
                    lastEntryDate.year,
                    lastEntryDate.month,
                    lastEntryDate.day,
                  );

                  // If date changed, need recalculation (don't return cached data)
                  dateChanged = lastDateOnly.isBefore(todayDateOnly);
                } catch (e) {
                  // If date parsing fails, treat as date changed to be safe
                  dateChanged = true;
                }
              }

              // If date changed, skip cache and trigger recalculation
              if (!dateChanged) {
                // Same day, check time-based staleness (15 minutes)
                final lastSyncAt = streak['last_sync_at'] as String?;
                if (lastSyncAt != null) {
                  final lastSync = DateTime.parse(lastSyncAt);
                  final now = DateTime.now();
                  if (now.difference(lastSync).inMinutes < 15) {
                    // Return local data if fresh (same day and recent sync)
                    return {
                      'user_id': streak['user_id'],
                      'current': streak['current'],
                      'longest': streak['longest'],
                      'last_entry_date': streak['last_entry_date'],
                      'freeze_credits': streak['freeze_credits'],
                      'grace_pieces_total': streak['grace_pieces_total'],
                      'updated_at': streak['updated_at'],
                      'today_date': streak['today_date'],
                      'today_diary': streak['today_diary'],
                      'today_affirmations': streak['today_affirmations'],
                      'today_gratitude': streak['today_gratitude'],
                      'today_self_care_count': streak['today_self_care_count'],
                      'today_grace_pieces': streak['today_grace_pieces'],
                    };
                  }
                }
              }
              // If date changed or stale, fall through to fetch from Supabase and recalculate
            }

            // If missing or stale, fetch from Supabase
            print(
              '🔥 STREAK DEBUG: fetchStreaks - Fetching from Supabase with select(*)',
            );
            final response = await _supabase
                .from('streaks')
                .select('*')
                .eq('user_id', userId)
                .maybeSingle();
            print(
              '🔥 STREAK DEBUG: fetchStreaks - Supabase raw response: $response',
            );

            if (response != null) {
              // Cache in local SQLite
              print(
                '🔥 STREAK DEBUG: fetchStreaks - Caching Supabase response to local DB',
              );
              await db.insert('streaks', {
                'user_id': response['user_id'],
                'current': response['current'] ?? 0,
                'longest': response['longest'] ?? 0,
                'last_entry_date': response['last_entry_date'],
                'freeze_credits': response['freeze_credits'] ?? 0,
                'grace_pieces_total': response['grace_pieces_total'] ?? 0.0,
                'today_date': response['today_date'],
                'today_diary': (response['today_diary'] ?? false) ? 1 : 0,
                'today_affirmations': (response['today_affirmations'] ?? false)
                    ? 1
                    : 0,
                'today_gratitude': (response['today_gratitude'] ?? false)
                    ? 1
                    : 0,
                'today_self_care_count': response['today_self_care_count'] ?? 0,
                'today_grace_pieces': response['today_grace_pieces'] ?? 0.0,
                'updated_at':
                    response['updated_at'] ?? DateTime.now().toIso8601String(),
                'is_synced': 1,
                'last_sync_at': DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
              print('🔥 STREAK DEBUG: fetchStreaks - Cached to local DB');

              // Check if date changed and trigger recalculation if needed
              final lastEntryDateStr = response['last_entry_date'] as String?;
              if (lastEntryDateStr != null) {
                try {
                  final lastEntryDate = DateTime.parse(lastEntryDateStr);
                  final today = DateTime.now();
                  final todayDateOnly = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );
                  final lastDateOnly = DateTime(
                    lastEntryDate.year,
                    lastEntryDate.month,
                    lastEntryDate.day,
                  );

                  // If date changed, trigger recalculation (async, non-blocking)
                  if (lastDateOnly.isBefore(todayDateOnly)) {
                    // Date changed, recalculate streak in background
                    UserDataService.recalculateStreak(
                      userId,
                      dataFetchService: this,
                    ).catchError((e) {
                      // Log error but don't fail the fetch
                      ErrorLoggingService.logLowError(
                        error: ErrorContext.fromException(
                          errorCode: 'ERRDATA225',
                          severity: ErrorSeverity.low,
                          exception: e,
                          stackTrace: StackTrace.current,
                          errorContext: {
                            'user_id': userId,
                            'operation': 'fetch_streaks_recalculate',
                          },
                        ),
                      );
                    });
                  }
                } catch (e) {
                  // Date parsing failed, skip recalculation
                }
              }
            } else {
              // Create default record in local SQLite if doesn't exist
              await db.insert('streaks', {
                'user_id': userId,
                'current': 0,
                'longest': 0,
                'last_entry_date': null,
                'freeze_credits': 0,
                'grace_pieces_total': 0.0,
                'updated_at': DateTime.now().toIso8601String(),
                'is_synced': 1,
                'last_sync_at': DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }

            return response;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA224',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'table': 'streaks',
                  'operation': 'fetch_streaks',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA225',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'cache_key': key,
            'operation': 'fetch_streaks',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA226',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'date': dateStr,
                  'table': 'entries',
                  'operation': 'fetch_entry_by_date',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA227',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'date': dateStr,
            'cache_key': key,
            'operation': 'fetch_entry_by_date',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch entries by mood with JOINs (for HistoryService mood filter)
  ///
  /// Returns entries filtered by mood with date range and pagination.
  /// Uses cache key: entries_mood_${userId}_${moodScore}_${endDateStr}_${limit}_${offset}
  Future<List<Map<String, dynamic>>> fetchEntriesByMoodWithJoins({
    required String userId,
    required int moodScore,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    final endDateStr = endDate != null
        ? endDate.toIso8601String().split('T')[0]
        : 'all';
    final key =
        'entries_mood_${userId}_${moodScore}_${endDateStr}_${limit}_$offset';

    debugPrint(
      'HISTORY DEBUG: fetchEntriesByMoodWithJoins key=$key '
      'endDate=$endDate startDate=$startDate',
    );

    try {
      return await _repository.fetch<List<Map<String, dynamic>>>(
        key: key,
        fetcher: () async {
          try {
            var query = _supabase
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
                .eq('mood_score', moodScore);

            if (endDate != null) {
              final endDateStrVal = endDate.toIso8601String().split('T')[0];
              query = query.lt('entry_date', endDateStrVal);
            }
            if (startDate != null) {
              final startDateStr =
                  startDate.toIso8601String().split('T')[0];
              query = query.gte('entry_date', startDateStr);
            }

            final response = await query
                .order('entry_date', ascending: false)
                .range(offset, offset + limit - 1);
            debugPrint(
              'HISTORY DEBUG: fetchEntriesByMoodWithJoins Supabase returned '
              '${(response as List).length} rows',
            );
            return (response as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          } catch (e) {
            await ErrorLoggingService.logHighError(
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA232',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'mood_score': moodScore,
                  'end_date': endDate?.toIso8601String(),
                  'table': 'entries',
                  'operation': 'fetch_entries_by_mood_with_joins',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA233',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'mood_score': moodScore,
            'cache_key': key,
            'operation': 'fetch_entries_by_mood_with_joins',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA228',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'start_date': startDateStr,
                  'end_date': endDateStr,
                  'table': 'entries',
                  'operation': 'fetch_entries_with_joins',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA229',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDateStr,
            'end_date': endDateStr,
            'cache_key': key,
            'operation': 'fetch_entries_with_joins',
          },
        ),
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
    final key =
        'entries_select_${userId}_${startDateStr}_${endDateStr}_${select.hashCode}';

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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA230',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'start_date': startDateStr,
                  'end_date': endDateStr,
                  'select': select,
                  'table': 'entries',
                  'operation': 'fetch_entries_with_select',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA231',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDateStr,
            'end_date': endDateStr,
            'select': select,
            'cache_key': key,
            'operation': 'fetch_entries_with_select',
          },
        ),
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
  @Deprecated(
    'Use fetchHabitsDaily() with date range instead. This method is expensive.',
  )
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
                filledAffirmations:
                    (habit['filled_affirmations'] as int? ?? 0) == 1,
                filledGratitude: (habit['filled_gratitude'] as int? ?? 0) == 1,
                selfCareCompletedCount:
                    habit['self_care_completed_count'] as int? ?? 0,
                gracePiecesEarned: (habit['grace_pieces_earned'] as num? ?? 0.0)
                    .toDouble(),
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
            await db.insert('habits_daily', {
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
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            return habit;
          } catch (e) {
            await ErrorLoggingService.logHighError(
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA234',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'date': dateStr,
                  'table': 'habits_daily',
                  'operation': 'fetch_habits_for_date',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA235',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'cache_key': key,
            'operation': 'fetch_habits_for_date',
          },
        ),
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
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA236',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'week_start': weekStart.toIso8601String(),
                  'operation': 'fetch_weekly_analytics',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA237',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'week_start': weekStart.toIso8601String(),
            'cache_key': key,
            'operation': 'fetch_weekly_analytics',
          },
        ),
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

            final response = await query.order(
              'processed_at',
              ascending: false,
            );

            return (response as List).map((e) {
              final json = e as Map<String, dynamic>;
              return EntryInsights.fromJson(json);
            }).toList();
          } catch (e) {
            await ErrorLoggingService.logHighError(
              error: ErrorContext.fromException(
                errorCode: 'ERRDATA238',
                severity: ErrorSeverity.high,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'entry_id': entryId,
                  'start_date': startDate?.toIso8601String(),
                  'end_date': endDate?.toIso8601String(),
                  'table': 'entry_insights',
                  'operation': 'fetch_entry_insights',
                },
              ),
            );
            rethrow;
          }
        },
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA239',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'entry_id': entryId,
            'start_date': startDate?.toIso8601String(),
            'end_date': endDate?.toIso8601String(),
            'cache_key': key,
            'operation': 'fetch_entry_insights',
          },
        ),
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA240',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'invalidate_user_settings_cache',
          },
        ),
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA241',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'invalidate_streaks_cache',
          },
        ),
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA242',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'invalidate_all_user_cache',
          },
        ),
      );
    }
  }
}

/// Batch data result
class BatchData {
  final List<Entry> entries;
  final List<HabitsDaily> habits;

  BatchData({required this.entries, required this.habits});
}
