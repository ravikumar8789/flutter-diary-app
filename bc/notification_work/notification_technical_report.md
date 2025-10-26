# **Diary App Notification System - Technical Implementation Report**

## **1. System Architecture Overview**

### **Technical Stack:**
- **Frontend**: Flutter (Dart)
- **Local Storage**: Shared Preferences
- **Notifications**: Flutter Local Notifications Plugin
- **Timezone**: Timezone Package
- **State Management**: Provider/Riverpod (to be determined)

### **Core Components:**
```
NotificationService (Singleton)
├── Initialization Manager
├── Permission Handler
├── Scheduler Engine
├── Cancellation Controller
└── Storage Adapter
```

---

## **2. Package Dependencies & Setup**

### **Required Packages:**
```yaml
dependencies:
  flutter_local_notifications: ^16.3.0
  timezone: ^0.9.1
  shared_preferences: ^2.2.2
  permission_handler: ^11.0.0
```

### **Platform-Specific Configuration:**

**Android:**
- Notification channels creation
- Foreground service permission (if needed)
- Battery optimization exemption

**iOS:**
- Notification categories setup
- Background modes configuration
- Permission descriptions in Info.plist

---

## **3. Notification Service Class Structure**

### **Core Class Architecture:**
```dart
class NotificationService {
  // Dependencies
  final FlutterLocalNotificationsPlugin _notifications;
  final SharedPreferences _prefs;
  
  // State Management
  final _notificationStreamController = StreamController<NotificationResponse>();
  
  // Public API
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> scheduleAllNotifications();
  Future<void> cancelMorningReminders();
  Future<void> cancelBedtimeReminder();
  Future<void> updateUserSettings(NotificationSettings settings);
}
```

---

## **4. Data Models & Storage Schema**

### **Data Models:**
```dart
class NotificationSettings {
  final TimeOfDay morningTime;
  final List<int> activeDays; // [1,2,3,4,5] for Mon-Fri
  final bool notificationsEnabled;
}

class DailyCompletion {
  final DateTime date;
  final bool morningCompleted;
  final bool bedtimeCompleted;
}
```

### **Storage Keys:**
```dart
class StorageKeys {
  static const String morningTime = 'morning_time';
  static const String activeDays = 'active_days';
  static const String todayMorningCompleted = 'today_morning';
  static const String todayBedtimeCompleted = 'today_bedtime';
  static const String lastScheduledDate = 'last_scheduled';
}
```

---

## **5. Notification Scheduling Engine**

### **Scheduling Algorithm:**
```dart
Future<void> _scheduleMorningNotifications(TimeOfDay morningTime) async {
  // Convert user time to today's DateTime
  final now = tz.TZDateTime.now(tz.local);
  final morningDateTime = tz.TZDateTime(
    tz.local, now.year, now.month, now.day, morningTime.hour, morningTime.minute
  );
  
  // Schedule three progressive notifications
  await _scheduleSingleNotification(
    id: 1001,
    title: 'Good morning! Time for your daily affirmation 🌅',
    scheduledDate: morningDateTime,
    payload: {'type': 'morning_reminder_1'}
  );
  
  await _scheduleSingleNotification(
    id: 1002,
    title: 'Your daily affirmation is waiting! ✨',
    scheduledDate: morningDateTime.add(Duration(hours: 3)),
    payload: {'type': 'morning_reminder_2'}
  );
  
  await _scheduleSingleNotification(
    id: 1003,
    title: 'Protect your streak! 🛡️',
    scheduledDate: morningDateTime.add(Duration(hours: 6)),
    payload: {'type': 'morning_reminder_3'}
  );
}
```

### **Timezone Handling:**
- All scheduling uses device local timezone
- Convert to UTC for storage, back to local for display
- Handle DST changes automatically

---

## **6. Smart Cancellation System**

### **Cancellation Logic:**
```dart
Future<void> cancelMorningReminders() async {
  // Cancel all morning reminder IDs
  await _notifications.cancel(1001);
  await _notifications.cancel(1002);
  await _notifications.cancel(1003);
  
  // Update completion status
  await _prefs.setBool(StorageKeys.todayMorningCompleted, true);
}

Future<void> cancelBedtimeReminder() async {
  await _notifications.cancel(2001); // Bedtime ID
  await _prefs.setBool(StorageKeys.todayBedtimeCompleted, true);
}
```

### **Complete Rescheduling:**
```dart
Future<void> rescheduleAllNotifications() async {
  // 1. Cancel everything
  await _notifications.cancelAll();
  
  // 2. Check if today is active day
  if (!_isTodayActiveDay()) return;
  
  // 3. Check completion status
  final morningCompleted = _prefs.getBool(StorageKeys.todayMorningCompleted) ?? false;
  final bedtimeCompleted = _prefs.getBool(StorageKeys.todayBedtimeCompleted) ?? false;
  
  // 4. Schedule only incomplete items
  if (!morningCompleted) {
    await _scheduleMorningNotifications(_getMorningTime());
  }
  if (!bedtimeCompleted) {
    await _scheduleBedtimeNotification();
  }
}
```

---

## **7. Daily Reset Mechanism**

### **Reset Trigger Options:**
1. **App Launch Detection** - Check if new day on every app open
2. **Background Task** - Daily scheduled check (complex)
3. **Midnight Timer** - While app is running (limited)

### **Recommended Approach:**
```dart
Future<void> checkAndResetDailyStatus() async {
  final today = DateTime.now();
  final lastReset = _getLastResetDate();
  
  if (!_isSameDay(today, lastReset)) {
    // New day detected
    await _resetDailyCompletion();
    await _scheduleAllNotifications();
    await _updateLastResetDate(today);
  }
}
```

---

## **8. Error Handling & Edge Cases**

### **Critical Error Scenarios:**

**1. Permission Denied:**
- Fallback to in-app notification center
- Show educational prompt about benefits
- Provide quick settings deep link

**2. Scheduling Failures:**
- Retry logic with exponential backoff
- Log errors for debugging
- User-friendly error messages

**3. Storage Corruption:**
- Default settings fallback
- Data validation on read/write
- Recovery mechanisms

### **Validation Methods:**
```dart
bool _validateNotificationSettings(NotificationSettings settings) {
  return settings.morningTime.hour >= 4 && 
         settings.morningTime.hour <= 16 &&
         settings.activeDays.isNotEmpty;
}
```

---

## **9. Performance Optimization**

### **Memory Management:**
- Singleton pattern for NotificationService
- Stream-based notification responses
- Efficient cancellation by ID ranges

### **Battery Optimization:**
- Batch scheduling operations
- Minimal background processing
- Efficient storage operations

### **Storage Optimization:**
- Minimal data persistence
- Efficient key-value storage
- Regular cleanup of old data

---

## **10. Testing Strategy**

### **Unit Tests:**
- Scheduling logic with mock time
- Cancellation scenarios
- Settings validation
- Timezone conversion

### **Integration Tests:**
- Full notification flow
- Permission handling
- Storage persistence
- Real device scheduling

### **Test Scenarios:**
```dart
test('Should cancel morning reminders when entry completed', () async {
  // Setup scheduled notifications
  // Simulate morning entry completion
  // Verify reminders are cancelled
  // Verify storage updated correctly
});
```

---

## **11. Monitoring & Analytics**

### **Key Metrics to Track:**
- Notification permission grant rate
- Scheduling success/failure rates
- Cancellation trigger events
- User interaction with notifications

### **Error Tracking:**
- Permission denial reasons
- Scheduling failures
- Storage read/write errors
- Timezone conversion issues

---

## **12. Security Considerations**

### **Data Privacy:**
- All data stored locally only
- No personal data in notification payloads
- Secure storage practices

### **Notification Security:**
- Validate all notification payloads
- Sanitize user-input data in messages
- Prevent notification spoofing

---

## **Implementation Priority Order:**

1. **Phase 1**: Basic scheduling & cancellation
2. **Phase 2**: Settings persistence & daily reset
3. **Phase 3**: Error handling & edge cases
4. **Phase 4**: Performance optimization
5. **Phase 5**: Advanced features (timezone, analytics)

This technical architecture provides a robust foundation for reliable local notifications that work seamlessly even when the app is closed, while maintaining excellent user experience and system performance.