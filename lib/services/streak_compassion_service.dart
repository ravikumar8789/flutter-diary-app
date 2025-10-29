import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_logging_service.dart';

class StreakCompassionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get user's streak compassion settings
  static Future<Map<String, dynamic>?> getUserCompassionSettings(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('user_settings')
          .select(
            'streak_compassion_enabled, grace_period_days, max_freeze_credits, freeze_credits_earned',
          )
          .eq('user_id', userId);

      // Handle case when no user_settings record exists
      if (response.isNotEmpty) {
        return response.first;
      } else {
        // Return default values if no settings record exists
        return {
          'streak_compassion_enabled': true, // Default from schema
          'grace_period_days': 1,
          'max_freeze_credits': 3,
          'freeze_credits_earned': 0,
        };
      }
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA101',
        errorMessage: 'Failed to get user compassion settings: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionService.getUserCompassionSettings',
        },
      );
      return null;
    }
  }

  /// Update user's streak compassion settings
  static Future<bool> updateCompassionSettings({
    required String userId,
    required bool compassionEnabled,
    int? gracePeriodDays,
    int? maxFreezeCredits,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'streak_compassion_enabled': compassionEnabled,
      };

      if (gracePeriodDays != null) {
        updateData['grace_period_days'] = gracePeriodDays;
      }
      if (maxFreezeCredits != null) {
        updateData['max_freeze_credits'] = maxFreezeCredits;
      }

      // Check if user_settings record exists first
      final existingRecord = await _supabase
          .from('user_settings')
          .select('user_id, streak_compassion_enabled')
          .eq('user_id', userId);

      if (existingRecord.isNotEmpty) {
        // Record exists, update it
        await _supabase
            .from('user_settings')
            .update(updateData)
            .eq('user_id', userId);
      } else {
        // No record exists, create one
        final insertData = Map<String, dynamic>.from(updateData);
        insertData['user_id'] = userId;
        insertData['reminder_enabled'] = true;
        insertData['privacy_lock_enabled'] = false;
        insertData['export_format_default'] = 'json';
        insertData['grace_period_days'] = gracePeriodDays ?? 1;
        insertData['max_freeze_credits'] = maxFreezeCredits ?? 3;
        insertData['freeze_credits_earned'] = 0;

        await _supabase.from('user_settings').insert(insertData);
      }

      return true;
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA102',
        errorMessage: 'Failed to update compassion settings: $e',
        errorContext: {
          'userId': userId,
          'compassionEnabled': compassionEnabled,
          'gracePeriodDays': gracePeriodDays,
          'maxFreezeCredits': maxFreezeCredits,
          'service': 'StreakCompassionService.updateCompassionSettings',
        },
      );
      return false;
    }
  }

  /// Get user's current streak with compassion logic
  static Future<Map<String, dynamic>?> getStreakWithCompassion(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .rpc(
            'calculate_streak_with_compassion',
            params: {'p_user_id': userId},
          )
          .single();

      return response;
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA103',
        errorMessage: 'Failed to get streak with compassion: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionService.getStreakWithCompassion',
        },
      );
      return null;
    }
  }

  /// Use a freeze credit to maintain streak
  static Future<bool> useFreezeCredit({
    required String userId,
    required String reason,
    required int streakMaintained,
  }) async {
    try {
      // Insert freeze usage record
      await _supabase.from('streak_freeze_usage').insert({
        'user_id': userId,
        'reason': reason,
        'streak_maintained': streakMaintained,
        'grace_period_days': 1,
      });

      return true;
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA104',
        errorMessage: 'Failed to use freeze credit: $e',
        errorContext: {
          'userId': userId,
          'reason': reason,
          'streakMaintained': streakMaintained,
          'service': 'StreakCompassionService.useFreezeCredit',
        },
      );
      return false;
    }
  }

  /// Get freeze credit usage history
  static Future<List<Map<String, dynamic>>> getFreezeUsageHistory(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('streak_freeze_usage')
          .select('*')
          .eq('user_id', userId)
          .order('used_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA105',
        errorMessage: 'Failed to get freeze usage history: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionService.getFreezeUsageHistory',
        },
      );
      return [];
    }
  }

  /// Earn freeze credits through consistent writing
  static Future<bool> earnFreezeCredits({
    required String userId,
    required int creditsEarned,
  }) async {
    try {
      await _supabase
          .from('user_settings')
          .update({
            'freeze_credits_earned': creditsEarned,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return true;
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA106',
        errorMessage: 'Failed to earn freeze credits: $e',
        errorContext: {
          'userId': userId,
          'creditsEarned': creditsEarned,
          'service': 'StreakCompassionService.earnFreezeCredits',
        },
      );
      return false;
    }
  }

  /// Check if user can use freeze credit
  static Future<bool> canUseFreezeCredit(String userId) async {
    try {
      final streakData = await _supabase
          .from('streaks')
          .select('freeze_credits, grace_period_active')
          .eq('user_id', userId)
          .single();

      final settingsData = await _supabase
          .from('user_settings')
          .select('streak_compassion_enabled')
          .eq('user_id', userId)
          .single();

      return (streakData['freeze_credits'] ?? 0) > 0 &&
          (settingsData['streak_compassion_enabled'] ?? false) &&
          !(streakData['grace_period_active'] ?? false);
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA107',
        errorMessage: 'Failed to check freeze credit availability: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionService.canUseFreezeCredit',
        },
      );
      return false;
    }
  }

  /// Reset grace period when user writes entry
  static Future<bool> resetGracePeriod(String userId) async {
    try {
      await _supabase
          .from('streaks')
          .update({
            'grace_period_active': false,
            'grace_period_expires_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return true;
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA108',
        errorMessage: 'Failed to reset grace period: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionService.resetGracePeriod',
        },
      );
      return false;
    }
  }

  /// Get compassion statistics for user
  static Future<Map<String, dynamic>?> getCompassionStats(String userId) async {
    try {
      // Get streak data - handle case when no streak record exists
      final streakResponse = await _supabase
          .from('streaks')
          .select('freeze_credits, compassion_used_count, grace_period_active')
          .eq('user_id', userId);

      final streakData = streakResponse.isNotEmpty
          ? streakResponse.first
          : null;

      // Get settings data - handle case when no settings record exists
      final settingsResponse = await _supabase
          .from('user_settings')
          .select(
            'grace_period_days, max_freeze_credits, freeze_credits_earned',
          )
          .eq('user_id', userId);
      final settingsData = settingsResponse.isNotEmpty
          ? settingsResponse.first
          : null;

      final result = {
        'freeze_credits_remaining': streakData?['freeze_credits'] ?? 0,
        'compassion_used_count': streakData?['compassion_used_count'] ?? 0,
        'grace_period_active': streakData?['grace_period_active'] ?? false,
        'grace_period_days': settingsData?['grace_period_days'] ?? 1,
        'max_freeze_credits': settingsData?['max_freeze_credits'] ?? 3,
        'freeze_credits_earned': settingsData?['freeze_credits_earned'] ?? 0,
      };

      return result;
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA109',
        errorMessage: 'Failed to get compassion stats: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionService.getCompassionStats',
        },
      );
      return null;
    }
  }
}
