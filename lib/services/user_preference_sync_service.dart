import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';

import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'notification_service.dart';
import 'database/database_manager.dart';
import 'database/local_entry_service.dart';

class UserPreferenceSyncService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Update notification settings (local first, add to sync queue)
  static Future<void> syncNotificationSettingsToCloud(
    NotificationSettings settings,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final timeString = _formatTimeOfDay(settings.morningTime);
      final db = await DatabaseManager().database;
      final existing = await db.query(
        'user_settings',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      final now = DateTime.now().toIso8601String();
      final reminderDaysJson = jsonEncode(settings.activeDays);
      final payload = <String, dynamic>{
        'user_id': userId,
        'reminder_enabled': settings.notificationsEnabled ? 1 : 0,
        'reminder_time_local': timeString,
        'reminder_days': reminderDaysJson,
        'grace_system_enabled': existing.isNotEmpty
            ? (existing.first['grace_system_enabled'] as int? ?? 1)
            : 1,
        'privacy_lock_enabled': existing.isNotEmpty
            ? (existing.first['privacy_lock_enabled'] as int? ?? 0)
            : 0,
        'region_preference': existing.isNotEmpty
            ? existing.first['region_preference']
            : null,
        'export_format_default': existing.isNotEmpty
            ? (existing.first['export_format_default'] ?? 'json')
            : 'json',
        'updated_at': now,
        'is_synced': 0,
      };

      await db.insert(
        'user_settings',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await LocalEntryService().addToSyncQueue(
        entityType: 'user_settings',
        entityId: userId,
        tableName: 'user_settings',
        operation: 'upsert',
        data: {
          'user_id': userId,
          'reminder_enabled': settings.notificationsEnabled ? 1 : 0,
          'reminder_time_local': timeString,
          'reminder_days': reminderDaysJson,
          'grace_system_enabled': payload['grace_system_enabled'],
          'privacy_lock_enabled': payload['privacy_lock_enabled'],
          'region_preference': payload['region_preference'],
          'export_format_default': payload['export_format_default'],
        },
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS134',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'sync_notification_settings',
            'active_days': settings.activeDays,
            'enabled': settings.notificationsEnabled,
            'time': _formatTimeOfDay(settings.morningTime),
          },
        ),
      );
    }
  }

  // Update appearance (local first, add to sync queue)
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
      final db = await DatabaseManager().database;
      final existing = await db.query(
        'user_profiles',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      final payload = <String, dynamic>{
        'user_id': userId,
        'theme_preference': update['theme_preference'] ??
            (existing.isNotEmpty
                ? existing.first['theme_preference']
                : 'system'),
        'diary_font': update['diary_font'] ??
            (existing.isNotEmpty ? existing.first['diary_font'] : null),
        'font_size': update['font_size'] ??
            (existing.isNotEmpty ? existing.first['font_size'] : null),
        'paper_style': update['paper_style'] ??
            (existing.isNotEmpty ? existing.first['paper_style'] : 'ruled'),
        'is_synced': 0,
      };

      await db.insert(
        'user_profiles',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await LocalEntryService().addToSyncQueue(
        entityType: 'user_profiles',
        entityId: userId,
        tableName: 'user_profiles',
        operation: 'upsert',
        data: {
          'user_id': userId,
          'theme_preference': payload['theme_preference'],
          'diary_font': payload['diary_font'],
          'font_size': payload['font_size'],
          'paper_style': payload['paper_style'],
        },
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS134',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'sync_appearance',
            'theme': themeMode != null ? _themeModeToString(themeMode) : null,
            'font': diaryFont,
            'font_size': fontSize,
            'paper_style': paperStyle,
          },
        ),
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


