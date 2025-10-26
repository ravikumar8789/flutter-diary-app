import 'package:supabase_flutter/supabase_flutter.dart';

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
        return DataResult(
          success: false,
          error: 'Failed to create user: $createError',
        );
      }
    }
  }

  /// Fetch user statistics (entries, streak, etc.)
  static Future<DataResult> _fetchUserStats(String userId) async {
    try {
      // Get diary entries count
      final entriesResponse = await _supabase
          .from('diary_entries')
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

  /// Calculate streak with compassion logic
  static Future<int> calculateStreakWithCompassion(
    String userId,
    List entries,
  ) async {
    try {
      // Get compassion settings
      final compassionSettings = await _supabase
          .from('user_settings')
          .select('streak_compassion_enabled, grace_period_days')
          .eq('user_id', userId)
          .single();

      final compassionEnabled =
          compassionSettings['streak_compassion_enabled'] ?? false;
      final gracePeriodDays = compassionSettings['grace_period_days'] ?? 1;

      if (!compassionEnabled) {
        // Use strict streak calculation
        return await _calculateStreak(entries);
      }

      // Get current streak data
      final streakData = await _supabase
          .from('streaks')
          .select('current, freeze_credits, grace_period_active')
          .eq('user_id', userId)
          .single();

      final currentStreak = streakData['current'] ?? 0;
      final freezeCredits = streakData['freeze_credits'] ?? 0;
      final gracePeriodActive = streakData['grace_period_active'] ?? false;

      if (entries.isEmpty) {
        // No entries, check if grace period can be used
        if (freezeCredits > 0 && !gracePeriodActive) {
          // Use freeze credit to maintain streak
          await _useFreezeCreditForStreak(userId, currentStreak);
          return currentStreak;
        }
        return 0;
      }

      // Calculate days since last entry
      final lastEntryDate = DateTime.parse(entries.first['created_at']);
      final daysSinceLastEntry = DateTime.now()
          .difference(lastEntryDate)
          .inDays;

      if (daysSinceLastEntry == 0) {
        // Entry written today, maintain streak
        return currentStreak;
      } else if (daysSinceLastEntry <= gracePeriodDays) {
        // Within grace period, check if freeze credit can be used
        if (freezeCredits > 0 && !gracePeriodActive) {
          await _useFreezeCreditForStreak(userId, currentStreak);
          return currentStreak;
        }
        // No freeze credit available, break streak
        return 0;
      } else {
        // Grace period exceeded, break streak
        return 0;
      }
    } catch (e) {
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
      print('Error using freeze credit: $e');
    }
  }

  /// Fetch user preferences
  static Future<DataResult> _fetchUserPreferences(String userId) async {
    try {
      final response = await _supabase
          .from('user_preferences')
          .select('*')
          .eq('user_id', userId)
          .single();

      return DataResult(success: true, data: response);
    } catch (e) {
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
