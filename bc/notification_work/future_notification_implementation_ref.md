# Future Push Notification Implementation Reference

## Overview
This document outlines how to integrate **Supabase Push Notifications** with the existing **local notification system** without disturbing current functionality.

---

## Current System Architecture

### ✅ Working Local Notifications (AlarmManager)
- **Location**: `lib/services/notification_service.dart`
- **Technology**: `android_alarm_manager_plus` + `flutter_local_notifications`
- **Notification Types**:
  1. Morning Reminders (3-tier: at time, +3h, +6h)
  2. Bedtime Reminder (9 PM default)
- **Key Features**:
  - User-configurable time and days
  - Smart cancellation on entry completion
  - Daily reset at midnight
  - Survives device reboots

### 🎯 Top-Level Callback Functions (Critical!)
```dart
@pragma('vm:entry-point')
Future<void> showMorningReminder1Callback() async { ... }

@pragma('vm:entry-point')
Future<void> showMorningReminder2Callback() async { ... }

@pragma('vm:entry-point')
Future<void> showMorningReminder3Callback() async { ... }

@pragma('vm:entry-point')
Future<void> showBedtimeReminderCallback() async { ... }
```

**⚠️ CRITICAL**: These MUST remain top-level for AlarmManager to access them!

---

## Push Notification Integration Strategy

### 📋 Use Cases for Push Notifications

#### 1. **Social Features** (Future)
- Friend requests
- Comments on entries
- Shared diary updates
- Community interactions

#### 2. **Cloud-Triggered Reminders**
- Streak about to break (no entry for 3 days)
- Weekly summary available
- Monthly reflection prompt
- Special events (birthdays, anniversaries)

#### 3. **Admin/Marketing** (Optional)
- App updates
- New features
- Special promotions
- System maintenance

---

## Implementation Plan

### Phase 1: Setup (No Code Changes to Existing System)

#### Dependencies to Add
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
  flutter_local_notifications: ^17.0.0  # Already added ✅
```

#### Files Structure
```
lib/
├── services/
│   ├── notification_service.dart         # ✅ Local notifications (KEEP AS IS)
│   ├── push_notification_service.dart    # 🆕 New file for push
│   └── notification_coordinator.dart     # 🆕 Coordinates both systems
```

---

### Phase 2: Firebase Setup

#### 1. Firebase Console Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Add Android app with package name: `com.zen.diaryapp`
3. Download `google-services.json` → Place in `android/app/`
4. Add iOS app (if needed)

#### 2. Android Configuration

**File**: `android/build.gradle.kts`
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

**File**: `android/app/build.gradle.kts`
```kotlin
plugins {
    id("com.google.gms.google-services")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
```

#### 3. AndroidManifest.xml Updates

**File**: `android/app/src/main/AndroidManifest.xml`
```xml
<application>
    <!-- Existing AlarmManager services - DO NOT TOUCH ✅ -->
    
    <!-- 🆕 Firebase Messaging Service -->
    <service
        android:name=".FirebaseMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
    
    <!-- 🆕 Default notification channel for FCM -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="push_notifications" />
</application>
```

---

### Phase 3: Code Implementation

#### 1. Create Push Notification Service

**File**: `lib/services/push_notification_service.dart`
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Top-level handler for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 PUSH: Background message received: ${message.messageId}');
  
  // Handle background notification
  await _showPushNotification(
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? '',
    message.data,
  );
}

// Helper to show push notifications
Future<void> _showPushNotification(
  String title,
  String body,
  Map<String, dynamic> data,
) async {
  final notifications = FlutterLocalNotificationsPlugin();
  
  await notifications.show(
    data['notification_id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'push_notifications',  // Different channel from local notifications!
        'Push Notifications',
        channelDescription: 'Notifications from server',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

class PushNotificationService {
  static final PushNotificationService _instance = 
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static PushNotificationService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  /// Initialize Firebase Messaging
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 PUSH: Permission granted');
      
      // Get FCM token
      _fcmToken = await _messaging.getToken();
      print('🔔 PUSH: FCM Token: $_fcmToken');
      
      // Save token to Supabase
      await _saveFCMTokenToSupabase(_fcmToken!);
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveFCMTokenToSupabase);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 PUSH: Foreground message: ${message.messageId}');
    
    // Show notification when app is in foreground
    _showPushNotification(
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      message.data,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 PUSH: Notification tapped: ${message.data}');
    
    // Navigate based on notification data
    // Example: Navigate to specific screen
    // navigatorKey.currentState?.pushNamed(message.data['route']);
  }

  /// Save FCM token to Supabase
  Future<void> _saveFCMTokenToSupabase(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('user_fcm_tokens')
          .upsert({
            'user_id': userId,
            'fcm_token': token,
            'platform': 'android',
            'updated_at': DateTime.now().toIso8601String(),
          });

      print('🔔 PUSH: Token saved to Supabase');
    } catch (e) {
      print('🔔 PUSH: Error saving token: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;
}
```

---

#### 2. Create Notification Coordinator

**File**: `lib/services/notification_coordinator.dart`
```dart
import 'notification_service.dart';
import 'push_notification_service.dart';

/// Coordinates local and push notifications
class NotificationCoordinator {
  static final NotificationCoordinator _instance = 
      NotificationCoordinator._internal();
  factory NotificationCoordinator() => _instance;
  NotificationCoordinator._internal();

  static NotificationCoordinator get instance => _instance;

  final NotificationService _localNotifications = NotificationService.instance;
  final PushNotificationService _pushNotifications = 
      PushNotificationService.instance;

  /// Initialize all notification systems
  Future<void> initializeAll() async {
    // Initialize local notifications (existing system)
    await _localNotifications.initialize();
    await _localNotifications.requestPermissions();
    
    // Initialize push notifications (new system)
    await _pushNotifications.initialize();
  }

  /// Schedule local notifications (for daily reminders)
  Future<void> scheduleLocalNotifications() async {
    await _localNotifications.scheduleAllNotifications();
  }

  /// Cancel local notifications
  Future<void> cancelLocalMorningReminders() async {
    await _localNotifications.cancelMorningReminders();
  }

  Future<void> cancelLocalBedtimeReminder() async {
    await _localNotifications.cancelBedtimeReminder();
  }
}
```

---

#### 3. Update main.dart

**File**: `lib/main.dart`
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_notification_service.dart';
import 'services/notification_coordinator.dart';

// Register background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase BEFORE everything else
  await Firebase.initializeApp();
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Android Alarm Manager (for local notifications)
  await AndroidAlarmManager.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class _MyAppState extends State<MyApp> {
  // Replace individual services with coordinator
  final NotificationCoordinator _notificationCoordinator = 
      NotificationCoordinator.instance;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize all notification systems (local + push)
    await _notificationCoordinator.initializeAll();
    
    // ... rest of initialization
  }
}
```

---

### Phase 4: Supabase Database Schema

#### Create FCM Tokens Table
```sql
-- Store user FCM tokens
CREATE TABLE user_fcm_tokens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'android' or 'ios'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, platform)
);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only manage their own tokens
CREATE POLICY "Users can manage their own FCM tokens"
  ON user_fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id);

-- Index for faster lookups
CREATE INDEX idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
```

#### Create Notification History Table
```sql
-- Track sent notifications
CREATE TABLE notification_history (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL, -- 'streak_reminder', 'weekly_summary', etc.
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  opened_at TIMESTAMP WITH TIME ZONE,
  delivery_status TEXT DEFAULT 'sent' -- 'sent', 'delivered', 'opened', 'failed'
);

-- Enable RLS
ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;

-- Policy
CREATE POLICY "Users can view their own notification history"
  ON notification_history
  FOR SELECT
  USING (auth.uid() = user_id);

-- Index
CREATE INDEX idx_notification_history_user_id ON notification_history(user_id);
CREATE INDEX idx_notification_history_sent_at ON notification_history(sent_at);
```

---

### Phase 5: Supabase Edge Function (Server-Side Push)

#### Create Edge Function for Sending Push Notifications

**File**: `supabase/functions/send-push-notification/index.ts`
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')!

serve(async (req) => {
  try {
    const { userId, title, body, data } = await req.json()

    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get user's FCM token
    const { data: tokenData, error } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token')
      .eq('user_id', userId)
      .single()

    if (error || !tokenData) {
      throw new Error('No FCM token found for user')
    }

    // Send FCM notification
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${fcmServerKey}`
      },
      body: JSON.stringify({
        to: tokenData.fcm_token,
        notification: { title, body },
        data: data || {},
        priority: 'high'
      })
    })

    const fcmResult = await fcmResponse.json()

    // Log to notification history
    await supabase.from('notification_history').insert({
      user_id: userId,
      notification_type: data?.type || 'general',
      title,
      body,
      data,
      delivery_status: fcmResult.success ? 'sent' : 'failed'
    })

    return new Response(JSON.stringify({ success: true, fcmResult }), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
```

---

### Phase 6: Testing Strategy

#### Test Scenarios

1. **Local Notifications (Existing System)**
   - ✅ Morning reminders at user time
   - ✅ +3h and +6h follow-ups
   - ✅ Bedtime reminder at 9 PM
   - ✅ Smart cancellation on entry completion

2. **Push Notifications (New System)**
   - ✅ Receive notification when app is closed
   - ✅ Receive notification when app is in background
   - ✅ Receive notification when app is in foreground
   - ✅ Navigate to correct screen on tap
   - ✅ Token refresh on app reinstall

3. **Coordination Between Systems**
   - ✅ Both systems work independently
   - ✅ No conflicts between local and push
   - ✅ Different notification channels
   - ✅ Proper permission handling

---

## Key Architectural Decisions

### ✅ Separation of Concerns
- **Local Notifications**: User-scheduled daily reminders
- **Push Notifications**: Server-triggered events and social features
- **Different Channels**: Prevent conflicts

### ✅ No Impact on Existing System
- Local notification code remains untouched
- Top-level callbacks stay in place
- AlarmManager continues to work
- Settings screen unchanged

### ✅ Coordinator Pattern
- Single entry point for all notification systems
- Easy to add more notification types in future
- Centralized initialization

---

## Future Enhancements

### 1. Smart Push Notifications
- **Streak Reminder**: If no entry for 3 days
- **Weekly Summary**: Every Sunday evening
- **Achievement Unlocked**: Milestone notifications
- **Friend Activity**: When friends complete entries

### 2. Notification Preferences
```dart
class NotificationPreferences {
  bool localRemindersEnabled;
  bool pushNotificationsEnabled;
  bool streakRemindersEnabled;
  bool socialNotificationsEnabled;
  bool marketingNotificationsEnabled;
}
```

### 3. Analytics
- Track notification open rates
- A/B test notification messages
- Optimize send times
- User engagement metrics

---

## Migration Checklist

When implementing push notifications:

- [ ] Add Firebase dependencies
- [ ] Configure Firebase project
- [ ] Update AndroidManifest.xml
- [ ] Create `push_notification_service.dart`
- [ ] Create `notification_coordinator.dart`
- [ ] Update `main.dart` initialization
- [ ] Create Supabase tables
- [ ] Deploy Edge Function
- [ ] Test all scenarios
- [ ] Update user documentation

---

## Important Notes

⚠️ **DO NOT MODIFY**:
- `lib/services/notification_service.dart` (except to integrate coordinator)
- Top-level callback functions
- AlarmManager configuration
- Existing notification channel IDs

✅ **SAFE TO ADD**:
- New push notification files
- New notification channels
- Firebase configuration
- Supabase Edge Functions

---

## Conclusion

This architecture allows you to:
1. ✅ Keep existing local notifications working
2. ✅ Add push notifications without conflicts
3. ✅ Scale to handle social features
4. ✅ Maintain clean separation of concerns
5. ✅ Easy to test and debug

**When ready to implement, follow phases 1-6 in order!** 🚀

