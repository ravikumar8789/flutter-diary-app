import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'timezone_service.dart';
import 'grace_system_service.dart';
import 'data_fetch_service.dart';
import '../repositories/data_repository.dart';
import 'database/database_manager.dart';
import 'sync/supabase_sync_service.dart';

class UserDataService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final SupabaseSyncService _syncService = SupabaseSyncService();
  static Timer? _debounceTimer;
  static final Set<String> _recalcInProgress = {};
  static final Set<String> _recalcQueued = {};

  /// Fetch all user data including profile, stats, and preferences
  ///
  /// Uses DataFetchService for caching if provided.
  static Future<UserDataResult> fetchUserData({
    DataFetchService? dataFetchService,
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
      );

      // Fetch user preferences
      final preferencesData = await _fetchUserPreferences(
        user.id,
        dataFetchService: dataFetchService,
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
  }) async {
    try {
      Map<String, dynamic>? response;

      if (dataFetchService != null) {
        // Use cached fetchUserProfile
        response = await dataFetchService.fetchUserProfile(userId);
      } else {
        // Fallback to direct query
        response = await _supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
      }

      // Case 1: User exists
      if (response != null) {
        // Check if timezone is null and update it
        if (response['timezone'] == null) {
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

      // Case 2: User doesn't exist (null response) - Create new user
      final user = _supabase.auth.currentUser!;
      final displayName =
          user.userMetadata?['display_name'] ??
          user.email?.split('@')[0] ??
          'User';

      // Get device timezone
      final timezone = await TimezoneService.getDeviceTimezone();

      final newUser = {
        'id': userId,
        'email': user.email,
        'display_name': displayName,
        'avatar_url': null,
        'timezone': timezone,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _supabase.from('users').insert(newUser);
        return DataResult(success: true, data: newUser);
      } catch (insertError) {
        // Handle duplicate key error (race condition)
        if (_isDuplicateKeyError(insertError)) {
          // User was created between check and insert, retry fetch
          return await _retryFetchUser(
            userId,
            dataFetchService: dataFetchService,
          );
        }
        // Other insert errors - log and return
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
        // Use cached fetchUserProfile
        retryResponse = await dataFetchService.fetchUserProfile(userId);
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
      } else {
        // Fallback to direct query
        final entriesResponse = await _supabase
            .from('entries')
            .select('id, entry_date, created_at')
            .eq('user_id', userId);
        entries = List<Map<String, dynamic>>.from(entriesResponse);
      }
      final entriesCount = entries.length;

      // Get current streak from streaks table (not calculating from habits_daily)
      final db = await DatabaseManager().database;
      final streakRecord = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final streak = streakRecord.isNotEmpty
          ? (streakRecord.first['current'] as int? ?? 0)
          : 0;

      // Get last entry date from habits_daily (most recent date with any task completed)
      final lastHabit = await db.query(
        'habits_daily',
        where:
            'user_id = ? AND (wrote_entry = 1 OR filled_affirmations = 1 OR filled_gratitude = 1 OR self_care_completed_count > 0)',
        whereArgs: [userId],
        orderBy: 'date DESC',
        limit: 1,
      );
      final lastEntryDate = lastHabit.isNotEmpty
          ? lastHabit.first['date'] as String?
          : null;

      // Note: This method is READ-ONLY for stats display
      // Do NOT persist/write streak data here - writing should only happen when:
      // 1. User completes tasks (trackTaskCompletion)
      // 2. Gap detected and handled (calculateStreakOnAppLaunch)
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
        'current_streak': streak,
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
          'days_active': 0,
          'last_entry_date': null,
        },
      );
    }
  }

  /// Calculate streak from today's habits_daily only (simplified)
  /// Uses current streak from streaks table and checks if today has activity
  static Future<int> _calculateStreakFromTodayHabits(String userId) async {
    print(
      '🔥 STREAK DEBUG: _calculateStreakFromTodayHabits START - userId: $userId',
    );
    try {
      final db = await DatabaseManager().database;
      final today = DateTime.now().toIso8601String().split('T')[0];
      print('🔥 STREAK DEBUG: Today: $today');

      // Get today's habits
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );
      print(
        '🔥 STREAK DEBUG: Today habits query result: ${todayHabits.length} records',
      );

      if (todayHabits.isEmpty) {
        print('🔥 STREAK DEBUG: No habits for today, returning 0');
        return 0;
      }

      final habit = todayHabits.first;
      print('🔥 STREAK DEBUG: Today habit data: $habit');
      final hasActivity =
          (habit['wrote_entry'] as int? ?? 0) == 1 ||
          (habit['filled_affirmations'] as int? ?? 0) == 1 ||
          (habit['filled_gratitude'] as int? ?? 0) == 1 ||
          (habit['self_care_completed_count'] as int? ?? 0) > 0;
      print('🔥 STREAK DEBUG: Has activity today: $hasActivity');

      if (!hasActivity) {
        print('🔥 STREAK DEBUG: No activity today, returning 0');
        return 0;
      }

      // Get current streak from streaks table
      final streak = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      print('🔥 STREAK DEBUG: Streak query result: ${streak.length} records');

      if (streak.isEmpty) {
        print('🔥 STREAK DEBUG: No streak record, returning 0');
        return 0;
      }

      final currentStreak = streak.first['current'] as int? ?? 0;
      final lastEntryDateStr = streak.first['last_entry_date'] as String?;
      print(
        '🔥 STREAK DEBUG: Current streak: $currentStreak, last_entry_date: $lastEntryDateStr',
      );

      if (lastEntryDateStr == null) {
        print('🔥 STREAK DEBUG: No last_entry_date, returning 1');
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
      print(
        '🔥 STREAK DEBUG: lastDateOnly: ${lastDateOnly.toIso8601String().split('T')[0]}, daysDiff: $daysDiff',
      );

      if (daysDiff == 0) {
        // Same day - return current streak (already incremented)
        print(
          '🔥 STREAK DEBUG: Same day, returning current streak: $currentStreak',
        );
        return currentStreak;
      } else if (daysDiff == 1) {
        // Consecutive day - increment
        final newStreak = currentStreak + 1;
        print('🔥 STREAK DEBUG: Consecutive day, returning: $newStreak');
        return newStreak;
      } else {
        // Gap - reset or use grace days (handled elsewhere)
        print('🔥 STREAK DEBUG: Gap detected ($daysDiff days), returning 0');
        return 0;
      }
    } catch (e) {
      print('🔥 STREAK DEBUG: _calculateStreakFromTodayHabits ERROR: $e');
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
    print(
      '🔥 STREAK DEBUG: _persistStreak START - userId: $userId, computedStreak: $computedStreak, lastEntryIso: $lastEntryIso',
    );
    try {
      final db = await DatabaseManager().database;

      // Get existing row from local SQLite
      final existing = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      print(
        '🔥 STREAK DEBUG: Existing streak record: ${existing.length} records',
      );
      if (existing.isNotEmpty) {
        print('🔥 STREAK DEBUG: Existing data: ${existing.first}');
      }

      final todayDateOnly = DateTime.now().toIso8601String().split('T')[0];
      final lastDate = lastEntryIso != null
          ? DateTime.parse(lastEntryIso).toIso8601String().split('T')[0]
          : todayDateOnly;
      print('🔥 STREAK DEBUG: lastDate: $lastDate');

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
        print('🔥 STREAK DEBUG: Creating new streak record: $newData');
        await db.insert('streaks', newData);
        print('🔥 STREAK DEBUG: New streak record created');
      } else {
        // Update existing record in local SQLite (preserve today_* fields)
        final longest = (existing.first['longest'] as int? ?? 0);
        final newLongest = computedStreak > longest ? computedStreak : longest;
        print(
          '🔥 STREAK DEBUG: Existing longest: $longest, new longest: $newLongest',
        );

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
        print('🔥 STREAK DEBUG: Updating streak record: $updateData');
        await db.update(
          'streaks',
          updateData,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print('🔥 STREAK DEBUG: Streak record updated');
      }

      // Queue sync to Supabase (debounced, 2s)
      print('🔥 STREAK DEBUG: Scheduling streak sync');
      _scheduleStreakSync(userId);
      print('🔥 STREAK DEBUG: _persistStreak END');
    } catch (e) {
      print('🔥 STREAK DEBUG: _persistStreak ERROR: $e');
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

  // Helper: Schedule debounced sync for streaks via RPC
  static void _scheduleStreakSync(String userId) {
    print('🔥 STREAK DEBUG: _scheduleStreakSync called - userId: $userId');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () async {
      print('🔥 STREAK DEBUG: _scheduleStreakSync timer fired - starting sync');
      try {
        final db = await DatabaseManager().database;
        final unsyncedStreaks = await db.query(
          'streaks',
          where: 'user_id = ? AND is_synced = 0',
          whereArgs: [userId],
          limit: 1,
        );
        print('🔥 STREAK DEBUG: Unsynced streaks: ${unsyncedStreaks.length}');

        if (unsyncedStreaks.isEmpty) {
          print('🔥 STREAK DEBUG: No unsynced streaks, returning');
          return;
        }

        final streak = unsyncedStreaks.first;
        print('🔥 STREAK DEBUG: Unsynced streak data: $streak');
        final streakData = {
          'current': streak['current'] ?? 0,
          'longest': streak['longest'] ?? 0,
          'last_entry_date': streak['last_entry_date'],
          'freeze_credits': streak['freeze_credits'] ?? 0,
          'grace_pieces_total': streak['grace_pieces_total'] ?? 0.0,
          'today_date': streak['today_date'],
          'today_diary': (streak['today_diary'] as int? ?? 0) == 1,
          'today_affirmations':
              (streak['today_affirmations'] as int? ?? 0) == 1,
          'today_gratitude': (streak['today_gratitude'] as int? ?? 0) == 1,
          'today_self_care_count': streak['today_self_care_count'] ?? 0,
          'today_grace_pieces': streak['today_grace_pieces'] ?? 0.0,
        };
        print('🔥 STREAK DEBUG: Syncing streak data to Supabase: $streakData');
        await _syncService.batchUpdateStreakData(
          userId: userId,
          streakData: streakData,
        );
        print('🔥 STREAK DEBUG: Streak sync completed');
      } catch (e) {
        print('🔥 STREAK DEBUG: _scheduleStreakSync ERROR: $e');
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRSYS158',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {'userId': userId},
          ),
        );
      }
    });
  }

  /// Calculate streak with grace system logic
  /// Uses habits_daily instead of entries table
  static Future<int> calculateStreakWithGrace(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    print('🔥 STREAK DEBUG: calculateStreakWithGrace START - userId: $userId');
    try {
      // Grace system always enabled (no setting in UI)
      // Calculate streak from today's habits_daily only
      final newStreak = await _calculateStreakFromTodayHabits(userId);
      print('🔥 STREAK DEBUG: Calculated new streak: $newStreak');

      // Get last entry date from habits_daily (most recent date with any task completed)
      final db = await DatabaseManager().database;
      final lastHabit = await db.query(
        'habits_daily',
        where:
            'user_id = ? AND (wrote_entry = 1 OR filled_affirmations = 1 OR filled_gratitude = 1 OR self_care_completed_count > 0)',
        whereArgs: [userId],
        orderBy: 'date DESC',
        limit: 1,
      );
      print(
        '🔥 STREAK DEBUG: Last habit with activity: ${lastHabit.length} records',
      );

      final lastEntryDate = lastHabit.isNotEmpty
          ? lastHabit.first['date'] as String?
          : null;
      print('🔥 STREAK DEBUG: lastEntryDate: $lastEntryDate');

      // Get grace system data
      final graceStatus = await GraceSystemService.getGraceStatus(
        userId,
        dataFetchService: dataFetchService,
      );
      final graceDaysAvailable = graceStatus?['grace_days_available'] ?? 0;
      print('🔥 STREAK DEBUG: Grace days available: $graceDaysAvailable');

      // Check if user completed any task today
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );
      print('🔥 STREAK DEBUG: Today habits: ${todayHabits.length} records');

      final completedToday =
          todayHabits.isNotEmpty &&
          ((todayHabits.first['wrote_entry'] as int? ?? 0) == 1 ||
              (todayHabits.first['filled_affirmations'] as int? ?? 0) == 1 ||
              (todayHabits.first['filled_gratitude'] as int? ?? 0) == 1 ||
              (todayHabits.first['self_care_completed_count'] as int? ?? 0) >
                  0);
      print('🔥 STREAK DEBUG: Completed today: $completedToday');

      // If user completed tasks today, update streak normally
      if (completedToday) {
        print(
          '🔥 STREAK DEBUG: User completed tasks today, persisting streak: $newStreak',
        );
        await _persistStreak(userId, newStreak, lastEntryIso: lastEntryDate);
        print(
          '🔥 STREAK DEBUG: calculateStreakWithGrace END - returning: $newStreak',
        );
        return newStreak;
      }

      // User didn't complete tasks today - check if we should use grace day
      if (lastEntryDate == null) {
        print(
          '🔥 STREAK DEBUG: No lastEntryDate, graceDaysAvailable: $graceDaysAvailable',
        );
        // No previous tasks
        if (graceDaysAvailable > 0) {
          print('🔥 STREAK DEBUG: Using grace day (no previous tasks)');
          await _useGraceDayForStreak(userId);
          final current = await _getCurrentStreak(userId);
          print(
            '🔥 STREAK DEBUG: calculateStreakWithGrace END - returning current: $current',
          );
          return current;
        }
        print('🔥 STREAK DEBUG: No grace days, persisting streak 0');
        await _persistStreak(userId, 0);
        print('🔥 STREAK DEBUG: calculateStreakWithGrace END - returning 0');
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
      print(
        '🔥 STREAK DEBUG: Gap check - lastDateOnly: ${lastDateOnly.toIso8601String().split('T')[0]}, daysDifference: $daysDifference',
      );

      if (daysDifference == 1) {
        // Missed exactly 1 day (yesterday)
        print('🔥 STREAK DEBUG: 1 day gap detected');
        if (graceDaysAvailable > 0) {
          print('🔥 STREAK DEBUG: Using grace day for 1 day gap');
          final currentStreak = await _getCurrentStreak(userId);
          await _useGraceDayForStreak(userId);
          print(
            '🔥 STREAK DEBUG: calculateStreakWithGrace END - returning current: $currentStreak',
          );
          return currentStreak; // Maintain current streak
        } else {
          print('🔥 STREAK DEBUG: No grace days, persisting streak 0');
          await _persistStreak(userId, 0);
          print('🔥 STREAK DEBUG: calculateStreakWithGrace END - returning 0');
          return 0;
        }
      } else if (daysDifference > 1) {
        // Missed multiple days
        print('🔥 STREAK DEBUG: Multiple days gap: $daysDifference');
        if (graceDaysAvailable >= daysDifference - 1) {
          print('🔥 STREAK DEBUG: Using ${daysDifference - 1} grace days');
          for (int i = 0; i < daysDifference - 1; i++) {
            await _useGraceDayForStreak(userId);
          }
          final current = await _getCurrentStreak(userId);
          print(
            '🔥 STREAK DEBUG: calculateStreakWithGrace END - returning current: $current',
          );
          return current;
        } else {
          print('🔥 STREAK DEBUG: Not enough grace days, persisting streak 0');
          await _persistStreak(userId, 0);
          print('🔥 STREAK DEBUG: calculateStreakWithGrace END - returning 0');
          return 0;
        }
      } else {
        // Same day or future (shouldn't happen)
        print(
          '🔥 STREAK DEBUG: Same day or future, persisting streak: $newStreak',
        );
        await _persistStreak(userId, newStreak, lastEntryIso: lastEntryDate);
        print(
          '🔥 STREAK DEBUG: calculateStreakWithGrace END - returning: $newStreak',
        );
        return newStreak;
      }
    } catch (e) {
      print('🔥 STREAK DEBUG: calculateStreakWithGrace ERROR: $e');
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
      print('🔥 STREAK DEBUG: Falling back to _calculateStreakFromTodayHabits');
      return await _calculateStreakFromTodayHabits(userId);
    }
  }

  /// Calculate streak on app launch (using today_* fields from streaks table)
  /// Fetches streaks only (1 call), populates local habits_daily from today_* fields
  static Future<void> calculateStreakOnAppLaunch(String userId) async {
    print(
      '🔥 STREAK DEBUG: calculateStreakOnAppLaunch START - userId: $userId',
    );
    try {
      final db = await DatabaseManager().database;
      final dataFetchService = DataFetchService(repository: DataRepository());

      // 1. Store app startup date (for all operations today)
      final appStartupDate = DateTime.now();
      final todayDateOnly = DateTime(
        appStartupDate.year,
        appStartupDate.month,
        appStartupDate.day,
      );
      final todayDateStr = todayDateOnly.toIso8601String().split('T')[0];
      print('🔥 STREAK DEBUG: Today date: $todayDateStr');

      // 2. Fetch streaks from Supabase (1 call)
      // Invalidate cache first to ensure we get fresh data from Supabase (not cached local)
      dataFetchService.invalidateStreaksCache(userId);
      // Also invalidate local DB's last_sync_at to force fresh fetch
      await db.update(
        'streaks',
        {'last_sync_at': null},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      print('🔥 STREAK DEBUG: Fetching streaks from Supabase...');
      final supabaseStreak = await dataFetchService.fetchStreaks(userId);
      print('🔥 STREAK DEBUG: Supabase streak data: $supabaseStreak');

      if (supabaseStreak == null) {
        // No streak data, initialize
        print('🔥 STREAK DEBUG: No Supabase streak data, initializing...');
        await _ensureStreaksRecordExists(userId);
        print(
          '🔥 STREAK DEBUG: calculateStreakOnAppLaunch END - initialized new record',
        );
        return;
      }

      // 3. Cache streaks in local DB (if not already cached)
      print('🔥 STREAK DEBUG: Checking local streak cache...');
      final localStreak = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      print(
        '🔥 STREAK DEBUG: Local streak exists: ${localStreak.isNotEmpty}, last_sync_at: ${localStreak.isNotEmpty ? localStreak.first['last_sync_at'] : 'null'}',
      );

      if (localStreak.isEmpty || localStreak.first['last_sync_at'] == null) {
        // Cache Supabase data locally
        print('🔥 STREAK DEBUG: Caching Supabase data to local DB...');
        final cacheData = {
          'user_id': userId,
          'current': supabaseStreak['current'] ?? 0,
          'longest': supabaseStreak['longest'] ?? 0,
          'last_entry_date': supabaseStreak['last_entry_date'],
          'freeze_credits': supabaseStreak['freeze_credits'] ?? 0,
          'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
          'today_date': supabaseStreak['today_date'],
          'today_diary': (supabaseStreak['today_diary'] ?? false) ? 1 : 0,
          'today_affirmations': (supabaseStreak['today_affirmations'] ?? false)
              ? 1
              : 0,
          'today_gratitude': (supabaseStreak['today_gratitude'] ?? false)
              ? 1
              : 0,
          'today_self_care_count': supabaseStreak['today_self_care_count'] ?? 0,
          'today_grace_pieces': supabaseStreak['today_grace_pieces'] ?? 0.0,
          'updated_at':
              supabaseStreak['updated_at'] ?? DateTime.now().toIso8601String(),
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        };
        print('🔥 STREAK DEBUG: Cache data: $cacheData');
        await db.insert(
          'streaks',
          cacheData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('🔥 STREAK DEBUG: Local cache updated');
      } else {
        // Cache exists but ensure today_* fields are synced from Supabase if they're null in local
        final localTodayDate = localStreak.first['today_date'] as String?;
        final supabaseTodayDate = supabaseStreak['today_date'] as String?;
        print(
          '🔥 STREAK DEBUG: Local cache exists, local today_date: $localTodayDate, Supabase today_date: $supabaseTodayDate',
        );

        if (localTodayDate == null && supabaseTodayDate != null) {
          print(
            '🔥 STREAK DEBUG: Local today_date is null but Supabase has value, updating local today_* fields',
          );
          await db.update(
            'streaks',
            {
              'today_date': supabaseTodayDate,
              'today_diary': (supabaseStreak['today_diary'] ?? false) ? 1 : 0,
              'today_affirmations':
                  (supabaseStreak['today_affirmations'] ?? false) ? 1 : 0,
              'today_gratitude': (supabaseStreak['today_gratitude'] ?? false)
                  ? 1
                  : 0,
              'today_self_care_count':
                  supabaseStreak['today_self_care_count'] ?? 0,
              'today_grace_pieces': supabaseStreak['today_grace_pieces'] ?? 0.0,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          print('🔥 STREAK DEBUG: Local today_* fields updated from Supabase');
        } else {
          print(
            '🔥 STREAK DEBUG: Local cache already exists, skipping cache update',
          );
        }
      }

      // 4. Check if today_date matches today
      final streakTodayDate = supabaseStreak['today_date'] as String?;
      final isNewDay = streakTodayDate != todayDateStr;
      print(
        '🔥 STREAK DEBUG: Streak today_date: $streakTodayDate, App today: $todayDateStr, isNewDay: $isNewDay',
      );

      if (isNewDay) {
        // New day - clear local habits_daily and reset today_* fields
        print(
          '🔥 STREAK DEBUG: NEW DAY detected - clearing habits_daily and resetting today_* fields',
        );
        await db.delete(
          'habits_daily',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print('🔥 STREAK DEBUG: Deleted all habits_daily records for user');

        // Reset today_* fields in local streaks
        final resetData = {
          'today_date': todayDateStr,
          'today_diary': 0,
          'today_affirmations': 0,
          'today_gratitude': 0,
          'today_self_care_count': 0,
          'today_grace_pieces': 0.0,
          'is_synced': 0,
        };
        print(
          '🔥 STREAK DEBUG: Resetting local streaks today_* fields: $resetData',
        );
        await db.update(
          'streaks',
          resetData,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print('🔥 STREAK DEBUG: Local streaks updated with reset data');

        // Push reset to Supabase via RPC
        final syncData = {
          'current': supabaseStreak['current'] ?? 0,
          'longest': supabaseStreak['longest'] ?? 0,
          'last_entry_date': supabaseStreak['last_entry_date'],
          'freeze_credits': supabaseStreak['freeze_credits'] ?? 0,
          'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
          'today_date': todayDateStr,
          'today_diary': false,
          'today_affirmations': false,
          'today_gratitude': false,
          'today_self_care_count': 0,
          'today_grace_pieces': 0.0,
        };
        print('🔥 STREAK DEBUG: Syncing reset data to Supabase: $syncData');
        await _syncService.batchUpdateStreakData(
          userId: userId,
          streakData: syncData,
        );
        print('🔥 STREAK DEBUG: Reset data synced to Supabase');
      } else {
        // Same day - populate local habits_daily from streaks.today_* fields
        print(
          '🔥 STREAK DEBUG: SAME DAY - populating habits_daily from streaks.today_*',
        );
        final todayHabits = await db.query(
          'habits_daily',
          where: 'user_id = ? AND date = ?',
          whereArgs: [userId, todayDateStr],
          limit: 1,
        );
        print(
          '🔥 STREAK DEBUG: Existing habits_daily records: ${todayHabits.length}',
        );

        if (todayHabits.isEmpty) {
          // Create today's habits_daily record from streaks.today_* fields
          final uuid = const Uuid().v4();
          final habitData = {
            'id': uuid,
            'user_id': userId,
            'date': todayDateStr,
            'wrote_entry': (supabaseStreak['today_diary'] ?? false) ? 1 : 0,
            'filled_affirmations':
                (supabaseStreak['today_affirmations'] ?? false) ? 1 : 0,
            'filled_gratitude': (supabaseStreak['today_gratitude'] ?? false)
                ? 1
                : 0,
            'self_care_completed_count':
                supabaseStreak['today_self_care_count'] ?? 0,
            'grace_pieces_earned': supabaseStreak['today_grace_pieces'] ?? 0.0,
            'is_synced': 1,
            'last_sync_at': DateTime.now().toIso8601String(),
          };
          print('🔥 STREAK DEBUG: Creating habits_daily record: $habitData');
          await db.insert('habits_daily', habitData);
          print('🔥 STREAK DEBUG: habits_daily record created');
        } else {
          print(
            '🔥 STREAK DEBUG: habits_daily record already exists, skipping creation',
          );
        }
      }

      // 5. Check for gaps and handle streak
      final lastEntryDateStr = supabaseStreak['last_entry_date'] as String?;
      final currentStreak = supabaseStreak['current'] as int? ?? 0;
      print(
        '🔥 STREAK DEBUG: last_entry_date: $lastEntryDateStr, current: $currentStreak',
      );

      if (lastEntryDateStr == null) {
        // No last_entry_date - only recalculate if current streak is 0 (new user)
        // If current > 0, trust the Supabase value (might be manually set)
        print(
          '🔥 STREAK DEBUG: last_entry_date is null, current: $currentStreak',
        );
        if (currentStreak == 0) {
          print('🔥 STREAK DEBUG: Recalculating streak (new user)');
          await recalculateStreak(userId, dataFetchService: dataFetchService);
        } else {
          print(
            '🔥 STREAK DEBUG: Trusting Supabase value (manually set), skipping recalculation',
          );
        }
        print(
          '🔥 STREAK DEBUG: calculateStreakOnAppLaunch END - no last_entry_date',
        );
        return;
      }

      final lastEntryDate = DateTime.parse(lastEntryDateStr);
      final lastDateOnly = DateTime(
        lastEntryDate.year,
        lastEntryDate.month,
        lastEntryDate.day,
      );
      final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;
      print(
        '🔥 STREAK DEBUG: lastDateOnly: ${lastDateOnly.toIso8601String().split('T')[0]}, daysDiff: $daysDiff',
      );

      if (daysDiff == 0) {
        // Same day - trust current streak from Supabase (don't recalculate)
        // BUT: If current > longest, update longest to match current (handles manual updates)
        final currentStreak = supabaseStreak['current'] as int? ?? 0;
        final longestStreak = supabaseStreak['longest'] as int? ?? 0;

        if (currentStreak > longestStreak) {
          print(
            '🔥 STREAK DEBUG: current ($currentStreak) > longest ($longestStreak), updating longest',
          );
          // Update longest to match current
          await db.update(
            'streaks',
            {
              'longest': currentStreak,
              'updated_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );

          // Sync updated longest to Supabase
          final syncData = {
            'current': currentStreak,
            'longest': currentStreak, // Updated longest
            'last_entry_date': supabaseStreak['last_entry_date'],
            'freeze_credits': supabaseStreak['freeze_credits'] ?? 0,
            'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
            'today_date': supabaseStreak['today_date'],
            'today_diary': supabaseStreak['today_diary'] ?? false,
            'today_affirmations': supabaseStreak['today_affirmations'] ?? false,
            'today_gratitude': supabaseStreak['today_gratitude'] ?? false,
            'today_self_care_count':
                supabaseStreak['today_self_care_count'] ?? 0,
            'today_grace_pieces': supabaseStreak['today_grace_pieces'] ?? 0.0,
          };
          print(
            '🔥 STREAK DEBUG: Syncing updated longest to Supabase: $syncData',
          );
          await _syncService.batchUpdateStreakData(
            userId: userId,
            streakData: syncData,
          );
          print('🔥 STREAK DEBUG: Longest updated and synced to Supabase');
        } else {
          print(
            '🔥 STREAK DEBUG: Same day, trusting Supabase streak, skipping recalculation',
          );
        }
        print('🔥 STREAK DEBUG: calculateStreakOnAppLaunch END - same day');
        return;
      }

      if (daysDiff > 0) {
        // Gap detected - handle with grace days
        final graceDays = supabaseStreak['freeze_credits'] as int? ?? 0;
        print(
          '🔥 STREAK DEBUG: Gap detected: $daysDiff days, grace days available: $graceDays',
        );

        if (daysDiff == 1 && graceDays > 0) {
          print('🔥 STREAK DEBUG: 1 day gap, using grace day');
          await GraceSystemService.useGraceDay(
            userId,
            dataFetchService: dataFetchService,
          );
          await recalculateStreak(userId, dataFetchService: dataFetchService);
        } else if (daysDiff > 1) {
          if (graceDays >= daysDiff - 1) {
            print(
              '🔥 STREAK DEBUG: $daysDiff days gap, using ${daysDiff - 1} grace days',
            );
            for (int i = 0; i < daysDiff - 1; i++) {
              await GraceSystemService.useGraceDay(
                userId,
                dataFetchService: dataFetchService,
              );
            }
            await recalculateStreak(userId, dataFetchService: dataFetchService);
          } else {
            // Reset streak
            print(
              '🔥 STREAK DEBUG: Not enough grace days, resetting streak to 0',
            );
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
            final resetSyncData = {
              'current': 0,
              'longest': supabaseStreak['longest'] ?? 0,
              'last_entry_date': null,
              'freeze_credits': graceDays,
              'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
              'today_date': todayDateStr,
              'today_diary': false,
              'today_affirmations': false,
              'today_gratitude': false,
              'today_self_care_count': 0,
              'today_grace_pieces': 0.0,
            };
            print(
              '🔥 STREAK DEBUG: Syncing reset streak to Supabase: $resetSyncData',
            );
            await _syncService.batchUpdateStreakData(
              userId: userId,
              streakData: resetSyncData,
            );
          }
        }
      }
      print('🔥 STREAK DEBUG: calculateStreakOnAppLaunch END - completed');
    } catch (e) {
      print('🔥 STREAK DEBUG: calculateStreakOnAppLaunch ERROR: $e');
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS162',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId},
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

  /// Recalculate and update streak after entry save
  /// Uses habits_daily instead of entries table
  /// Uses local-first approach: reads from local SQLite, syncs to Supabase via RPC (debounced)
  static Future<void> recalculateStreak(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    if (_recalcInProgress.contains(userId)) {
      _recalcQueued.add(userId);
      return;
    }

    _recalcInProgress.add(userId);
    print('🔥 STREAK DEBUG: recalculateStreak START - userId: $userId');
    try {
      final db = await DatabaseManager().database;

      // Check if recalculation is needed (recalculate if date changed)
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      print('🔥 STREAK DEBUG: Existing streaks: ${streaks.length}');

      if (streaks.isNotEmpty) {
        final lastEntryDateStr = streaks.first['last_entry_date'] as String?;
        print('🔥 STREAK DEBUG: last_entry_date: $lastEntryDateStr');
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
            print(
              '🔥 STREAK DEBUG: lastDateOnly: ${lastDateOnly.toIso8601String().split('T')[0]}, todayDateOnly: ${todayDateOnly.toIso8601String().split('T')[0]}',
            );

            // Recalculate if last_entry_date is before today (date changed)
            // This fixes the bug where daysDiff = 1 (yesterday) was incorrectly skipped
            if (lastDateOnly.isAtSameMomentAs(todayDateOnly) ||
                lastDateOnly.isAfter(todayDateOnly)) {
              // Same day or future date, no need to recalculate
              print(
                '🔥 STREAK DEBUG: Same day or future, skipping recalculation',
              );
              return;
            }
            // Date changed (lastDateOnly is before todayDateOnly), continue to recalculate
            print(
              '🔥 STREAK DEBUG: Date changed, proceeding with recalculation',
            );
          } catch (e) {
            print('🔥 STREAK DEBUG: Date parsing error: $e');
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

      // Calculate streak from habits_daily (not entries table)
      print('🔥 STREAK DEBUG: Calling calculateStreakWithGrace');
      await calculateStreakWithGrace(
        userId,
        dataFetchService: dataFetchService,
      );
      print('🔥 STREAK DEBUG: recalculateStreak END');
    } catch (e) {
      print('🔥 STREAK DEBUG: recalculateStreak ERROR: $e');
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
        Future.microtask(() {
          recalculateStreak(userId, dataFetchService: dataFetchService);
        });
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

      // Queue sync to Supabase (debounced, 2s)
      _scheduleStreakSync(userId);
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
  static Future<int> _getCurrentStreak(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    try {
      final db = await DatabaseManager().database;

      if (dataFetchService != null) {
        // Use cached fetchStreaks (now reconnected)
        final response = await dataFetchService.fetchStreaks(userId);
        return (response?['current'] as num?)?.toInt() ?? 0;
      } else {
        // Fallback: read from local SQLite
        final streaks = await db.query(
          'streaks',
          columns: ['current'],
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1,
        );

        if (streaks.isNotEmpty) {
          return streaks.first['current'] as int? ?? 0;
        }
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch user preferences
  static Future<DataResult> _fetchUserPreferences(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    try {
      Map<String, dynamic>? response;

      if (dataFetchService != null) {
        // Use cached fetchUserSettings
        response = await dataFetchService.fetchUserSettings(userId);
      } else {
        // Fallback to direct query
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
