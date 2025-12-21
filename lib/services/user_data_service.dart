import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_logging_service.dart';
import 'timezone_service.dart';

class UserDataService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all user data including profile, stats, and preferences
  static Future<UserDataResult> fetchUserData() async {
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
      final profileData = await _fetchUserProfile(user.id);
      if (!profileData.success) {
        return UserDataResult(
          success: false,
          error: profileData.error,
          userData: null,
        );
      }

      // Fetch user statistics
      final statsData = await _fetchUserStats(user.id);

      // Fetch user preferences
      final preferencesData = await _fetchUserPreferences(user.id);

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
        errorCode: 'ERRSYS117',
        errorMessage: 'User data fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'operation': 'fetch_user_data'},
      );
      return UserDataResult(
        success: false,
        error: 'Failed to fetch user data: $e',
        userData: null,
      );
    }
  }

  /// Fetch user profile information from users table
  static Future<DataResult> _fetchUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      // Case 1: User exists
      if (response != null) {
        // Check if timezone is null and update it
        if (response['timezone'] == null) {
          // Update timezone in background (don't await)
          TimezoneService.initializeUserTimezone(userId).catchError((e) {
            ErrorLoggingService.logLowError(
              errorCode: 'ERRSYS165',
              errorMessage: 'Timezone update failed for existing user: ${e.toString()}',
              stackTrace: StackTrace.current.toString(),
              errorContext: {
                'user_id': userId,
                'operation': 'update_existing_user_timezone',
              },
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
          return await _retryFetchUser(userId);
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
  static Future<DataResult> _retryFetchUser(String userId) async {
    try {
      final retryResponse = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (retryResponse != null) {
        return DataResult(success: true, data: retryResponse);
      }
      // Still null after retry - log as warning
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS119',
        errorMessage: 'User not found after duplicate key retry',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'retry_fetch_after_duplicate',
        },
      );
      return DataResult(success: false, error: 'User not found', data: null);
    } catch (retryError) {
      await _logUserFetchError(retryError, userId, 'retry_fetch_failed');
      return DataResult(success: false, error: 'Retry fetch failed', data: null);
    }
  }

  /// Log user fetch errors with detailed context
  static Future<void> _logUserFetchError(
    dynamic error,
    String userId,
    String operation,
  ) async {
    final errorString = error.toString();
    final isNetworkError = errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('connection');
    final isDbError = errorString.contains('database') ||
        errorString.contains('PostgrestException');

    // Use ERRSYS121 for retry fetch failures, ERRSYS118 for initial fetch failures
    final errorCode = operation == 'retry_fetch_failed' ? 'ERRSYS121' : 'ERRSYS118';
    final errorMessage = operation == 'retry_fetch_failed'
        ? 'User retry fetch failed: $errorString'
        : 'User profile fetch failed: $errorString';

    await ErrorLoggingService.logHighError(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: StackTrace.current.toString(),
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
      errorCode: isDuplicateKey ? 'ERRSYS119' : 'ERRSYS120',
      errorMessage: 'User creation failed: $errorString',
      stackTrace: StackTrace.current.toString(),
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
    );
  }

  /// Fetch user statistics (entries, streak, etc.)
  static Future<DataResult> _fetchUserStats(String userId) async {
    try {
      // Get diary entries count
      final entriesResponse = await _supabase
          .from('entries')
          .select('id, created_at')
          .eq('user_id', userId);

      final entries = entriesResponse as List;
      final entriesCount = entries.length;

      // Calculate current streak
      final streak = await _calculateStreak(entries);

      // Persist streak counters to DB so Home can read from streaks table
      await _persistStreak(
        userId,
        streak,
        lastEntryIso: entries.isNotEmpty ? entries.first['created_at'] : null,
      );

      // Get days since first entry
      final firstEntry = entries.isNotEmpty
          ? DateTime.parse(entries.first['created_at'])
          : DateTime.now();
      final daysSinceFirst = DateTime.now().difference(firstEntry).inDays + 1;

      final stats = {
        'entries_count': entriesCount,
        'current_streak': streak,
        'days_active': daysSinceFirst,
        'last_entry_date': entries.isNotEmpty
            ? entries.first['created_at']
            : null,
      };

      return DataResult(success: true, data: stats);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS119',
        errorMessage: 'User stats fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId, 'operation': 'fetch_user_stats'},
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

  /// Calculate current writing streak with compassion logic
  static Future<int> _calculateStreak(List entries) async {
    if (entries.isEmpty) return 0;

    // Sort entries by date (newest first)
    entries.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );

    int streak = 0;
    DateTime currentDate = DateTime.now();

    for (var entry in entries) {
      final entryDate = DateTime.parse(entry['created_at']);
      final daysDifference = currentDate.difference(entryDate).inDays;

      if (daysDifference == streak) {
        streak++;
        currentDate = entryDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Persist computed streak into public.streaks (current/longest/last_entry_date)
  static Future<void> _persistStreak(
    String userId,
    int computedStreak, {
    String? lastEntryIso,
  }) async {
    try {
      // Get existing row (if any)
      final existing = await _supabase
          .from('streaks')
          .select('longest')
          .eq('user_id', userId)
          .maybeSingle();

      final todayDateOnly = DateTime.now().toIso8601String().split('T')[0];
      final lastDate = lastEntryIso != null
          ? DateTime.parse(lastEntryIso).toIso8601String().split('T')[0]
          : todayDateOnly;

      if (existing == null) {
        await _supabase.from('streaks').insert({
          'user_id': userId,
          'current': computedStreak,
          'longest': computedStreak,
          'last_entry_date': lastDate,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return;
      }

      final longest = (existing['longest'] ?? 0) as int;
      final newLongest = computedStreak > longest ? computedStreak : longest;

      await _supabase
          .from('streaks')
          .update({
            'current': computedStreak,
            'longest': newLongest,
            'last_entry_date': lastDate,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRSYS156',
        errorMessage: 'Persist streak failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'persist_streak',
          'computed': computedStreak,
        },
      );
    }
  }

  /// Calculate streak with grace system logic
  static Future<int> calculateStreakWithGrace(
    String userId,
    List entries,
  ) async {
    try {
      // Get grace system settings
      final graceSettings = await _supabase
          .from('user_settings')
          .select('grace_system_enabled')
          .eq('user_id', userId)
          .single();

      final graceSystemEnabled = graceSettings['grace_system_enabled'] ?? true;

      if (!graceSystemEnabled) {
        // Use strict streak calculation
        return await _calculateStreak(entries);
      }

      // Get today's date in app timezone
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Check if user wrote today (has diary entry today)
      final todayHabits = await _supabase
          .from('habits_daily')
          .select('wrote_entry')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      final wroteToday = todayHabits?['wrote_entry'] == true;

      // Get grace system data
      final graceData = await _supabase
          .rpc(
            'calculate_grace_days_from_habits',
            params: {
              'p_user_id': userId,
              'p_date': today, // Pass app's current date
            },
          )
          .single();

      final graceDaysAvailable = graceData['grace_days_available'] ?? 0;

      // If user wrote today, calculate normal streak
      if (wroteToday && entries.isNotEmpty) {
        final streak = await _calculateStreak(entries);
        await _persistStreak(
          userId,
          streak,
          lastEntryIso: entries.first['created_at'],
        );
        return streak;
      }

      // User didn't write today - check if we should use grace day
      if (entries.isEmpty) {
        // No entries at all
        if (graceDaysAvailable > 0) {
          // Use grace day to maintain streak
          await _useGraceDayForStreak(userId);
          return await _getCurrentStreak(userId);
        }
        // No grace days, reset streak
        await _persistStreak(userId, 0);
        return 0;
      }

      // Has entries but didn't write today
      final lastEntryDate = DateTime.parse(entries.first['created_at']);
      final lastEntryDateOnly = lastEntryDate.toIso8601String().split('T')[0];
      final todayDate = DateTime.parse(today);
      final lastDate = DateTime.parse(lastEntryDateOnly);
      final daysDifference = todayDate.difference(lastDate).inDays;

      if (daysDifference == 1) {
        // Missed exactly 1 day (yesterday)
        if (graceDaysAvailable > 0) {
          // Use grace day to maintain streak
          final currentStreak = await _getCurrentStreak(userId);
          await _useGraceDayForStreak(userId);
          return currentStreak; // Maintain current streak
        } else {
          // No grace days, reset streak
          await _persistStreak(userId, 0);
          return 0;
        }
      } else if (daysDifference > 1) {
        // Missed multiple days
        if (graceDaysAvailable >= daysDifference - 1) {
          // Use multiple grace days if available
          for (int i = 0; i < daysDifference - 1; i++) {
            await _useGraceDayForStreak(userId);
          }
          final currentStreak = await _getCurrentStreak(userId);
          return currentStreak;
        } else {
          // Not enough grace days, reset streak
          await _persistStreak(userId, 0);
          return 0;
        }
      } else {
        // daysDifference == 0 shouldn't happen if wroteToday is false, but handle it
        final streak = await _calculateStreak(entries);
        await _persistStreak(userId, streak, lastEntryIso: entries.first['created_at']);
        return streak;
      }
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS119',
        errorMessage: 'Streak calculation with grace failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'operation': 'calculate_streak_with_grace'},
      );
      // Fallback to regular streak calculation
      return await _calculateStreak(entries);
    }
  }

  /// Use freeze credit to maintain streak
  static Future<void> _useFreezeCreditForStreak(
    String userId,
    int streakMaintained,
  ) async {
    try {
      await _supabase.from('streak_freeze_usage').insert({
        'user_id': userId,
        'reason': 'missed_day',
        'streak_maintained': streakMaintained,
        'grace_period_days': 1,
      });
    } catch (e) {
      // Log error but don't throw
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRSYS119',
        errorMessage: 'Freeze credit usage failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId, 'operation': 'use_freeze_credit'},
      );
    }
  }

  /// Use grace day to maintain streak
  static Future<void> _useGraceDayForStreak(String userId) async {
    try {
      // Get current streak
      final currentStreak = await _getCurrentStreak(userId);

      // Record grace day usage
      await _supabase.from('streak_freeze_usage').insert({
        'user_id': userId,
        'reason': 'grace_day_used',
        'streak_maintained': currentStreak,
        'grace_day_used': true,
        'grace_period_days': 1,
      });

      // Update streaks table (decrease grace days)
      final currentStreakData = await _supabase
          .from('streaks')
          .select('freeze_credits')
          .eq('user_id', userId)
          .single();

      final currentGraceDays = currentStreakData['freeze_credits'] ?? 0;

      await _supabase
          .from('streaks')
          .update({
            'freeze_credits': currentGraceDays - 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS121',
        errorMessage: 'Failed to use grace day: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId, 'operation': 'use_grace_day'},
      );
    }
  }

  /// Get current streak from database
  static Future<int> _getCurrentStreak(String userId) async {
    try {
      final response = await _supabase
          .from('streaks')
          .select('current')
          .eq('user_id', userId)
          .single();
      return response['current'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch user preferences
  static Future<DataResult> _fetchUserPreferences(String userId) async {
    try {
      final response = await _supabase
          .from('user_settings')
          .select('*')
          .eq('user_id', userId)
          .single();

      return DataResult(success: true, data: response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS120',
        errorMessage: 'User preferences fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'fetch_user_preferences',
        },
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
