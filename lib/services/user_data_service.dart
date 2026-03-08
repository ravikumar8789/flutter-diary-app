import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'timezone_service.dart';
import 'grace_system_service.dart';
import 'data_fetch_service.dart';
import 'database/database_manager.dart';
import 'database/local_entry_service.dart';

class UserDataService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Set<String> _recalcInProgress = {};
  static final Set<String> _recalcQueued = {};

  /// Fetch all user data including profile, stats, and preferences
  ///
  /// forceRefresh: when true (startup), fetches from Supabase and stores locally.
  /// useLocalOnly: when true (offline), reads from local SQLite only, never hits Supabase.
  static Future<UserDataResult> fetchUserData({
    DataFetchService? dataFetchService,
    bool forceRefresh = false,
    bool useLocalOnly = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return UserDataResult(
          success: false,
          error: 'User not authenticated',
          userData: null,
        );
      }

      // Fetch user profile data
      final profileData = await _fetchUserProfile(
        user.id,
        dataFetchService: dataFetchService,
        forceRefresh: forceRefresh,
        useLocalOnly: useLocalOnly,
      );
      if (!profileData.success) {
        return UserDataResult(
          success: false,
          error: profileData.error,
          userData: null,
        );
      }

      // Fetch user statistics
      final statsData = await _fetchUserStats(
        user.id,
        dataFetchService: dataFetchService,
        useLocalOnly: useLocalOnly,
      );

      // Fetch user preferences
      final preferencesData = await _fetchUserPreferences(
        user.id,
        dataFetchService: dataFetchService,
        forceRefresh: forceRefresh,
        useLocalOnly: useLocalOnly,
      );

      final userData = UserData(
        id: user.id,
        email: user.email ?? '',
        displayName: profileData.data?['display_name'] ?? '',
        avatarUrl: profileData.data?['avatar_url'],
        stats: statsData.data,
        preferences: preferencesData.data,
        timezone: profileData.data?['timezone'] as String?,
        createdAt: DateTime.parse(user.createdAt),
        lastLoginAt: DateTime.now(),
      );

      return UserDataResult(success: true, userData: userData);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS117',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'operation': 'fetch_user_data'},
        ),
      );
      return UserDataResult(
        success: false,
        error: 'Failed to fetch user data: $e',
        userData: null,
      );
    }
  }

  /// Fetch user profile information from users table
  static Future<DataResult> _fetchUserProfile(
    String userId, {
    DataFetchService? dataFetchService,
    bool forceRefresh = false,
    bool useLocalOnly = false,
  }) async {
    try {
      Map<String, dynamic>? response;

      if (dataFetchService != null) {
        response = await dataFetchService.fetchUserProfile(
          userId,
          forceRefresh: forceRefresh,
          useLocalOnly: useLocalOnly,
        );
      } else {
        if (useLocalOnly) {
          response = await DataFetchService().fetchUserProfile(userId, useLocalOnly: true);
        } else {
          response = await _supabase
              .from('users')
              .select('*')
              .eq('id', userId)
              .maybeSingle();
        }
      }

      // When useLocalOnly and no profile: do NOT create user (would hit Supabase)
      if (useLocalOnly && response == null) {
        return DataResult(
          success: false,
          error: 'No local profile',
          data: null,
        );
      }

      // Case 1: User exists
      if (response != null) {
        // When useLocalOnly, skip timezone init (may hit network)
        if (!useLocalOnly && response['timezone'] == null) {
          // Update timezone in background (don't await)
          TimezoneService.initializeUserTimezone(userId).catchError((e) {
            ErrorLoggingService.logLowError(
              error: ErrorContext.fromException(
                errorCode: 'ERRSYS165',
                severity: ErrorSeverity.low,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'operation': 'update_existing_user_timezone',
                },
              ),
            );
            return 'UTC';
          });
        }

        return DataResult(success: true, data: response);
      }

      // Case 2: User doesn't exist (null response) - Create new user (only when !useLocalOnly)
      final user = _supabase.auth.currentUser!;
      final displayName =
          user.userMetadata?['display_name'] ??
          user.email?.split('@')[0] ??
          'User';

      // Get device timezone
      final timezone = await TimezoneService.getDeviceTimezone();

      final now = DateTime.now().toIso8601String();
      final newUser = {
        'id': userId,
        'email': user.email,
        'email_verified': 0,
        'display_name': displayName,
        'avatar_url': null,
        'locale': null,
        'timezone': timezone,
        'marketing_opt_in': 0,
        'created_at': now,
        'updated_at': now,
        'is_synced': 0,
      };

      try {
        final db = await DatabaseManager().database;
        await db.insert('users', newUser);
        await LocalEntryService().addToSyncQueue(
          entityType: 'user_profile',
          entityId: userId,
          tableName: 'users',
          operation: 'upsert',
          data: newUser,
        );
        return DataResult(success: true, data: newUser);
      } catch (insertError) {
        if (_isDuplicateKeyError(insertError)) {
          final db = await DatabaseManager().database;
          final existing = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [userId],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            return DataResult(
              success: true,
              data: Map<String, dynamic>.from(existing.first),
            );
          }
          return await _retryFetchUser(
            userId,
            dataFetchService: dataFetchService,
          );
        }
        await _logUserCreationError(insertError, userId, 'insert_failed');
        return DataResult(
          success: false,
          error: 'Failed to create user: $insertError',
          data: null,
        );
      }
    } catch (e) {
      // Real error (network, DB, etc.) - don't try to create user
      await _logUserFetchError(e, userId, 'fetch_failed');
      return DataResult(
        success: false,
        error: 'Failed to fetch user profile: $e',
        data: null,
      );
    }
  }

  /// Check if error is duplicate key error
  static bool _isDuplicateKeyError(dynamic error) {
    final errorString = error.toString();
    return errorString.contains('23505') ||
        errorString.contains('duplicate key') ||
        errorString.contains('unique constraint');
  }

  /// Retry fetch after duplicate key error
  static Future<DataResult> _retryFetchUser(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    try {
      Map<String, dynamic>? retryResponse;

      if (dataFetchService != null) {
        retryResponse = await dataFetchService.fetchUserProfile(userId, forceRefresh: true);
      } else {
        // Fallback to direct query
        retryResponse = await _supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
      }

      if (retryResponse != null) {
        return DataResult(success: true, data: retryResponse);
      }
      // Still null after retry - log as warning
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.create(
          errorCode: 'ERRSYS119',
          errorMessage: 'User not found after duplicate key retry',
          severity: ErrorSeverity.medium,
          errorContext: {
            'user_id': userId,
            'operation': 'retry_fetch_after_duplicate',
          },
        ),
      );
      return DataResult(success: false, error: 'User not found', data: null);
    } catch (retryError) {
      await _logUserFetchError(retryError, userId, 'retry_fetch_failed');
      return DataResult(
        success: false,
        error: 'Retry fetch failed',
        data: null,
      );
    }
  }

  /// Log user fetch errors with detailed context
  static Future<void> _logUserFetchError(
    dynamic error,
    String userId,
    String operation,
  ) async {
    final errorString = error.toString();
    final isNetworkError =
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('connection');
    final isDbError =
        errorString.contains('database') ||
        errorString.contains('PostgrestException');

    // Use ERRSYS121 for retry fetch failures, ERRSYS118 for initial fetch failures
    final errorCode = operation == 'retry_fetch_failed'
        ? 'ERRSYS121'
        : 'ERRSYS118';
    final errorMessage = operation == 'retry_fetch_failed'
        ? 'User retry fetch failed: $errorString'
        : 'User profile fetch failed: $errorString';

    await ErrorLoggingService.logHighError(
      error: ErrorContext.create(
        errorCode: errorCode,
        errorMessage: errorMessage,
        severity: ErrorSeverity.high,
        errorContext: {
          'user_id': userId,
          'operation': operation,
          'error_type': isNetworkError
              ? 'network'
              : (isDbError ? 'database' : 'unknown'),
          'error_details': {
            'error_string': errorString,
            'error_runtime_type': error.runtimeType.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      ),
    );
  }

  /// Log user creation errors with detailed context
  static Future<void> _logUserCreationError(
    dynamic error,
    String userId,
    String operation,
  ) async {
    final errorString = error.toString();
    final isDuplicateKey = _isDuplicateKeyError(error);

    await ErrorLoggingService.logHighError(
      error: ErrorContext.fromException(
        errorCode: isDuplicateKey ? 'ERRSYS119' : 'ERRSYS120',
        severity: ErrorSeverity.high,
        exception: error,
        stackTrace: StackTrace.current,
        errorContext: {
          'user_id': userId,
          'operation': operation,
          'error_type': isDuplicateKey ? 'duplicate_key' : 'insert_error',
          'error_code': isDuplicateKey ? '23505' : 'unknown',
          'error_details': {
            'error_string': errorString,
            'error_runtime_type': error.runtimeType.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      ),
    );
  }

  /// Fetch user statistics (entries, streak, etc.)
  static Future<DataResult> _fetchUserStats(
    String userId, {
    DataFetchService? dataFetchService,
    bool useLocalOnly = false,
  }) async {
    try {
      // Get diary entries count (use entry_date for accurate streak calculation)
      List<Map<String, dynamic>> entries;

      if (dataFetchService != null) {
        // Use cached fetchEntries - fetch all entries (no date limit for stats)
        // For stats, we need all entries, so use a wide date range
        final now = DateTime.now();
        final startDate = DateTime(
          now.year - 10,
          1,
          1,
        ); // 10 years ago (should cover all entries)
        final entriesList = await dataFetchService.fetchEntries(
          userId: userId,
          startDate: startDate,
          endDate: now,
          useLocalOnly: useLocalOnly,
        );
        entries = entriesList
            .map(
              (e) => {
                'id': e.id,
                'entry_date': e.entryDate.toIso8601String().split('T')[0],
                'created_at': e.createdAt.toIso8601String(),
              },
            )
            .toList();
      } else if (useLocalOnly) {
        // Read from local DB when offline and no dataFetchService
        final db = await DatabaseManager().database;
        final rows = await db.query(
          'entries',
          columns: ['id', 'entry_date', 'created_at'],
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        entries = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      } else {
        // Fallback to direct Supabase query
        final entriesResponse = await _supabase
            .from('entries')
            .select('id, entry_date, created_at')
            .eq('user_id', userId);
        entries = List<Map<String, dynamic>>.from(entriesResponse);
      }
      final entriesCount = entries.length;

      // Get streak and last_entry_date from streaks table (single source of truth)
      final db = await DatabaseManager().database;
      final streakRecord = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final currentStreak = streakRecord.isNotEmpty
          ? (streakRecord.first['current'] as int? ?? 0)
          : 0;
      final longestStreak = streakRecord.isNotEmpty
          ? (streakRecord.first['longest'] as int? ?? 0)
          : 0;
      final lastEntryDate = streakRecord.isNotEmpty
          ? (streakRecord.first['last_entry_date'] as String?)
          : null;

      // Note: This method is READ-ONLY for stats display
      // Do NOT persist/write streak data here - writing should only happen when:
      // 1. User completes tasks (trackTaskCompletion)
      // 2. Gap detected and handled (entry_provider _checkGapsAndRecalculateStreak)
      // 3. Streak recalculation needed (recalculateStreak after entry save)

      // Get days since first entry
      final firstEntryDate = entries.isNotEmpty
          ? (entries.first['entry_date'] ?? entries.first['created_at'])
          : null;
      final firstEntry = firstEntryDate != null
          ? DateTime.parse(firstEntryDate)
          : DateTime.now();
      final daysSinceFirst = DateTime.now().difference(firstEntry).inDays + 1;

      final stats = {
        'entries_count': entriesCount,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'days_active': daysSinceFirst,
        'last_entry_date': lastEntryDate,
      };

      return DataResult(success: true, data: stats);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS119',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'fetch_user_stats'},
        ),
      );
      // Return default stats if there's an error
      return DataResult(
        success: true,
        data: {
          'entries_count': 0,
          'current_streak': 0,
          'longest_streak': 0,
          'days_active': 0,
          'last_entry_date': null,
        },
      );
    }
  }

  /// Calculate streak from today's habits_daily only (simplified)
  /// Uses current streak from streaks table and checks if today has activity
  static Future<int> _calculateStreakFromTodayHabits(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Get today's habits
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );

      if (todayHabits.isEmpty) {
        return 0;
      }

      final habit = todayHabits.first;
      final hasActivity =
          (habit['wrote_entry'] as int? ?? 0) == 1 ||
          (habit['filled_affirmations'] as int? ?? 0) == 1 ||
          (habit['filled_gratitude'] as int? ?? 0) == 1 ||
          (habit['self_care_completed_count'] as int? ?? 0) > 0;

      if (!hasActivity) {
        return 0;
      }

      // Get current streak from streaks table
      final streak = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (streak.isEmpty) {
        return 0;
      }

      final currentStreak = streak.first['current'] as int? ?? 0;
      final lastEntryDateStr = streak.first['last_entry_date'] as String?;

      if (lastEntryDateStr == null) {
        return 1;
      }

      final lastEntryDate = DateTime.parse(lastEntryDateStr);
      final lastDateOnly = DateTime(
        lastEntryDate.year,
        lastEntryDate.month,
        lastEntryDate.day,
      );
      final todayDateOnly = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

      if (daysDiff == 0) {
        return currentStreak;
      } else if (daysDiff == 1) {
        return currentStreak + 1;
      } else {
        return 0;
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS160',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId},
        ),
      );
      return 0;
    }
  }

  /// Persist computed streak into local SQLite (current/longest/last_entry_date)
  /// Uses local-first approach: updates local SQLite, syncs to Supabase (debounced)
  static Future<void> _persistStreak(
    String userId,
    int computedStreak, {
    String? lastEntryIso,
  }) async {
    try {
      final db = await DatabaseManager().database;

      // Get existing row from local SQLite
      final existing = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      final todayDateOnly = DateTime.now().toIso8601String().split('T')[0];
      final lastDate = lastEntryIso != null
          ? DateTime.parse(lastEntryIso).toIso8601String().split('T')[0]
          : todayDateOnly;

      if (existing.isEmpty) {
        // Create new record in local SQLite
        final newData = {
          'user_id': userId,
          'current': computedStreak,
          'longest': computedStreak,
          'last_entry_date': lastDate,
          'freeze_credits': 0,
          'grace_pieces_total': 0.0,
          'today_date': todayDateOnly,
          'today_diary': 0,
          'today_affirmations': 0,
          'today_gratitude': 0,
          'today_self_care_count': 0,
          'today_grace_pieces': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        };
        await db.insert('streaks', newData);
      } else {
        // Update existing record in local SQLite (preserve today_* fields)
        final longest = (existing.first['longest'] as int? ?? 0);
        final newLongest = computedStreak > longest ? computedStreak : longest;

        final updateData = {
          'current': computedStreak,
          'longest': newLongest,
          'last_entry_date': lastDate,
          // Preserve today_* fields from existing record
          'today_date': existing.first['today_date'],
          'today_diary': existing.first['today_diary'],
          'today_affirmations': existing.first['today_affirmations'],
          'today_gratitude': existing.first['today_gratitude'],
          'today_self_care_count': existing.first['today_self_care_count'],
          'today_grace_pieces': existing.first['today_grace_pieces'],
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        };
        await db.update(
          'streaks',
          updateData,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }

      await LocalEntryService.addStreakToSyncQueue(userId);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS156',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'persist_streak',
            'computed': computedStreak,
          },
        ),
      );
    }
  }

  /// Calculate streak with grace system logic
  /// Uses habits_daily for today, streaks.last_entry_date for last activity (source of truth).
  static Future<int> calculateStreakWithGrace(String userId) async {
    try {
      final newStreak = await _calculateStreakFromTodayHabits(userId);
      final db = await DatabaseManager().database;

      // Use streaks.last_entry_date (merged from Supabase) — habits_daily is today-only
      String? lastEntryDate;
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (streaks.isNotEmpty) {
        lastEntryDate = streaks.first['last_entry_date'] as String?;
      }

      final graceStatus = await GraceSystemService.getGraceStatus(userId);
      final graceDaysAvailable = graceStatus?['grace_days_available'] ?? 0;

      // Check if user completed any task today
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );

      final completedToday =
          todayHabits.isNotEmpty &&
          ((todayHabits.first['wrote_entry'] as int? ?? 0) == 1 ||
              (todayHabits.first['filled_affirmations'] as int? ?? 0) == 1 ||
              (todayHabits.first['filled_gratitude'] as int? ?? 0) == 1 ||
              (todayHabits.first['self_care_completed_count'] as int? ?? 0) >
                  0);

      // If user completed tasks today, update streak with today as last_entry_date
      if (completedToday) {
        await _persistStreak(userId, newStreak, lastEntryIso: today);
        return newStreak;
      }

      // User didn't complete tasks today - check if we should use grace day
      if (lastEntryDate == null) {
        // No previous tasks
        if (graceDaysAvailable > 0) {
          await _useGraceDayForStreak(userId);
          final current = await _getCurrentStreak(userId);
          return current;
        }
        await _persistStreak(userId, 0);
        return 0;
      }

      // Check gap
      final lastDate = DateTime.parse(lastEntryDate);
      final todayDate = DateTime.now();
      final todayDateOnly = DateTime(
        todayDate.year,
        todayDate.month,
        todayDate.day,
      );
      final lastDateOnly = DateTime(
        lastDate.year,
        lastDate.month,
        lastDate.day,
      );
      final daysDifference = todayDateOnly.difference(lastDateOnly).inDays;

      if (daysDifference == 1) {
        // Missed exactly 1 day (yesterday)
        if (graceDaysAvailable > 0) {
          final currentStreak = await _getCurrentStreak(userId);
          await _useGraceDayForStreak(userId);
          return currentStreak; // Maintain current streak
        } else {
          await _persistStreak(userId, 0);
          return 0;
        }
      } else if (daysDifference > 1) {
        // Missed multiple days
        if (graceDaysAvailable >= daysDifference - 1) {
          for (int i = 0; i < daysDifference - 1; i++) {
            await _useGraceDayForStreak(userId);
          }
          final current = await _getCurrentStreak(userId);
          return current;
        } else {
          await _persistStreak(userId, 0);
          return 0;
        }
      } else {
        // Same day or future (shouldn't happen)
        await _persistStreak(userId, newStreak, lastEntryIso: lastEntryDate);
        return newStreak;
      }
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS119',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'operation': 'calculate_streak_with_grace'},
        ),
      );
      // Fallback to today's streak calculation
      return await _calculateStreakFromTodayHabits(userId);
    }
  }

  /// Ensure streaks record exists (public for DataPrefetchService).
  static Future<void> ensureStreaksRecordExists(String userId) async {
    await _ensureStreaksRecordExists(userId);
  }

  /// Apply gap logic when last_entry_date < today (splash path only).
  /// Uses only streaks table — no habits_daily. For multi-device correctness.
  static Future<void> applyGapIfNeeded(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (streaks.isEmpty) return;

      final lastEntryDateStr = streaks.first['last_entry_date'] as String?;
      if (lastEntryDateStr == null) return;

      final lastEntryDate = DateTime.parse(lastEntryDateStr);
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final lastDateOnly = DateTime(
        lastEntryDate.year,
        lastEntryDate.month,
        lastEntryDate.day,
      );
      final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;
      if (daysDiff <= 0) return;
      if (daysDiff == 1) return; // last_entry_date = yesterday; user can still write today

      final graceDays = streaks.first['freeze_credits'] as int? ?? 0;

      if (daysDiff > 1) {
        if (graceDays >= daysDiff - 1) {
          for (int i = 0; i < daysDiff - 1; i++) {
            await GraceSystemService.useGraceDay(userId);
          }
        } else {
          await db.update(
            'streaks',
            {
              'current': 0,
              'last_entry_date': null,
              'updated_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          await LocalEntryService.addStreakToSyncQueue(userId);
        }
      }
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS170',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'apply_gap_if_needed'},
        ),
      );
    }
  }

  /// Helper: Ensure streaks record exists
  static Future<void> _ensureStreaksRecordExists(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final existing = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (existing.isEmpty) {
        final todayDateStr = DateTime.now().toIso8601String().split('T')[0];
        await db.insert('streaks', {
          'user_id': userId,
          'current': 0,
          'longest': 0,
          'last_entry_date': null,
          'freeze_credits': 0,
          'grace_pieces_total': 0.0,
          'today_date': todayDateStr,
          'today_diary': 0,
          'today_affirmations': 0,
          'today_gratitude': 0,
          'today_self_care_count': 0,
          'today_grace_pieces': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        });
      }
    } catch (e) {
      // Silently fail - this is a helper method
    }
  }

  /// Recalculate and update streak after entry save (local-only)
  static Future<void> recalculateStreak(String userId) async {
    if (_recalcInProgress.contains(userId)) {
      _recalcQueued.add(userId);
      return;
    }

    _recalcInProgress.add(userId);
    try {
      final db = await DatabaseManager().database;

      // Check if recalculation is needed (recalculate if date changed)
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (streaks.isNotEmpty) {
        final lastEntryDateStr = streaks.first['last_entry_date'] as String?;
        if (lastEntryDateStr != null) {
          try {
            final lastEntryDate = DateTime.parse(lastEntryDateStr);
            final today = DateTime.now();
            final todayDateOnly = DateTime(today.year, today.month, today.day);
            final lastDateOnly = DateTime(
              lastEntryDate.year,
              lastEntryDate.month,
              lastEntryDate.day,
            );

            // Recalculate if last_entry_date is before today (date changed)
            // This fixes the bug where daysDiff = 1 (yesterday) was incorrectly skipped
            if (lastDateOnly.isAtSameMomentAs(todayDateOnly) ||
                lastDateOnly.isAfter(todayDateOnly)) {
              // Same day or future date, no need to recalculate
              return;
            }
            // Date changed (lastDateOnly is before todayDateOnly), continue to recalculate
          } catch (e) {
            // Date parsing failed, continue to recalculate to be safe
            await ErrorLoggingService.logLowError(
              error: ErrorContext.fromException(
                errorCode: 'ERRSYS159',
                severity: ErrorSeverity.low,
                exception: e,
                stackTrace: StackTrace.current,
                errorContext: {
                  'user_id': userId,
                  'last_entry_date': lastEntryDateStr,
                  'operation': 'recalculate_streak_date_check',
                },
              ),
            );
            // Continue to recalculate if date parsing fails
          }
        }
      }

      await calculateStreakWithGrace(userId);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS157',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'recalculate_streak'},
        ),
      );
    } finally {
      _recalcInProgress.remove(userId);
      if (_recalcQueued.remove(userId)) {
        Future.microtask(() => recalculateStreak(userId));
      }
    }
  }

  /// Use grace day to maintain streak
  /// Uses local-first approach: updates local SQLite, syncs to Supabase (debounced)
  static Future<void> _useGraceDayForStreak(String userId) async {
    try {
      final db = await DatabaseManager().database;

      // Get current grace days from local SQLite
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (streaks.isEmpty) {
        return; // No streak record
      }

      final currentGraceDays = streaks.first['freeze_credits'] as int? ?? 0;
      if (currentGraceDays <= 0) {
        return; // No grace days available
      }

      // Update streaks table in local SQLite (decrease grace days)
      await db.update(
        'streaks',
        {
          'freeze_credits': currentGraceDays - 1,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await LocalEntryService.addStreakToSyncQueue(userId);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS121',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'use_grace_day'},
        ),
      );
    }
  }

  /// Get current streak from local SQLite
  static Future<int> _getCurrentStreak(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final streaks = await db.query(
        'streaks',
        columns: ['current'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      return streaks.isNotEmpty ? (streaks.first['current'] as int? ?? 0) : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch user preferences
  static Future<DataResult> _fetchUserPreferences(
    String userId, {
    DataFetchService? dataFetchService,
    bool forceRefresh = false,
    bool useLocalOnly = false,
  }) async {
    try {
      Map<String, dynamic>? response;

      if (dataFetchService != null) {
        response = await dataFetchService.fetchUserSettings(
          userId,
          forceRefresh: forceRefresh,
          useLocalOnly: useLocalOnly,
        );
      } else if (useLocalOnly) {
        response = await DataFetchService().fetchUserSettings(userId, useLocalOnly: true);
      } else {
        response = await _supabase
            .from('user_settings')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();
      }

      if (response == null) {
        // Return default preferences if none exist
        return DataResult(
          success: true,
          data: {
            'theme': 'system',
            'notifications': true,
            'reminder_time': '20:00',
            'writing_goal': 1,
            'privacy_level': 'private',
          },
        );
      }

      return DataResult(success: true, data: response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS120',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetch_user_preferences',
          },
        ),
      );
      // Return default preferences if none exist
      return DataResult(
        success: true,
        data: {
          'theme': 'system',
          'notifications': true,
          'reminder_time': '20:00',
          'writing_goal': 1,
          'privacy_level': 'private',
        },
      );
    }
  }

  /// Future: Add more data fetching methods here
  /// Example methods for future features:

  /// Fetch user's wellness data
  static Future<DataResult> fetchWellnessData(String userId) async {
    // TODO: Implement when wellness tracking is added
    return DataResult(success: true, data: {});
  }

  /// Fetch user's gratitude entries
  static Future<DataResult> fetchGratitudeData(String userId) async {
    // TODO: Implement when gratitude feature is added
    return DataResult(success: true, data: {});
  }

  /// Fetch user's morning rituals data
  static Future<DataResult> fetchMorningRitualsData(String userId) async {
    // TODO: Implement when morning rituals feature is added
    return DataResult(success: true, data: {});
  }

  /// Fetch user's analytics data
  static Future<DataResult> fetchAnalyticsData(String userId) async {
    // TODO: Implement when analytics feature is added
    return DataResult(success: true, data: {});
  }
}

/// Data models for the service
class UserData {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? preferences;
  final String? timezone;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  UserData({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.stats,
    this.preferences,
    this.timezone,
    required this.createdAt,
    required this.lastLoginAt,
  });
}

class UserDataResult {
  final bool success;
  final String? error;
  final UserData? userData;

  UserDataResult({required this.success, this.error, this.userData});
}

class DataResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;

  DataResult({required this.success, this.error, this.data});
}
