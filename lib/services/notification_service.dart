import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../services/error_logging_service.dart';
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

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Set India timezone

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
            await NativeAlarmManager.scheduleAlarm(
              notificationId: alarmId,
              title: title,
              body: body,
              scheduledTime: scheduledTime,
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
          await NativeAlarmManager.scheduleAlarm(
            notificationId: bedtimeReminderId,
            title: bedtimeTitle,
            body: bedtimeBody,
            scheduledTime: scheduledTime,
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

  /// Schedule all notifications for today
  Future<void> scheduleAllNotifications() async {
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

      // Check if morning is already completed
      final morningCompleted =
          _prefs?.getBool(NotificationStorageKeys.todayMorningCompleted) ??
          false;
      final bedtimeCompleted =
          _prefs?.getBool(NotificationStorageKeys.todayBedtimeCompleted) ??
          false;

      print(
        '🔔 DEBUG: Morning completed: $morningCompleted, Bedtime completed: $bedtimeCompleted',
      );

      // Schedule morning notifications if not completed
      if (!morningCompleted) {
        print('🔔 DEBUG: Scheduling morning notifications...');
        await _scheduleMorningNotifications(settings.morningTime);
      }

      // Schedule bedtime notification if not completed
      if (!bedtimeCompleted) {
        print('🔔 DEBUG: Scheduling bedtime notification...');
        await _scheduleBedtimeNotification();
      }

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
  Future<void> _scheduleMorningNotifications(TimeOfDay morningTime) async {
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

    // First reminder - at user's chosen time
    await NativeAlarmManager.scheduleAlarm(
      notificationId: morningReminder1Id,
      title: 'Good morning! Time for your daily affirmation 🌅',
      body: 'Start your day with positive energy and intention',
      scheduledTime: morningDateTime,
    );

    // Save to SharedPreferences for persistence
    await _prefs?.setString(
      'alarm_${morningReminder1Id}_time',
      morningDateTime.toIso8601String(),
    );
    await _prefs?.setString(
      'alarm_${morningReminder1Id}_title',
      'Good morning! Time for your daily affirmation 🌅',
    );
    await _prefs?.setString(
      'alarm_${morningReminder1Id}_body',
      'Start your day with positive energy and intention',
    );

    // Second reminder - +3 hours
    final reminder2Time = morningDateTime.add(const Duration(hours: 3));
    await NativeAlarmManager.scheduleAlarm(
      notificationId: morningReminder2Id,
      title: 'Your daily affirmation is waiting! ✨',
      body: 'Don\'t let the day rush by without taking a moment for yourself',
      scheduledTime: reminder2Time,
    );

    await _prefs?.setString(
      'alarm_${morningReminder2Id}_time',
      reminder2Time.toIso8601String(),
    );
    await _prefs?.setString(
      'alarm_${morningReminder2Id}_title',
      'Your daily affirmation is waiting! ✨',
    );
    await _prefs?.setString(
      'alarm_${morningReminder2Id}_body',
      'Don\'t let the day rush by without taking a moment for yourself',
    );

    // Third reminder - +6 hours
    final reminder3Time = morningDateTime.add(const Duration(hours: 6));
    await NativeAlarmManager.scheduleAlarm(
      notificationId: morningReminder3Id,
      title: 'Protect your streak! 🛡️',
      body: 'A quick affirmation keeps your progress alive',
      scheduledTime: reminder3Time,
    );

    await _prefs?.setString(
      'alarm_${morningReminder3Id}_time',
      reminder3Time.toIso8601String(),
    );
    await _prefs?.setString(
      'alarm_${morningReminder3Id}_title',
      'Protect your streak! 🛡️',
    );
    await _prefs?.setString(
      'alarm_${morningReminder3Id}_body',
      'A quick affirmation keeps your progress alive',
    );
  }

  /// Schedule bedtime notification using Native AlarmManager
  Future<void> _scheduleBedtimeNotification() async {
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

    await NativeAlarmManager.scheduleAlarm(
      notificationId: bedtimeReminderId,
      title: 'Time to reflect on your day! 📖',
      body: 'Capture today\'s memories before bed',
      scheduledTime: bedtimeDateTime,
    );

    // Save to SharedPreferences for persistence
    await _prefs?.setString(
      'alarm_${bedtimeReminderId}_time',
      bedtimeDateTime.toIso8601String(),
    );
    await _prefs?.setString(
      'alarm_${bedtimeReminderId}_title',
      'Time to reflect on your day! 📖',
    );
    await _prefs?.setString(
      'alarm_${bedtimeReminderId}_body',
      'Capture today\'s memories before bed',
    );
  }

  /// Schedule a single notification
  Future<void> _scheduleSingleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required Map<String, String> payload,
  }) async {
    try {
      print(
        '🔔 DEBUG: Scheduling notification ID $id at ${scheduledDate.toIso8601String()}',
      );
      print('🔔 DEBUG: Scheduled local time: ${scheduledDate.toString()}');
      final currentTime = tz.TZDateTime.now(tz.local);
      print('🔔 DEBUG: Current time: ${currentTime.toIso8601String()}');
      print('🔔 DEBUG: Current local time: ${currentTime.toString()}');
      print(
        '🔔 DEBUG: Time difference: ${scheduledDate.difference(currentTime).inMinutes} minutes',
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'diary_reminders',
            'Diary Reminders',
            channelDescription:
                'Gentle reminders for your daily diary practice',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            autoCancel: false,
            ongoing: false,
            silent: false,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'diary_reminder',
            threadIdentifier: 'diary_reminders',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print('🔔 DEBUG: Notification ID $id scheduled successfully!');
    } catch (e) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS035',
        errorMessage: 'Failed to schedule single notification: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'notification_id': id,
          'scheduled_date': scheduledDate.toIso8601String(),
          'title': title,
        },
      );
    }
  }

  /// Cancel morning reminders using Native AlarmManager
  Future<void> cancelMorningReminders() async {
    try {
      // Cancel native alarms
      await NativeAlarmManager.cancelAlarm(morningReminder1Id);
      await NativeAlarmManager.cancelAlarm(morningReminder2Id);
      await NativeAlarmManager.cancelAlarm(morningReminder3Id);

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
      // Cancel native alarm
      await NativeAlarmManager.cancelAlarm(bedtimeReminderId);

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
