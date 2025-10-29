import 'package:flutter/services.dart';

/// Native Android AlarmManager wrapper
/// This uses platform channels to schedule alarms directly in native code
/// Guarantees notifications work when app is closed
class NativeAlarmManager {
  static const platform = MethodChannel('com.zen.diaryapp/native_alarm');

  /// Schedule an alarm using native Android AlarmManager
  static Future<bool> scheduleAlarm({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final result = await platform.invokeMethod('scheduleAlarm', {
        'notification_id': notificationId,
        'title': title,
        'body': body,
        'scheduled_time_millis': scheduledTime.millisecondsSinceEpoch,
      });

      print(
        '🔔 NATIVE: Alarm $notificationId scheduled for ${scheduledTime.toString()}',
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel an alarm using native Android AlarmManager
  static Future<bool> cancelAlarm(int notificationId) async {
    try {
      final result = await platform.invokeMethod('cancelAlarm', {
        'notification_id': notificationId,
      });

      return result == true;
    } catch (e) {
      return false;
    }
  }
}
