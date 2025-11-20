import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../widgets/app_drawer.dart';

class NotificationTestScreen extends ConsumerStatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  ConsumerState<NotificationTestScreen> createState() =>
      _NotificationTestScreenState();
}

class _NotificationTestScreenState
    extends ConsumerState<NotificationTestScreen> {
  String _status = 'Initializing...';
  NotificationSettings? _currentSettings;
  Timer? _timer;
  String _currentTime = '';
  String _scheduledTimes = '';
  String _timeDifference = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startRealTimeMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRealTimeMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now().toString();
        _updateScheduledTimes();
      });
    });
  }

  void _updateScheduledTimes() {
    if (_currentSettings != null) {
      final now = DateTime.now();
      final morningTime = _currentSettings!.morningTime;

      // Calculate scheduled times
      var morningDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        morningTime.hour,
        morningTime.minute,
      );

      // Check if morning time has passed today
      final hasMorningPassed = morningDateTime.isBefore(now);

      // If time has passed, show tomorrow's time
      if (hasMorningPassed) {
        morningDateTime = morningDateTime.add(const Duration(days: 1));
      }

      _scheduledTimes =
          '''
Morning: ${morningDateTime.toString()}
+3h: ${morningDateTime.add(const Duration(hours: 3)).toString()}
+6h: ${morningDateTime.add(const Duration(hours: 6)).toString()}
Bedtime: ${DateTime(now.year, now.month, now.day, 23, 18).toString()}
      '''
              .trim();

      // Calculate time difference to next notification
      final nextNotification = morningDateTime;
      final difference = nextNotification.difference(now);

      if (hasMorningPassed) {
        _timeDifference =
            'Morning time passed today - next notification tomorrow in ${difference.inMinutes} minutes';
      } else {
        _timeDifference =
            'Next notification in: ${difference.inMinutes} minutes, ${difference.inSeconds % 60} seconds';
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await NotificationService.instance
          .getNotificationSettings();
      setState(() {
        _currentSettings = settings;
        _status = 'Settings loaded successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading settings: $e';
      });
    }
  }

  Future<void> _testScheduleNotifications() async {
    setState(() {
      _status = 'Scheduling test notifications...';
    });

    try {
      await NotificationService.instance.scheduleAllNotifications();
      setState(() {
        _status = 'Test notifications scheduled successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error scheduling notifications: $e';
      });
    }
  }

  Future<void> _testCancelMorningReminders() async {
    setState(() {
      _status = 'Cancelling morning reminders...';
    });

    try {
      await NotificationService.instance.cancelMorningReminders();
      setState(() {
        _status = 'Morning reminders cancelled successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error cancelling morning reminders: $e';
      });
    }
  }

  Future<void> _testCancelBedtimeReminder() async {
    setState(() {
      _status = 'Cancelling bedtime reminder...';
    });

    try {
      await NotificationService.instance.cancelBedtimeReminder();
      setState(() {
        _status = 'Bedtime reminder cancelled successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error cancelling bedtime reminder: $e';
      });
    }
  }

  Future<void> _testDailyReset() async {
    setState(() {
      _status = 'Testing daily reset...';
    });

    try {
      await NotificationService.instance.checkAndResetDailyStatus();
      setState(() {
        _status = 'Daily reset completed successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error during daily reset: $e';
      });
    }
  }

  Future<void> _resetCompletionStatus() async {
    setState(() {
      _status = 'Resetting completion status...';
    });

    try {
      await NotificationService.instance.resetCompletionStatus();
      setState(() {
        _status = 'Completion status reset successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error resetting completion status: $e';
      });
    }
  }

  Future<void> _testImmediateNotification() async {
    setState(() {
      _status = 'Sending immediate test notification...';
    });

    try {
      await NotificationService.instance.testImmediateNotification();
      setState(() {
        _status =
            'Immediate test notification sent! Check your notification panel.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error sending immediate notification: $e';
      });
    }
  }

  Future<void> _testHardcodedNotification() async {
    setState(() {
      _status = 'Scheduling hardcoded 5-minute notification...';
    });

    try {
      await NotificationService.instance.testHardcodedNotification();
      setState(() {
        _status = 'Hardcoded 5-minute notification scheduled! Wait 5 minutes.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error scheduling hardcoded notification: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(currentRoute: 'notification_test'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Real-time monitoring display
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🕐 Real-Time Monitoring:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Current Time: $_currentTime'),
                    const SizedBox(height: 8),
                    Text(
                      _timeDifference,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _timeDifference.contains('0 minutes')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Scheduled times display
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📅 Scheduled Times:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _scheduledTimes.isEmpty ? 'Loading...' : _scheduledTimes,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current settings display
            if (_currentSettings != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚙️ Current Settings:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Morning Time: ${_currentSettings!.morningTime.format(context)}',
                      ),
                      Text('Active Days: ${_currentSettings!.activeDays}'),
                      Text(
                        'Notifications Enabled: ${_currentSettings!.notificationsEnabled}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Test buttons
            const Text(
              'Test Functions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),

            // Schedule notifications button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testScheduleNotifications,
                icon: const Icon(Icons.schedule),
                label: const Text('Schedule Test Notifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel morning reminders button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testCancelMorningReminders,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Morning Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel bedtime reminder button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testCancelBedtimeReminder,
                icon: const Icon(Icons.bedtime),
                label: const Text('Cancel Bedtime Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Daily reset button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testDailyReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Test Daily Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Reset completion status button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetCompletionStatus,
                icon: const Icon(Icons.restore),
                label: const Text('Reset Completion Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Immediate test notification button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testImmediateNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Immediate Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Hardcoded 5-minute test button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testHardcodedNotification,
                icon: const Icon(Icons.timer),
                label: const Text('Test Hardcoded 5-Minute Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Tap "Schedule Test Notifications" to schedule notifications for today',
                    ),
                    const Text(
                      '2. Check your device\'s notification panel to see scheduled notifications',
                    ),
                    const Text(
                      '3. Use cancel buttons to test cancellation functionality',
                    ),
                    const Text(
                      '4. Use "Test Daily Reset" to reset completion status',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: Notifications will appear at the scheduled times. For immediate testing, you may need to adjust the time in Settings.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
