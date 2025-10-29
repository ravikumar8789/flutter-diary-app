import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_logging_service.dart';

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
          .single();

      return DataResult(success: true, data: response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS118',
        errorMessage: 'User profile fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId, 'operation': 'fetch_user_profile'},
      );
      // If user doesn't exist in users table, create a basic one
      try {
        final user = _supabase.auth.currentUser!;
        final displayName =
            user.userMetadata?['display_name'] ??
            user.email?.split('@')[0] ??
            'User';

        final newUser = {
          'id': userId,
          'email': user.email,
          'display_name': displayName,
          'avatar_url': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('users').insert(newUser);
        return DataResult(success: true, data: newUser);
      } catch (createError) {
        // Log create user error
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS118',
          errorMessage: 'User creation failed: ${createError.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {'user_id': userId, 'operation': 'create_user'},
        );
        return DataResult(
          success: false,
          error: 'Failed to create user: $createError',
          data: null,
        );
      }
    }
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

      // Get grace system data from habits_daily
      final today = DateTime.now().toIso8601String().split('T')[0];
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

      // Calculate days since last entry
      if (entries.isEmpty) {
        if (graceDaysAvailable > 0) {
          // Use grace day to maintain streak
          await _useGraceDayForStreak(userId);
          return await _getCurrentStreak(userId);
        }
        return 0;
      }

      final lastEntryDate = DateTime.parse(entries.first['created_at']);
      final daysSinceLastEntry = DateTime.now()
          .difference(lastEntryDate)
          .inDays;

      if (daysSinceLastEntry == 0) {
        // Entry written today, maintain streak
        return await _getCurrentStreak(userId);
      } else if (daysSinceLastEntry == 1 && graceDaysAvailable > 0) {
        // Missed yesterday, use grace day
        await _useGraceDayForStreak(userId);
        return await _getCurrentStreak(userId);
      } else {
        // Multiple days missed or no grace days, break streak
        return 0;
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
  final DateTime createdAt;
  final DateTime lastLoginAt;

  UserData({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.stats,
    this.preferences,
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
