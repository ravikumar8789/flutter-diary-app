import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

/// Temporary debug widget to show all notification and SharedPreferences data
/// TODO: Remove after debugging
class DebugNotificationBottomSheet extends StatefulWidget {
  const DebugNotificationBottomSheet({super.key});

  @override
  State<DebugNotificationBottomSheet> createState() =>
      _DebugNotificationBottomSheetState();
}

class _DebugNotificationBottomSheetState
    extends State<DebugNotificationBottomSheet> {
  Map<String, dynamic> _sharedPrefsData = {};
  Map<String, dynamic> _alarmMetadata = {};
  Map<String, dynamic> _notificationSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all SharedPreferences keys
      final allKeys = prefs.getKeys();
      _sharedPrefsData = {};
      for (final key in allKeys) {
        final value = prefs.get(key);
        _sharedPrefsData[key] = value?.toString() ?? 'null';
      }

        // Extract alarm metadata (supports both old format: alarm_{id}_time and new format: alarm_{id}_{date}_time)
      _alarmMetadata = {};
      for (final key in allKeys) {
        if (key.startsWith('alarm_')) {
          final value = prefs.get(key);
          _alarmMetadata[key] = value?.toString() ?? 'null';
        }
      }

      // Get notification settings
      final settings = await NotificationService.instance.getNotificationSettings();
      _notificationSettings = {
        'morning_time': '${settings.morningTime.hour}:${settings.morningTime.minute.toString().padLeft(2, '0')}',
        'active_days': settings.activeDays.toString(),
        'notifications_enabled': settings.notificationsEnabled.toString(),
      };

      // Get last scheduled date if exists
      final lastScheduled = prefs.getString('last_scheduled_date');
      if (lastScheduled != null) {
        _notificationSettings['last_scheduled_date'] = lastScheduled;
      }

      // Get last reset date
      final lastReset = prefs.getString('last_reset_date');
      if (lastReset != null) {
        _notificationSettings['last_reset_date'] = lastReset;
      }
    } catch (e) {
      _sharedPrefsData['error'] = e.toString();
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Debug: Notification Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Refresh button
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Data'),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Settings'),
                        Tab(text: 'Alarm Metadata'),
                        Tab(text: 'All SharedPrefs'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Notification Settings Tab
                          _buildSettingsTab(),
                          // Alarm Metadata Tab
                          _buildAlarmMetadataTab(),
                          // All SharedPreferences Tab
                          _buildAllSharedPrefsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Text(
          'Notification Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._notificationSettings.entries.map((entry) => _buildKeyValueCard(
              entry.key,
              entry.value,
            )),
      ],
    );
  }

  Widget _buildAlarmMetadataTab() {
    if (_alarmMetadata.isEmpty) {
      return const Center(
        child: Text('No alarm metadata found'),
      );
    }

    // Group alarms by ID and date
    // Supports both formats:
    // Old: alarm_{id}_time, alarm_{id}_title, alarm_{id}_body
    // New: alarm_{id}_{date}_time, alarm_{id}_{date}_title, alarm_{id}_{date}_body
    final Map<String, Map<String, String>> groupedAlarms = {};
    for (final entry in _alarmMetadata.entries) {
      final key = entry.key;
      final parts = key.split('_');
      
      if (parts.length >= 3) {
        final alarmId = parts[1];
        String date = 'today'; // Default for old format
        String type = 'unknown';
        
        // Check if it's new format with date (alarm_{id}_{date}_{type})
        if (parts.length >= 4) {
          // Try to parse date (format: YYYY-MM-DD)
          final possibleDate = parts[2];
          if (possibleDate.contains('-') && possibleDate.length == 10) {
            date = possibleDate;
            type = parts.length > 3 ? parts[3] : 'unknown';
          } else {
            // Old format: alarm_{id}_{type}
            type = parts[2];
          }
        } else {
          // Old format: alarm_{id}_{type}
          type = parts[2];
        }
        
        final groupKey = '$alarmId|$date';
        if (!groupedAlarms.containsKey(groupKey)) {
          groupedAlarms[groupKey] = {'alarm_id': alarmId, 'date': date};
        }
        groupedAlarms[groupKey]![type] = entry.value;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Text(
          'Scheduled Alarms',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...groupedAlarms.entries.map((entry) {
          final data = entry.value;
          final alarmId = data['alarm_id'] ?? 'unknown';
          final date = data['date'] ?? 'unknown';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alarm ID: $alarmId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (date != 'today')
                    Text(
                      'Date: $date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (data.containsKey('time'))
                    _buildKeyValueRow('Scheduled Time', data['time']!),
                  if (data.containsKey('title'))
                    _buildKeyValueRow('Title', data['title']!),
                  if (data.containsKey('body'))
                    _buildKeyValueRow('Body', data['body']!),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAllSharedPrefsTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Text(
          'All SharedPreferences',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._sharedPrefsData.entries.map((entry) => _buildKeyValueCard(
              entry.key,
              entry.value,
            )),
      ],
    );
  }

  Widget _buildKeyValueCard(String key, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$key:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
