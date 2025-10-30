import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_logging_service.dart';
import 'notification_service.dart';

class UserPreferenceSyncService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Update notification settings in user_settings table
  static Future<void> syncNotificationSettingsToCloud(
    NotificationSettings settings,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final timeString = _formatTimeOfDay(settings.morningTime);
      final payload = {
        'user_id': userId,
        'reminder_enabled': settings.notificationsEnabled,
        'reminder_time_local': timeString,
        'reminder_days': settings.activeDays,
      };

      await _supabase.from('user_settings').upsert(
            payload,
            onConflict: 'user_id',
          );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS134',
        errorMessage:
            'Settings save failed (cloud notification settings): ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'operation': 'sync_notification_settings',
          'active_days': settings.activeDays,
          'enabled': settings.notificationsEnabled,
          'time': _formatTimeOfDay(settings.morningTime),
        },
      );
    }
  }

  // Update appearance in user_profiles table (partial updates)
  static Future<void> syncAppearanceToCloud({
    ThemeMode? themeMode,
    String? diaryFont,
    int? fontSize,
    String? paperStyle,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final update = <String, dynamic>{};
    if (themeMode != null) {
      update['theme_preference'] = _themeModeToString(themeMode);
    }
    if (diaryFont != null) {
      update['diary_font'] = diaryFont;
    }
    if (fontSize != null) {
      update['font_size'] = fontSize;
    }
    if (paperStyle != null) {
      update['paper_style'] = paperStyle;
    }

    if (update.isEmpty) return;
    update['user_id'] = userId;

    try {
      await _supabase.from('user_profiles').upsert(
            update,
            onConflict: 'user_id',
          );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS134',
        errorMessage:
            'Settings save failed (cloud appearance): ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'sync_appearance',
          'theme': themeMode != null ? _themeModeToString(themeMode) : null,
          'font': diaryFont,
          'font_size': fontSize,
          'paper_style': paperStyle,
        },
      );
    }
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}


