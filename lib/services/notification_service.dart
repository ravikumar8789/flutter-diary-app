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
  final now = DateTime.now();
  final index = NotificationService.instance._getRotationIndexForDate(now);
  final message = NotificationService.instance._pickMessage(
    NotificationService._morningTitles,
    NotificationService._morningBodies,
    index,
    context: 'callback_morning_1',
  );
  await _showNotification(1001, message.title, message.body);
}

@pragma('vm:entry-point')
Future<void> showMorningReminder2Callback() async {
  print('🔔 CALLBACK: Morning reminder 2 triggered!');
  final now = DateTime.now();
  final index = NotificationService.instance._getRotationIndexForDate(now);
  final message = NotificationService.instance._pickMessage(
    NotificationService._reminder3hTitles,
    NotificationService._reminder3hBodies,
    index,
    context: 'callback_morning_2',
  );
  await _showNotification(1002, message.title, message.body);
}

@pragma('vm:entry-point')
Future<void> showMorningReminder3Callback() async {
  print('🔔 CALLBACK: Morning reminder 3 triggered!');
  final now = DateTime.now();
  final index = NotificationService.instance._getRotationIndexForDate(now);
  final message = NotificationService.instance._pickMessage(
    NotificationService._reminder6hTitles,
    NotificationService._reminder6hBodies,
    index,
    context: 'callback_morning_3',
  );
  await _showNotification(1003, message.title, message.body);
}

@pragma('vm:entry-point')
Future<void> showBedtimeReminderCallback() async {
  print('🔔 CALLBACK: Bedtime reminder triggered!');
  final now = DateTime.now();
  final index = NotificationService.instance._getRotationIndexForDate(now);
  final message = NotificationService.instance._pickMessage(
    NotificationService._bedtimeNotFilledTitles,
    NotificationService._bedtimeNotFilledBodies,
    index,
    context: 'callback_bedtime',
  );
  await _showNotification(2001, message.title, message.body);
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
  static const int _futureDays = 10;
  static const int _alarmDayMultiplier = 10;

  // Rotating messages (10 per category)
  static const List<String> _morningTitles = [
    'Good morning! 🌅',
    'Rise and shine! ☀️',
    'Morning sunshine! 🌞',
    'A fresh new day begins! 🌄',
    'Good morning, beautiful soul! 💖',
    'The sun is up, and so should your spirits! ☀️',
    'Morning blessings! 🙏',
    'Wake up with purpose! 🌅',
    'A brand new day, a fresh start! 🌸',
    'Good morning, sunshine! ☀️',
  ];

  static const List<String> _morningBodies = [
    'Time to start your day with positive energy and intention ✨',
    'Your daily affirmation is waiting to set a beautiful tone for today 🌸',
    'Take a moment to fill your heart with gratitude and affirmations 💫',
    'Start it right with your daily affirmation practice 🌺',
    'Time for your morning ritual of self-love and positivity 🌟',
    'Let us begin with your daily affirmation 🌷',
    'Take a peaceful moment to set your intentions for today 🕊️',
    'Your daily affirmation practice awaits to brighten your day ✨',
    'Begin with your morning affirmation ritual 💫',
    'Time to nurture your soul with positive affirmations 🌺',
  ];

  static const List<String> _reminder3hTitles = [
    'Your daily affirmation is waiting! ✨',
    'A gentle reminder:',
    'Pause for a moment! 🌷',
    'Do not forget your daily affirmation! 🌟',
    'Your affirmation is waiting patiently! 💫',
    'Time for a mindful pause! 🧘',
    'A gentle nudge:',
    'Still time for your affirmation! 🌟',
    'Your daily affirmation is calling! 💫',
    'A reminder with love:',
  ];

  static const List<String> _reminder3hBodies = [
    'Do not let the day rush by without taking a moment for yourself 🌸',
    'Your morning affirmation is still waiting 💫 Take a quick break to fill your heart 🌺',
    'Your daily affirmation practice is calling - you deserve this time 💖',
    'A few minutes now can transform your entire day ✨',
    'Take a moment to connect with yourself 🌸',
    'Your daily affirmation is here to support your journey 🌺',
    'Your affirmation practice awaits! ✨ You are worth this moment of self-care 💖',
    'Do not let the day slip away without this beautiful ritual 🌸',
    'Take a peaceful moment to nurture your soul 🌺',
    'Your affirmation practice is waiting! ✨ You deserve this time for yourself 🌷',
  ];

  static const List<String> _reminder6hTitles = [
    'Protect your streak! 🛡️',
    'Your streak is precious! 🌟',
    'Streak protection time! 💪',
    'Keep your momentum going! 🚀',
    'Your streak needs you! 💖',
    'Do not break the chain! 🔗',
    'Protect what you have built! 🏆',
    'Your progress matters! 💪',
    'Streak guardian mode! 🛡️',
    'Keep the momentum! 🌟',
  ];

  static const List<String> _reminder6hBodies = [
    'A quick affirmation keeps your progress alive and your heart full 💫',
    'Do not let it slip - a moment now keeps your journey strong 🛡️',
    'Your daily affirmation is the key to maintaining your beautiful progress ✨',
    'A quick affirmation now protects all the progress you have made 🌟',
    'Take a moment to complete your affirmation and keep your journey alive 🛡️',
    'Your daily affirmation is the link that keeps your progress strong 💫',
    'A quick affirmation now maintains your beautiful streak 🌟',
    'Complete your affirmation to keep your streak alive and thriving 🛡️',
    'Your daily affirmation is the shield that protects your journey ✨',
    'Your affirmation practice is the foundation of your beautiful progress 💫',
  ];

  static const List<String> _bedtimeNotFilledTitles = [
    'Fill your diary! 📖',
    'Your diary is waiting! ✍️',
    'Time to reflect and write! 📝',
    'Capture today\'s journey! 📖',
    'Do not forget to write! ✍️',
    'Bedtime reflection time! 🌙',
    'Your diary needs you! 📖',
    'Write it down! ✍️',
    'Time to journal! 📝',
    'Your diary awaits! 📖',
  ];

  static const List<String> _bedtimeNotFilledBodies = [
    'Capture today\'s memories before they fade into tomorrow 🌙',
    'Do not let today\'s stories go untold - write them down 📖',
    'Your diary is ready to hold today\'s precious moments 🌙',
    'Your diary is calling - preserve these beautiful memories ✨',
    'Your diary is waiting to hold today\'s experiences and thoughts 📖',
    'Fill your diary with today\'s moments before sleep 📝',
    'Take a moment to document today\'s beautiful journey ✨',
    'Your diary is ready to capture today\'s memories and reflections 📖',
    'Do not let today slip away - fill your diary with your story 🌙',
    'Capture today\'s moments before they become yesterday\'s memories ✨',
  ];

  static const List<String> _bedtimeFilledTitles = [
    'Reflect on your day! ✨',
    'Evening reflection time! 💫',
    'Time to reflect! 🌙',
    'Evening gratitude moment! 🙏',
    'Bedtime reflection! 🌙',
    'Evening pause! 💫',
    'Time for reflection! 🌙',
    'Evening gratitude! 🙏',
    'Bedtime reflection moment! 🌙',
    'Evening pause for reflection! 💫',
  ];

  static const List<String> _bedtimeFilledBodies = [
    'Take a moment to appreciate all the beautiful moments you have captured 🌙',
    'Review your day and see how much you have accomplished 🌟',
    'Look back on your day with gratitude and see your growth ✨',
    'Reflect on today\'s journey and all the blessings it brought 💖',
    'Take a peaceful moment to appreciate your day and set intentions for tomorrow ✨',
    'Reflect on your beautiful day and all the moments you have captured 🌟',
    'Review your day with love and see how much you have grown ✨',
    'Reflect on today\'s journey and appreciate all the beautiful moments 💖',
    'Take time to appreciate your day and all you have accomplished ✨',
    'Look back on your day with gratitude and see your beautiful journey 🌟',
  ];

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

      // Schedule next 10 days on app start
      await scheduleFutureWindow();
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

    // Cancel existing alarms/notifications and reschedule
    await cancelFutureWindow();
    await _notifications.cancelAll();
    if (settings.notificationsEnabled) {
      await scheduleFutureWindow();
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
        errorContext: {'operation': 'notification_settings_sync_call'},
      );
    }
  }

  String? _getCurrentUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  int _getRotationIndexForDate(DateTime date) {
    final daysSinceEpoch = _daysSinceEpoch(date);
    return daysSinceEpoch % 10;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _daysSinceEpoch(DateTime date) {
    return _dateOnly(date).difference(DateTime(1970, 1, 1)).inDays;
  }

  int _alarmIdForDate(int baseId, DateTime date) {
    return baseId + (_daysSinceEpoch(date) * _alarmDayMultiplier);
  }

  String _formatDateKey(DateTime date) {
    return _dateOnly(date).toIso8601String().split('T')[0];
  }

  bool _isActiveDayForDate(DateTime date, List<int> activeDays) {
    return activeDays.contains(date.weekday);
  }

  _NotificationMessage _pickMessage(
    List<String> titles,
    List<String> bodies,
    int index, {
    String? context,
  }) {
    if (titles.isEmpty || bodies.isEmpty) {
      return const _NotificationMessage('Reminder', '');
    }

    if (titles.length != bodies.length) {
      ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS162',
        errorMessage: 'Notification titles/bodies length mismatch',
        errorContext: {
          'context': context,
          'titles_length': titles.length,
          'bodies_length': bodies.length,
        },
      );
    }

    final safeLength = titles.length < bodies.length
        ? titles.length
        : bodies.length;
    final safeIndex = safeLength == 0 ? 0 : index % safeLength;
    return _NotificationMessage(titles[safeIndex], bodies[safeIndex]);
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
    required String dateKey,
  }) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final keyBase = 'alarm_${notificationId}_$dateKey';
      final timeSaved = await _prefs?.setString(
        '${keyBase}_time',
        scheduledTime.toIso8601String(),
      );
      final titleSaved = await _prefs?.setString('${keyBase}_title', title);
      final bodySaved = await _prefs?.setString('${keyBase}_body', body);

      if (timeSaved == false || titleSaved == false || bodySaved == false) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS153',
          errorMessage: 'Failed to persist alarm metadata',
          errorContext: {
            'notification_id': notificationId,
            'scheduled_time': scheduledTime.toIso8601String(),
            'date_key': dateKey,
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

  Future<void> _clearAlarmMetadata(
    int notificationId, {
    String? dateKey,
  }) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final keyBase = dateKey == null
          ? 'alarm_${notificationId}'
          : 'alarm_${notificationId}_$dateKey';
      final timeKey = '${keyBase}_time';
      final titleKey = '${keyBase}_title';
      final bodyKey = '${keyBase}_body';

      final hasAnyKey =
          (_prefs?.containsKey(timeKey) ?? false) ||
          (_prefs?.containsKey(titleKey) ?? false) ||
          (_prefs?.containsKey(bodyKey) ?? false);
      if (!hasAnyKey) {
        return;
      }

      final timeRemoved = await _prefs?.remove(timeKey) ?? false;
      final titleRemoved = await _prefs?.remove(titleKey) ?? false;
      final bodyRemoved = await _prefs?.remove(bodyKey) ?? false;

      if (!timeRemoved || !titleRemoved || !bodyRemoved) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS160',
          errorMessage: 'Failed to clear alarm metadata',
          errorContext: {
            'notification_id': notificationId,
            'date_key': dateKey,
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
        errorContext: {'notification_id': notificationId, 'date_key': dateKey},
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
      await _rescheduleTodayNotifications(userId: userId);
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

  /// Schedule notifications for the next 10 days
  Future<void> scheduleAllNotifications({String? userId}) async {
    await scheduleFutureWindow(userId: userId);
  }

  /// Cancel existing alarms and schedule the next 10 days
  Future<void> scheduleFutureWindow({String? userId}) async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final settings = await getNotificationSettings();
      print('🔔 DEBUG: Scheduling future window - ${settings.toJson()}');

      await _clearLegacyAlarmMetadata();
      await cancelFutureWindow();

      if (!settings.notificationsEnabled) {
        print('🔔 DEBUG: Notifications disabled');
        return;
      }

      final resolvedUserId = userId ?? _getCurrentUserId();
      if (resolvedUserId == null) {
        await ErrorLoggingService.logLowError(
          errorCode: 'ERRSYS158',
          errorMessage: 'User ID missing while scheduling notifications',
          errorContext: {'operation': 'schedule_future_window'},
        );
      }

      final today = _dateOnly(DateTime.now());

      for (var dayOffset = 0; dayOffset < _futureDays; dayOffset++) {
        final targetDate = today.add(Duration(days: dayOffset));
        if (!_isActiveDayForDate(targetDate, settings.activeDays)) {
          continue;
        }

        final isToday = dayOffset == 0;
        final diaryCompleted = isToday && resolvedUserId != null
            ? await _isDiaryCompletedToday(resolvedUserId)
            : false;

        if (isToday && diaryCompleted && _prefs != null) {
          await _prefs!.setBool(
            NotificationStorageKeys.todayMorningCompleted,
            true,
          );
        } else {
          await _scheduleMorningNotificationsForDate(
            targetDate,
            settings.morningTime,
            userId: resolvedUserId,
            allowTomorrowShift: false,
          );
        }

        await _scheduleBedtimeNotificationForDate(
          targetDate: targetDate,
          diaryCompleted: diaryCompleted,
          userId: resolvedUserId,
          allowTomorrowShift: false,
        );
      }

      print('🔔 DEBUG: Future window scheduled successfully!');
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS034',
        errorMessage: 'Failed to schedule future window: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'scheduling_time': DateTime.now().toIso8601String(),
          'settings': (await getNotificationSettings()).toJson(),
        },
      );
    }
  }

  Future<void> cancelFutureWindow() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

      final today = _dateOnly(DateTime.now());
      for (var dayOffset = 0; dayOffset < _futureDays; dayOffset++) {
        final targetDate = today.add(Duration(days: dayOffset));
        await _cancelDayAlarms(targetDate);
      }
    } catch (e, stackTrace) {
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS171',
        errorMessage: 'Failed to cancel future window: ${e.toString()}',
        stackTrace: stackTrace.toString(),
        errorContext: {'cancel_time': DateTime.now().toIso8601String()},
      );
    }
  }

  Future<void> _rescheduleTodayNotifications({String? userId}) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    final settings = await getNotificationSettings();
    if (!settings.notificationsEnabled) {
      return;
    }

    final today = _dateOnly(DateTime.now());
    if (!_isActiveDayForDate(today, settings.activeDays)) {
      return;
    }

    final resolvedUserId = userId ?? _getCurrentUserId();
    final diaryCompleted = resolvedUserId == null
        ? false
        : await _isDiaryCompletedToday(resolvedUserId);

    if (diaryCompleted) {
      await cancelMorningReminders();
    } else {
      await _scheduleMorningNotificationsForDate(
        today,
        settings.morningTime,
        userId: resolvedUserId,
        allowTomorrowShift: false,
      );
    }

    await _scheduleBedtimeNotificationForDate(
      targetDate: today,
      diaryCompleted: diaryCompleted,
      userId: resolvedUserId,
      allowTomorrowShift: false,
    );
  }

  Future<void> _scheduleMorningNotificationsForDate(
    DateTime targetDate,
    TimeOfDay morningTime, {
    String? userId,
    bool allowTomorrowShift = false,
  }) async {
    final now = DateTime.now();
    var scheduledDate = _dateOnly(targetDate);
    var morningDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      morningTime.hour,
      morningTime.minute,
    );

    if (allowTomorrowShift && morningDateTime.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      morningDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        morningTime.hour,
        morningTime.minute,
      );
      print(
        '🔔 DEBUG: Morning time passed today, scheduling for tomorrow: ${morningDateTime.toString()}',
      );
    } else if (!allowTomorrowShift &&
        _isSameDay(scheduledDate, now) &&
        morningDateTime.isBefore(now)) {
      return;
    }

    final dateKey = _formatDateKey(scheduledDate);
    final messageIndex = _getRotationIndexForDate(morningDateTime);
    final firstMessage = _pickMessage(
      _morningTitles,
      _morningBodies,
      messageIndex,
      context: 'morning_reminder_1',
    );
    final secondMessage = _pickMessage(
      _reminder3hTitles,
      _reminder3hBodies,
      messageIndex,
      context: 'morning_reminder_2',
    );
    final thirdMessage = _pickMessage(
      _reminder6hTitles,
      _reminder6hBodies,
      messageIndex,
      context: 'morning_reminder_3',
    );

    final reminder1Id = _alarmIdForDate(morningReminder1Id, scheduledDate);
    final reminder2Id = _alarmIdForDate(morningReminder2Id, scheduledDate);
    final reminder3Id = _alarmIdForDate(morningReminder3Id, scheduledDate);

    // First reminder - at user's chosen time
    await _scheduleAlarmWithLogging(
      notificationId: reminder1Id,
      title: firstMessage.title,
      body: firstMessage.body,
      scheduledTime: morningDateTime,
      context: 'morning_reminder_1',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: reminder1Id,
      scheduledTime: morningDateTime,
      title: firstMessage.title,
      body: firstMessage.body,
      dateKey: dateKey,
    );

    // Second reminder - +3 hours
    final reminder2Time = morningDateTime.add(const Duration(hours: 3));
    await _scheduleAlarmWithLogging(
      notificationId: reminder2Id,
      title: secondMessage.title,
      body: secondMessage.body,
      scheduledTime: reminder2Time,
      context: 'morning_reminder_2',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: reminder2Id,
      scheduledTime: reminder2Time,
      title: secondMessage.title,
      body: secondMessage.body,
      dateKey: dateKey,
    );

    // Third reminder - +6 hours
    final reminder3Time = morningDateTime.add(const Duration(hours: 6));
    await _scheduleAlarmWithLogging(
      notificationId: reminder3Id,
      title: thirdMessage.title,
      body: thirdMessage.body,
      scheduledTime: reminder3Time,
      context: 'morning_reminder_3',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: reminder3Id,
      scheduledTime: reminder3Time,
      title: thirdMessage.title,
      body: thirdMessage.body,
      dateKey: dateKey,
    );
  }

  Future<void> _scheduleBedtimeNotificationForDate({
    required DateTime targetDate,
    required bool diaryCompleted,
    String? userId,
    bool allowTomorrowShift = false,
  }) async {
    final now = DateTime.now();
    var scheduledDate = _dateOnly(targetDate);
    var bedtimeDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      21, // 9:00 PM
      0,
    );

    if (allowTomorrowShift && bedtimeDateTime.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      bedtimeDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        21,
        0,
      );
      print(
        '🔔 DEBUG: Bedtime time passed today, scheduling for tomorrow: ${bedtimeDateTime.toString()}',
      );
    } else if (!allowTomorrowShift &&
        _isSameDay(scheduledDate, now) &&
        bedtimeDateTime.isBefore(now)) {
      return;
    }

    final dateKey = _formatDateKey(scheduledDate);
    final messageIndex = _getRotationIndexForDate(bedtimeDateTime);
    final bedtimeMessage = diaryCompleted
        ? _pickMessage(
            _bedtimeFilledTitles,
            _bedtimeFilledBodies,
            messageIndex,
            context: 'bedtime_reminder_filled',
          )
        : _pickMessage(
            _bedtimeNotFilledTitles,
            _bedtimeNotFilledBodies,
            messageIndex,
            context: 'bedtime_reminder_not_filled',
          );

    final bedtimeId = _alarmIdForDate(bedtimeReminderId, scheduledDate);
    await _scheduleAlarmWithLogging(
      notificationId: bedtimeId,
      title: bedtimeMessage.title,
      body: bedtimeMessage.body,
      scheduledTime: bedtimeDateTime,
      context: 'bedtime_reminder',
      userId: userId,
    );
    await _storeAlarmMetadata(
      notificationId: bedtimeId,
      scheduledTime: bedtimeDateTime,
      title: bedtimeMessage.title,
      body: bedtimeMessage.body,
      dateKey: dateKey,
    );
  }

  Future<void> _cancelDayAlarms(DateTime date) async {
    final userId = _getCurrentUserId();
    final dateKey = _formatDateKey(date);

    final reminder1Id = _alarmIdForDate(morningReminder1Id, date);
    final reminder2Id = _alarmIdForDate(morningReminder2Id, date);
    final reminder3Id = _alarmIdForDate(morningReminder3Id, date);
    final bedtimeId = _alarmIdForDate(bedtimeReminderId, date);

    final keyBase1 = 'alarm_${reminder1Id}_$dateKey';
    final keyBase2 = 'alarm_${reminder2Id}_$dateKey';
    final keyBase3 = 'alarm_${reminder3Id}_$dateKey';
    final keyBaseBedtime = 'alarm_${bedtimeId}_$dateKey';

    final shouldCancel1 = _prefs?.containsKey('${keyBase1}_time') ?? false;
    final shouldCancel2 = _prefs?.containsKey('${keyBase2}_time') ?? false;
    final shouldCancel3 = _prefs?.containsKey('${keyBase3}_time') ?? false;
    final shouldCancelBedtime =
        _prefs?.containsKey('${keyBaseBedtime}_time') ?? false;

    if (shouldCancel1) {
      await _cancelAlarmWithLogging(
        notificationId: reminder1Id,
        context: 'cancel_morning_reminder_1',
        userId: userId,
      );
      await _clearAlarmMetadata(reminder1Id, dateKey: dateKey);
    }

    if (shouldCancel2) {
      await _cancelAlarmWithLogging(
        notificationId: reminder2Id,
        context: 'cancel_morning_reminder_2',
        userId: userId,
      );
      await _clearAlarmMetadata(reminder2Id, dateKey: dateKey);
    }

    if (shouldCancel3) {
      await _cancelAlarmWithLogging(
        notificationId: reminder3Id,
        context: 'cancel_morning_reminder_3',
        userId: userId,
      );
      await _clearAlarmMetadata(reminder3Id, dateKey: dateKey);
    }

    if (shouldCancelBedtime) {
      await _cancelAlarmWithLogging(
        notificationId: bedtimeId,
        context: 'cancel_bedtime_reminder',
        userId: userId,
      );
      await _clearAlarmMetadata(bedtimeId, dateKey: dateKey);
    }
  }

  Future<void> _clearLegacyAlarmMetadata() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    for (final id in [
      morningReminder1Id,
      morningReminder2Id,
      morningReminder3Id,
      bedtimeReminderId,
    ]) {
      final hasLegacy =
          (_prefs?.containsKey('alarm_${id}_time') ?? false) ||
          (_prefs?.containsKey('alarm_${id}_title') ?? false) ||
          (_prefs?.containsKey('alarm_${id}_body') ?? false);

      if (hasLegacy) {
        await _cancelAlarmWithLogging(
          notificationId: id,
          context: 'cancel_legacy_alarm',
          userId: _getCurrentUserId(),
        );
        await _notifications.cancel(id);
        await _clearAlarmMetadata(id);
      }
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

  /// Cancel morning reminders using Native AlarmManager
  Future<void> cancelMorningReminders() async {
    final today = _dateOnly(DateTime.now());
    final dateKey = _formatDateKey(today);
    final reminder1Id = _alarmIdForDate(morningReminder1Id, today);
    final reminder2Id = _alarmIdForDate(morningReminder2Id, today);
    final reminder3Id = _alarmIdForDate(morningReminder3Id, today);

    try {
      final userId = _getCurrentUserId();

      // Cancel native alarms
      await _cancelAlarmWithLogging(
        notificationId: reminder1Id,
        context: 'cancel_morning_reminder_1',
        userId: userId,
      );
      await _clearAlarmMetadata(reminder1Id, dateKey: dateKey);
      await _cancelAlarmWithLogging(
        notificationId: reminder2Id,
        context: 'cancel_morning_reminder_2',
        userId: userId,
      );
      await _clearAlarmMetadata(reminder2Id, dateKey: dateKey);
      await _cancelAlarmWithLogging(
        notificationId: reminder3Id,
        context: 'cancel_morning_reminder_3',
        userId: userId,
      );
      await _clearAlarmMetadata(reminder3Id, dateKey: dateKey);

      // Also cancel any shown notifications
      await _notifications.cancel(reminder1Id);
      await _notifications.cancel(reminder2Id);
      await _notifications.cancel(reminder3Id);

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
          'reminder_ids': [reminder1Id, reminder2Id, reminder3Id],
        },
      );
    }
  }

  /// Cancel bedtime reminder using Native AlarmManager
  Future<void> cancelBedtimeReminder() async {
    final today = _dateOnly(DateTime.now());
    final dateKey = _formatDateKey(today);
    final bedtimeId = _alarmIdForDate(bedtimeReminderId, today);

    try {
      final userId = _getCurrentUserId();

      // Cancel native alarm
      await _cancelAlarmWithLogging(
        notificationId: bedtimeId,
        context: 'cancel_bedtime_reminder',
        userId: userId,
      );
      await _clearAlarmMetadata(bedtimeId, dateKey: dateKey);

      // Also cancel any shown notification
      await _notifications.cancel(bedtimeId);

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
          'reminder_id': bedtimeId,
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
        await _rescheduleTodayNotifications();
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
        await _rescheduleTodayNotifications();
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
