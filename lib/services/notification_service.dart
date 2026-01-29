import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/error_logging_service.dart';
import 'database/database_manager.dart';
import 'native_alarm_manager.dart';
import 'user_preference_sync_service.dart';

/// Top-level callback functions for AlarmManager
/// MUST be top-level for Android to access them

@pragma('vm:entry-point')
Future<void> showTestNotificationCallback() async {
  print('🔔 CALLBACK: Test notification triggered!');
  await _showNotification(
    9997,
    'AlarmManager Test - SUCCESS! 🎉',
    'This notification was triggered by Android AlarmManager!',
  );
}

@pragma('vm:entry-point')
Future<void> showMorningReminder1Callback() async {
  print('🔔 CALLBACK: Morning reminder 1 triggered!');
  await _showNotification(
    1001,
    'Good morning! Time for your daily affirmation 🌅',
    'Start your day with positive energy and intention',
  );
}

@pragma('vm:entry-point')
Future<void> showMorningReminder2Callback() async {
  print('🔔 CALLBACK: Morning reminder 2 triggered!');
  await _showNotification(
    1002,
    'Your daily affirmation is waiting! ✨',
    'Don\'t let the day rush by without taking a moment for yourself',
  );
}

@pragma('vm:entry-point')
Future<void> showMorningReminder3Callback() async {
  print('🔔 CALLBACK: Morning reminder 3 triggered!');
  await _showNotification(
    1003,
    'Protect your streak! 🛡️',
    'A quick affirmation keeps your progress alive',
  );
}

@pragma('vm:entry-point')
Future<void> showBedtimeReminderCallback() async {
  print('🔔 CALLBACK: Bedtime reminder triggered!');
  await _showNotification(
    2001,
    'Time to reflect on your day! 📖',
    'Capture today\'s memories before bed',
  );
}

/// Helper function to show notifications
Future<void> _showNotification(int id, String title, String body) async {
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  await notifications.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'diary_reminders',
        'Diary Reminders',
        channelDescription: 'Gentle reminders for your daily diary practice',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        category: AndroidNotificationCategory.reminder,
      ),
    ),
  );

  print('🔔 CALLBACK: Notification $id shown successfully!');
}

/// Notification settings data model
class NotificationSettings {
  final TimeOfDay morningTime;
  final List<int> activeDays; // [1,2,3,4,5,6,7] for Mon-Sun
  final bool notificationsEnabled;

  NotificationSettings({
    required this.morningTime,
    required this.activeDays,
    this.notificationsEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'morning_time_hour': morningTime.hour,
      'morning_time_minute': morningTime.minute,
      'active_days': activeDays,
      'notifications_enabled': notificationsEnabled,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      morningTime: TimeOfDay(
        hour: json['morning_time_hour'] as int? ?? 7,
        minute: json['morning_time_minute'] as int? ?? 0,
      ),
      activeDays: List<int>.from(
        json['active_days'] as List? ?? [1, 2, 3, 4, 5, 6, 7],
      ),
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
    );
  }
}

/// Daily completion tracking model
class DailyCompletion {
  final DateTime date;
  final bool morningCompleted;
  final bool bedtimeCompleted;

  DailyCompletion({
    required this.date,
    this.morningCompleted = false,
    this.bedtimeCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'morning_completed': morningCompleted,
      'bedtime_completed': bedtimeCompleted,
    };
  }

  factory DailyCompletion.fromJson(Map<String, dynamic> json) {
    return DailyCompletion(
      date: DateTime.parse(json['date'] as String),
      morningCompleted: json['morning_completed'] as bool? ?? false,
      bedtimeCompleted: json['bedtime_completed'] as bool? ?? false,
    );
  }
}

/// Storage keys for SharedPreferences
class NotificationStorageKeys {
  // User Settings
  static const String morningTime = 'notification_morning_time';
  static const String activeDays = 'notification_active_days';
  static const String notificationsEnabled = 'notification_enabled';

  // Daily Completion Status
  static const String todayMorningCompleted = 'today_morning_completed';
  static const String todayBedtimeCompleted = 'today_bedtime_completed';
  static const String lastResetDate = 'last_reset_date';

  // Notification IDs
  static const String morningReminder1Id = 'morning_reminder_1_id';
  static const String morningReminder2Id = 'morning_reminder_2_id';
  static const String morningReminder3Id = 'morning_reminder_3_id';
  static const String bedtimeReminderId = 'bedtime_reminder_id';
}

class _NotificationMessage {
  final String title;
  final String body;
  const _NotificationMessage(this.title, this.body);
}

/// Main notification service class
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  // Dependencies
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  SharedPreferences? _prefs;

  // State Management
  final StreamController<NotificationResponse> _notificationStreamController =
      StreamController<NotificationResponse>.broadcast();

  // Notification IDs
  static const int morningReminder1Id = 1001;
  static const int morningReminder2Id = 1002;
  static const int morningReminder3Id = 1003;
  static const int bedtimeReminderId = 2001;

  // Rotating messages (10 per category)
  static const List<String> _morningTitles = [
    'Good morning! 🌅 Time to start your day with positive energy and intention ✨',
    'Rise and shine! ☀️ Your daily affirmation is waiting to set a beautiful tone for today 🌸',
    'Morning sunshine! 🌞 Take a moment to fill your heart with gratitude and affirmations 💫',
    'A fresh new day begins! 🌄 Start it right with your daily affirmation practice 🌺',
    'Good morning, beautiful soul! 💖 Time for your morning ritual of self-love and positivity 🌟',
    'The sun is up, and so should your spirits! ☀️ Let us begin with your daily affirmation 🌷',
    'Morning blessings! 🙏 Take a peaceful moment to set your intentions for today 🕊️',
    'Wake up with purpose! 🌅 Your daily affirmation practice awaits to brighten your day ✨',
    'A brand new day, a fresh start! 🌸 Begin with your morning affirmation ritual 💫',
    'Good morning, sunshine! ☀️ Time to nurture your soul with positive affirmations 🌺',
  ];

  static const List<String> _reminder3hTitles = [
    'Your daily affirmation is waiting! ✨ Do not let the day rush by without taking a moment for yourself 🌸',
    'A gentle reminder: your morning affirmation is still waiting 💫 Take a quick break to fill your heart 🌺',
    'Pause for a moment! 🌷 Your daily affirmation practice is calling - you deserve this time 💖',
    'Do not forget your daily affirmation! 🌟 A few minutes now can transform your entire day ✨',
    'Your affirmation is waiting patiently! 💫 Take a moment to connect with yourself 🌸',
    'Time for a mindful pause! 🧘 Your daily affirmation is here to support your journey 🌺',
    'A gentle nudge: your affirmation practice awaits! ✨ You are worth this moment of self-care 💖',
    'Still time for your affirmation! 🌟 Do not let the day slip away without this beautiful ritual 🌸',
    'Your daily affirmation is calling! 💫 Take a peaceful moment to nurture your soul 🌺',
    'A reminder with love: your affirmation practice is waiting! ✨ You deserve this time for yourself 🌷',
  ];

  static const List<String> _reminder6hTitles = [
    'Protect your streak! 🛡️ A quick affirmation keeps your progress alive and your heart full 💫',
    'Your streak is precious! 🌟 Do not let it slip - a moment now keeps your journey strong 🛡️',
    'Streak protection time! 💪 Your daily affirmation is the key to maintaining your beautiful progress ✨',
    'Keep your momentum going! 🚀 A quick affirmation now protects all the progress you have made 🌟',
    'Your streak needs you! 💖 Take a moment to complete your affirmation and keep your journey alive 🛡️',
    'Do not break the chain! 🔗 Your daily affirmation is the link that keeps your progress strong 💫',
    'Protect what you have built! 🏆 A quick affirmation now maintains your beautiful streak 🌟',
    'Your progress matters! 💪 Complete your affirmation to keep your streak alive and thriving 🛡️',
    'Streak guardian mode! 🛡️ Your daily affirmation is the shield that protects your journey ✨',
    'Keep the momentum! 🌟 Your affirmation practice is the foundation of your beautiful progress 💫',
  ];

  static const List<String> _bedtimeNotFilledTitles = [
    'Fill your diary! 📖 Capture today\'s memories before they fade into tomorrow 🌙',
    'Your diary is waiting! ✍️ Do not let today\'s stories go untold - write them down 📖',
    'Time to reflect and write! 📝 Your diary is ready to hold today\'s precious moments 🌙',
    'Capture today\'s journey! 📖 Your diary is calling - preserve these beautiful memories ✨',
    'Do not forget to write! ✍️ Your diary is waiting to hold today\'s experiences and thoughts 📖',
    'Bedtime reflection time! 🌙 Fill your diary with today\'s moments before sleep 📝',
    'Your diary needs you! 📖 Take a moment to document today\'s beautiful journey ✨',
    'Write it down! ✍️ Your diary is ready to capture today\'s memories and reflections 📖',
    'Time to journal! 📝 Do not let today slip away - fill your diary with your story 🌙',
    'Your diary awaits! 📖 Capture today\'s moments before they become yesterday\'s memories ✨',
  ];

  static const List<String> _bedtimeFilledTitles = [
    'Reflect on your day! ✨ Take a moment to appreciate all the beautiful moments you have captured 🌙',
    'Evening reflection time! 💫 Review your day and see how much you have accomplished 🌟',
    'Time to reflect! 🌙 Look back on your day with gratitude and see your growth ✨',
    'Evening gratitude moment! 🙏 Reflect on today\'s journey and all the blessings it brought 💖',
    'Bedtime reflection! 🌙 Take a peaceful moment to appreciate your day and set intentions for tomorrow ✨',
    'Evening pause! 💫 Reflect on your beautiful day and all the moments you have captured 🌟',
    'Time for reflection! 🌙 Review your day with love and see how much you have grown ✨',
    'Evening gratitude! 🙏 Reflect on today\'s journey and appreciate all the beautiful moments 💖',
    'Bedtime reflection moment! 🌙 Take time to appreciate your day and all you have accomplished ✨',
    'Evening pause for reflection! 💫 Look back on your day with gratitude and see your beautiful journey 🌟',
  ];

  static const String _morningBody =
      'Start your day with positive energy and intention';
  static const String _reminder3hBody =
      'Do not let the day rush by without taking a moment for yourself';
  static const String _reminder6hBody =
      'A quick affirmation keeps your progress alive';
  static const String _bedtimeNotFilledBody =
      'Capture today\'s memories before bed';
  static const String _bedtimeFilledBody =
      'Take a calm moment to reflect on your day';

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      // Get SharedPreferences instance
      _prefs = await SharedPreferences.getInstance();

      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      // Reschedule any pending alarms that may have been cancelled
      await _rescheduleAlarmsOnRestart();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS031',
        errorMessage:
            'Notification service initialization failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'initialization_time': DateTime.now().toIso8601String(),
          'service': 'NotificationService',
        },
      );
    }
  }

  /// Reschedule alarms on app restart (in case they were cancelled)
  Future<void> _rescheduleAlarmsOnRestart() async {
    try {
      final now = DateTime.now();
      final userId = _getCurrentUserId();

      // Reschedule morning reminders
      for (final alarmId in [
        morningReminder1Id,
        morningReminder2Id,
        morningReminder3Id,
      ]) {
        final timeStr = _prefs?.getString('alarm_${alarmId}_time');
        final title = _prefs?.getString('alarm_${alarmId}_title');
        final body = _prefs?.getString('alarm_${alarmId}_body');

        if (timeStr != null && title != null && body != null) {
          final scheduledTime = DateTime.parse(timeStr);

          // Only reschedule if time is in the future
          if (scheduledTime.isAfter(now)) {
            await _scheduleAlarmWithLogging(
              notificationId: alarmId,
              title: title,
              body: body,
              scheduledTime: scheduledTime,
              context: 'restart_reschedule_morning',
              userId: userId,
            );
            print(
              '🔔 RESTART: Rescheduled alarm $alarmId for ${scheduledTime.toString()}',
            );
          }
        }
      }

      // Reschedule bedtime reminder
      final bedtimeTimeStr = _prefs?.getString(
        'alarm_${bedtimeReminderId}_time',
      );
      final bedtimeTitle = _prefs?.getString(
        'alarm_${bedtimeReminderId}_title',
      );
      final bedtimeBody = _prefs?.getString('alarm_${bedtimeReminderId}_body');

      if (bedtimeTimeStr != null &&
          bedtimeTitle != null &&
          bedtimeBody != null) {
        final scheduledTime = DateTime.parse(bedtimeTimeStr);

        if (scheduledTime.isAfter(now)) {
          await _scheduleAlarmWithLogging(
            notificationId: bedtimeReminderId,
            title: bedtimeTitle,
            body: bedtimeBody,
            scheduledTime: scheduledTime,
            context: 'restart_reschedule_bedtime',
            userId: userId,
          );
          print(
            '🔔 RESTART: Rescheduled bedtime alarm for ${scheduledTime.toString()}',
          );
        }
      }
    } catch (e) {
      print('🔔 RESTART: Error rescheduling alarms: $e');
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS060',
        errorMessage: 'Failed to reschedule alarms on restart: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'restart_time': DateTime.now().toIso8601String(),
          'service': 'NotificationService',
        },
      );
    }
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse response) {
    _notificationStreamController.add(response);
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'diary_reminders',
        'Diary Reminders',
        description: 'Gentle reminders for your daily diary practice',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS059',
        errorMessage: 'Failed to create notification channel: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'channel_id': 'diary_reminders',
          'creation_time': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      // Request notification permission
      final status = await Permission.notification.request();
      print('🔔 DEBUG: Permission status: $status');

      if (status.isGranted) {
        print('🔔 DEBUG: Notification permission granted!');
        return true;
      } else {
        print('🔔 DEBUG: Notification permission denied!');
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS032',
          errorMessage: 'Notification permission denied by user',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'permission_status': status.toString(),
            'request_time': DateTime.now().toIso8601String(),
          },
        );
        return false;
      }
    } catch (e) {
      print('🔔 DEBUG: Permission request failed: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS033',
        errorMessage: 'Permission request failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'permission_type': 'notification',
          'request_time': DateTime.now().toIso8601String(),
        },
      );
      return false;
    }
  }

  /// Get current notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    final morningTimeHour =
        _prefs!.getInt('${NotificationStorageKeys.morningTime}_hour') ?? 7;
    final morningTimeMinute =
        _prefs!.getInt('${NotificationStorageKeys.morningTime}_minute') ?? 0;
    final activeDays =
        _prefs!
            .getStringList(NotificationStorageKeys.activeDays)
            ?.map(int.parse)
            .toList() ??
        [1, 2, 3, 4, 5, 6, 7];
    final notificationsEnabled =
        _prefs!.getBool(NotificationStorageKeys.notificationsEnabled) ?? true;

    return NotificationSettings(
      morningTime: TimeOfDay(hour: morningTimeHour, minute: morningTimeMinute),
      activeDays: activeDays,
      notificationsEnabled: notificationsEnabled,
    );
  }

  /// Update notification settings
  Future<void> updateNotificationSettings(NotificationSettings settings) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    await _prefs!.setInt(
      '${NotificationStorageKeys.morningTime}_hour',
      settings.morningTime.hour,
    );
    await _prefs!.setInt(
      '${NotificationStorageKeys.morningTime}_minute',
      settings.morningTime.minute,
    );
    await _prefs!.setStringList(
      NotificationStorageKeys.activeDays,
      settings.activeDays.map((day) => day.toString()).toList(),
    );
    await _prefs!.setBool(
      NotificationStorageKeys.notificationsEnabled,
      settings.notificationsEnabled,
    );

    // Cancel existing notifications and reschedule
    await _notifications.cancelAll();
    if (settings.notificationsEnabled) {
      await scheduleAllNotifications();
    }

    // Sync to Supabase (best-effort)
    try {
      await UserPreferenceSyncService.syncNotificationSettingsToCloud(settings);
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS134',
        errorMessage:
            'Settings save failed (syncNotificationSettingsToCloud call): ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'notification_settings_sync_call',
        },
      );
    }
  }

  /// Check if today is an active day
  bool _isTodayActiveDay(List<int> activeDays) {
    final today = DateTime.now().weekday;
    return activeDays.contains(today);
  }

  String? _getCurrentUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  int _getRotationIndexForDate(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    final daysSinceEpoch =
        localDate.difference(DateTime(1970, 1, 1)).inDays;
    return daysSinceEpoch % 10;
  }

  _NotificationMessage _pickMessage(
    List<String> titles,
    String body,
    int index,
  ) {
    if (titles.isEmpty) {
      return _NotificationMessage('Reminder', body);
    }
    final safeIndex = index % titles.length;
    return _NotificationMessage(titles[safeIndex], body);
  }

  Future<bool> _isDiaryCompletedToday(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;
      final rows = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );

      if (rows.isEmpty) {
        return false;
      }

      final wroteEntry = rows.first['wrote_entry'];
      if (wroteEntry is bool) return wroteEntry;
      if (wroteEntry is int) return wroteEntry == 1;
      if (wroteEntry is num) return wroteEntry > 0;

      return false;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS150',
        errorMessage: 'Failed to read diary completion status: $e',
        stackTrace: stackTrace.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'read_habits_daily_diary_status',
        },
      );
      return false;
    }
  }

  Future<void> _scheduleAlarmWithLogging({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String context,
    String? userId,
  }) async {
    try {
      final scheduled = await NativeAlarmManager.scheduleAlarm(
        notificationId: notificationId,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
      );

      if (scheduled != true) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS151',
          errorMessage: 'Native alarm scheduling returned false',
          errorContext: {
            'notification_id': notificationId,
            'scheduled_time': scheduledTime.toIso8601String(),
            'title': title,
            'context': context,
            'user_id': userId,
          },
        );
      }
    } catch (e, stackTrace) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS152',
        errorMessage: 'Native alarm scheduling failed: $e',
        stackTrace: stackTrace.toString(),
        errorContext: {
          'notification_id': notificationId,
          'scheduled_time': scheduledTime.toIso8601String(),
          'title': title,
          'context': context,
          'user_id': userId,
        },
      );
    }
  }

  Future<void> _storeAlarmMetadata({
    required int notificationId,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final timeSaved = await _prefs?.setString(
        'alarm_${notificationId}_time',
        scheduledTime.toIso8601String(),
      );
      final titleSaved = await _prefs?.setString(
        'alarm_${notificationId}_title',
        title,
      );
      final bodySaved = await _prefs?.setString(
        'alarm_${notificationId}_body',
        body,
      );

      if (timeSaved == false || titleSaved == false || bodySaved == false) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS153',
          errorMessage: 'Failed to persist alarm metadata',
          errorContext: {
            'notification_id': notificationId,
            'scheduled_time': scheduledTime.toIso8601String(),
            'time_saved': timeSaved,
            'title_saved': titleSaved,
            'body_saved': bodySaved,
          },
        );
      }
    } catch (e, stackTrace) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS154',
        errorMessage: 'Error saving alarm metadata: $e',
        stackTrace: stackTrace.toString(),
        errorContext: {
          'notification_id': notificationId,
          'scheduled_time': scheduledTime.toIso8601String(),
        },
      );
    }
  }

  Future<void> _clearAlarmMetadata(int notificationId) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final timeRemoved =
          await _prefs?.remove('alarm_${notificationId}_time') ?? false;
      final titleRemoved =
          await _prefs?.remove('alarm_${notificationId}_title') ?? false;
      final bodyRemoved =
          await _prefs?.remove('alarm_${notificationId}_body') ?? false;

      if (!timeRemoved || !titleRemoved || !bodyRemoved) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS160',
          errorMessage: 'Failed to clear alarm metadata',
          errorContext: {
            'notification_id': notificationId,
            'time_removed': timeRemoved,
            'title_removed': titleRemoved,
            'body_removed': bodyRemoved,
          },
        );
      }
    } catch (e, stackTrace) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS161',
        errorMessage: 'Error clearing alarm metadata: $e',
        stackTrace: stackTrace.toString(),
        errorContext: {
          'notification_id': notificationId,
        },
      );
    }
  }

  Future<void> _cancelAlarmWithLogging({
    required int notificationId,
    required String context,
    String? userId,
  }) async {
    try {
      final cancelled = await NativeAlarmManager.cancelAlarm(notificationId);
      if (cancelled != true) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS155',
          errorMessage: 'Native alarm cancel returned false',
          errorContext: {
            'notification_id': notificationId,
            'context': context,
            'user_id': userId,
          },
        );
      }
    } catch (e, stackTrace) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS156',
        errorMessage: 'Native alarm cancel failed: $e',
        stackTrace: stackTrace.toString(),
        errorContext: {
          'notification_id': notificationId,
          'context': context,
          'user_id': userId,
        },
      );
    }
  }

  Future<void> rescheduleBasedOnHabits(String userId) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final settings = await getNotificationSettings();
      if (!settings.notificationsEnabled) {
        return;
      }

      if (!_isTodayActiveDay(settings.activeDays)) {
        return;
      }

      final diaryCompleted = await _isDiaryCompletedToday(userId);

      if (diaryCompleted) {
        await cancelMorningReminders();
      } else {
        await _scheduleMorningNotifications(
          settings.morningTime,
          userId: userId,
        );
      }

      await _scheduleBedtimeNotification(
        diaryCompleted: diaryCompleted,
        userId: userId,
      );
    } catch (e, stackTrace) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS157',
        errorMessage: 'Reschedule based on habits failed: $e',
        stackTrace: stackTrace.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'reschedule_based_on_habits',
        },
      );
    }
  }

  /// Schedule all notifications for today
  Future<void> scheduleAllNotifications({String? userId}) async {
    try {
      final settings = await getNotificationSettings();
      print('🔔 DEBUG: Settings loaded - ${settings.toJson()}');

      if (!settings.notificationsEnabled) {
        print('🔔 DEBUG: Notifications disabled');
        return;
      }

      if (!_isTodayActiveDay(settings.activeDays)) {
        print(
          '🔔 DEBUG: Today is not an active day. Active days: ${settings.activeDays}, Today: ${DateTime.now().weekday}',
        );
        return;
      }

      final resolvedUserId = userId ?? _getCurrentUserId();
      if (resolvedUserId == null) {
        await ErrorLoggingService.logLowError(
          errorCode: 'ERRSYS158',
          errorMessage: 'User ID missing while scheduling notifications',
          errorContext: {
            'operation': 'schedule_all_notifications',
          },
        );
      }

      final diaryCompleted = resolvedUserId == null
          ? false
          : await _isDiaryCompletedToday(resolvedUserId);

      print('🔔 DEBUG: Diary completed: $diaryCompleted');

      if (diaryCompleted) {
        await cancelMorningReminders();
      } else {
        print('🔔 DEBUG: Scheduling morning notifications...');
        await _scheduleMorningNotifications(
          settings.morningTime,
          userId: resolvedUserId,
        );
      }

      print('🔔 DEBUG: Scheduling bedtime notification...');
      await _scheduleBedtimeNotification(
        diaryCompleted: diaryCompleted,
        userId: resolvedUserId,
      );

      print('🔔 DEBUG: All notifications scheduled successfully!');
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS034',
        errorMessage: 'Failed to schedule notifications: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'scheduling_time': DateTime.now().toIso8601String(),
          'settings': (await getNotificationSettings()).toJson(),
        },
      );
    }
  }

  /// Reset completion status for testing
  Future<void> resetCompletionStatus() async {
    if (_prefs != null) {
      await _prefs!.setBool(
        NotificationStorageKeys.todayMorningCompleted,
        false,
      );
      await _prefs!.setBool(
        NotificationStorageKeys.todayBedtimeCompleted,
        false,
      );
      print('🔔 DEBUG: Completion status reset - both set to false');
    }
  }

  /// Test immediate notification
  Future<void> testImmediateNotification() async {
    try {
      await _notifications.show(
        9999,
        'Test Notification',
        'This is a test notification - if you see this, notifications are working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'diary_reminders',
            'Diary Reminders',
            channelDescription:
                'Gentle reminders for your daily diary practice',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'diary_reminder',
            threadIdentifier: 'diary_reminders',
          ),
        ),
      );
      print('🔔 DEBUG: Immediate test notification sent!');
    } catch (e) {
      print('🔔 DEBUG: Error sending immediate notification: $e');
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS061',
        errorMessage:
            'Failed to send immediate test notification: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'test_type': 'immediate',
          'test_time': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  /// Test hardcoded 1-minute notification using AlarmManager
  Future<void> testHardcodedNotification() async {
    DateTime scheduledTime = DateTime.now();
    try {
      final now = DateTime.now();
      scheduledTime = now.add(const Duration(minutes: 1));

      print('🔔 DEBUG: Current time: ${now.toString()}');
      print('🔔 DEBUG: Scheduled time: ${scheduledTime.toString()}');
      print(
        '🔔 DEBUG: Time difference: ${scheduledTime.difference(now).inSeconds} seconds',
      );

      // Use Android Alarm Manager for reliable scheduling
      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        9997, // Unique alarm ID
        showTestNotificationCallback, // Top-level callback function
        exact: true,
        wakeup: true,
        rescheduleOnReboot: false,
      );

      print(
        '🔔 DEBUG: AlarmManager scheduled successfully for ${scheduledTime.toString()}!',
      );
    } catch (e) {
      print('🔔 DEBUG: Error scheduling with AlarmManager: $e');
      print('🔔 DEBUG: Stack trace: ${StackTrace.current}');
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS062',
        errorMessage:
            'Failed to schedule test notification with AlarmManager: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'test_type': 'hardcoded_1min',
          'test_time': DateTime.now().toIso8601String(),
          'scheduled_time': scheduledTime.toIso8601String(),
        },
      );
    }
  }

  /// Schedule morning notifications (3-tier system) using Native AlarmManager
  Future<void> _scheduleMorningNotifications(
    TimeOfDay morningTime, {
    String? userId,
  }) async {
    final now = DateTime.now();
    var morningDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      morningTime.hour,
      morningTime.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (morningDateTime.isBefore(now)) {
      morningDateTime = morningDateTime.add(const Duration(days: 1));
      print(
        '🔔 DEBUG: Morning time passed today, scheduling for tomorrow: ${morningDateTime.toString()}',
      );
    }

    final messageIndex = _getRotationIndexForDate(morningDateTime);
    final firstMessage =
        _pickMessage(_morningTitles, _morningBody, messageIndex);
    final secondMessage =
        _pickMessage(_reminder3hTitles, _reminder3hBody, messageIndex);
    final thirdMessage =
        _pickMessage(_reminder6hTitles, _reminder6hBody, messageIndex);

    // First reminder - at user's chosen time
    await _scheduleAlarmWithLogging(
      notificationId: morningReminder1Id,
      title: firstMessage.title,
      body: firstMessage.body,
      scheduledTime: morningDateTime,
      context: 'morning_reminder_1',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: morningReminder1Id,
      scheduledTime: morningDateTime,
      title: firstMessage.title,
      body: firstMessage.body,
    );

    // Second reminder - +3 hours
    final reminder2Time = morningDateTime.add(const Duration(hours: 3));
    await _scheduleAlarmWithLogging(
      notificationId: morningReminder2Id,
      title: secondMessage.title,
      body: secondMessage.body,
      scheduledTime: reminder2Time,
      context: 'morning_reminder_2',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: morningReminder2Id,
      scheduledTime: reminder2Time,
      title: secondMessage.title,
      body: secondMessage.body,
    );

    // Third reminder - +6 hours
    final reminder3Time = morningDateTime.add(const Duration(hours: 6));
    await _scheduleAlarmWithLogging(
      notificationId: morningReminder3Id,
      title: thirdMessage.title,
      body: thirdMessage.body,
      scheduledTime: reminder3Time,
      context: 'morning_reminder_3',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: morningReminder3Id,
      scheduledTime: reminder3Time,
      title: thirdMessage.title,
      body: thirdMessage.body,
    );
  }

  /// Schedule bedtime notification using Native AlarmManager
  Future<void> _scheduleBedtimeNotification({
    required bool diaryCompleted,
    String? userId,
  }) async {
    final now = DateTime.now();
    var bedtimeDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      21, // 9:00 PM
      0,
    );

    // If the time has already passed today, schedule for tomorrow
    if (bedtimeDateTime.isBefore(now)) {
      bedtimeDateTime = bedtimeDateTime.add(const Duration(days: 1));
      print(
        '🔔 DEBUG: Bedtime time passed today, scheduling for tomorrow: ${bedtimeDateTime.toString()}',
      );
    }

    final messageIndex = _getRotationIndexForDate(bedtimeDateTime);
    final bedtimeMessage = diaryCompleted
        ? _pickMessage(_bedtimeFilledTitles, _bedtimeFilledBody, messageIndex)
        : _pickMessage(
            _bedtimeNotFilledTitles,
            _bedtimeNotFilledBody,
            messageIndex,
          );

    await _scheduleAlarmWithLogging(
      notificationId: bedtimeReminderId,
      title: bedtimeMessage.title,
      body: bedtimeMessage.body,
      scheduledTime: bedtimeDateTime,
      context: 'bedtime_reminder',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: bedtimeReminderId,
      scheduledTime: bedtimeDateTime,
      title: bedtimeMessage.title,
      body: bedtimeMessage.body,
    );
  }

  /// Cancel morning reminders using Native AlarmManager
  Future<void> cancelMorningReminders() async {
    try {
      final userId = _getCurrentUserId();

      // Cancel native alarms
      await _cancelAlarmWithLogging(
        notificationId: morningReminder1Id,
        context: 'cancel_morning_reminder_1',
        userId: userId,
      );
      await _clearAlarmMetadata(morningReminder1Id);
      await _cancelAlarmWithLogging(
        notificationId: morningReminder2Id,
        context: 'cancel_morning_reminder_2',
        userId: userId,
      );
      await _clearAlarmMetadata(morningReminder2Id);
      await _cancelAlarmWithLogging(
        notificationId: morningReminder3Id,
        context: 'cancel_morning_reminder_3',
        userId: userId,
      );
      await _clearAlarmMetadata(morningReminder3Id);

      // Also cancel any shown notifications
      await _notifications.cancel(morningReminder1Id);
      await _notifications.cancel(morningReminder2Id);
      await _notifications.cancel(morningReminder3Id);

      // Update completion status
      if (_prefs != null) {
        await _prefs!.setBool(
          NotificationStorageKeys.todayMorningCompleted,
          true,
        );
      }

      print('🔔 DEBUG: Morning reminders cancelled successfully');
    } catch (e) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS036',
        errorMessage: 'Failed to cancel morning reminders: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'cancellation_time': DateTime.now().toIso8601String(),
          'reminder_ids': [
            morningReminder1Id,
            morningReminder2Id,
            morningReminder3Id,
          ],
        },
      );
    }
  }

  /// Cancel bedtime reminder using Native AlarmManager
  Future<void> cancelBedtimeReminder() async {
    try {
      final userId = _getCurrentUserId();

      // Cancel native alarm
      await _cancelAlarmWithLogging(
        notificationId: bedtimeReminderId,
        context: 'cancel_bedtime_reminder',
        userId: userId,
      );
      await _clearAlarmMetadata(bedtimeReminderId);

      // Also cancel any shown notification
      await _notifications.cancel(bedtimeReminderId);

      // Update completion status
      if (_prefs != null) {
        await _prefs!.setBool(
          NotificationStorageKeys.todayBedtimeCompleted,
          true,
        );
      }

      print('🔔 DEBUG: Bedtime reminder cancelled successfully');
    } catch (e) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS037',
        errorMessage: 'Failed to cancel bedtime reminder: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'cancellation_time': DateTime.now().toIso8601String(),
          'reminder_id': bedtimeReminderId,
        },
      );
    }
  }

  /// Check and reset daily status
  Future<void> checkAndResetDailyStatus() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final today = DateTime.now();
      final lastResetString = _prefs!.getString(
        NotificationStorageKeys.lastResetDate,
      );

      if (lastResetString == null) {
        // First time setup
        await _prefs!.setString(
          NotificationStorageKeys.lastResetDate,
          today.toIso8601String(),
        );
        await scheduleAllNotifications();
        return;
      }

      final lastReset = DateTime.parse(lastResetString);

      if (!_isSameDay(today, lastReset)) {
        // New day detected - reset completion status
        await _prefs!.setBool(
          NotificationStorageKeys.todayMorningCompleted,
          false,
        );
        await _prefs!.setBool(
          NotificationStorageKeys.todayBedtimeCompleted,
          false,
        );
        await _prefs!.setString(
          NotificationStorageKeys.lastResetDate,
          today.toIso8601String(),
        );

        // Schedule new day's notifications
        await scheduleAllNotifications();
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS038',
        errorMessage: 'Daily reset failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'reset_time': DateTime.now().toIso8601String(),
          'last_reset': _prefs?.getString(
            NotificationStorageKeys.lastResetDate,
          ),
        },
      );
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get notification stream
  Stream<NotificationResponse> get notificationStream =>
      _notificationStreamController.stream;

  /// Dispose resources
  void dispose() {
    _notificationStreamController.close();
  }
}
