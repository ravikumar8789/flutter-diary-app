/// User settings model matching the user_settings table
class UserSettings {
  final String userId;
  final bool reminderEnabled;
  final String? reminderTimeLocal;
  final List<int> reminderDays;
  final bool streakCompassionEnabled;
  final bool privacyLockEnabled;
  final String? regionPreference;
  final ExportFormat exportFormatDefault;

  UserSettings({
    required this.userId,
    this.reminderEnabled = true,
    this.reminderTimeLocal,
    this.reminderDays = const [1, 2, 3, 4, 5, 6, 7], // Mon-Sun
    this.streakCompassionEnabled = true,
    this.privacyLockEnabled = false,
    this.regionPreference,
    this.exportFormatDefault = ExportFormat.json,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['user_id'] as String,
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      reminderTimeLocal: json['reminder_time_local'] as String?,
      reminderDays: List<int>.from(
        json['reminder_days'] as List? ?? [1, 2, 3, 4, 5, 6, 7],
      ),
      streakCompassionEnabled:
          json['streak_compassion_enabled'] as bool? ?? true,
      privacyLockEnabled: json['privacy_lock_enabled'] as bool? ?? false,
      regionPreference: json['region_preference'] as String?,
      exportFormatDefault: ExportFormat.fromString(
        json['export_format_default'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'reminder_enabled': reminderEnabled,
      'reminder_time_local': reminderTimeLocal,
      'reminder_days': reminderDays,
      'streak_compassion_enabled': streakCompassionEnabled,
      'privacy_lock_enabled': privacyLockEnabled,
      'region_preference': regionPreference,
      'export_format_default': exportFormatDefault.value,
    };
  }
}

/// Notification token model matching the notification_tokens table
class NotificationToken {
  final String id;
  final String userId;
  final NotificationPlatform platform;
  final String fcmToken;
  final DateTime? lastSeenAt;

  NotificationToken({
    required this.id,
    required this.userId,
    required this.platform,
    required this.fcmToken,
    this.lastSeenAt,
  });

  factory NotificationToken.fromJson(Map<String, dynamic> json) {
    return NotificationToken(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      platform: NotificationPlatform.fromString(json['platform'] as String),
      fcmToken: json['fcm_token'] as String,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'platform': platform.value,
      'fcm_token': fcmToken,
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }
}

/// Notification model matching the notifications table
class Notification {
  final String id;
  final String userId;
  final NotificationKind kind;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final NotificationStatus status;
  final Map<String, dynamic> meta;

  Notification({
    required this.id,
    required this.userId,
    required this.kind,
    this.scheduledFor,
    this.sentAt,
    this.status = NotificationStatus.scheduled,
    this.meta = const {},
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kind: NotificationKind.fromString(json['kind'] as String),
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.parse(json['scheduled_for'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      status: NotificationStatus.fromString(json['status'] as String?),
      meta: Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kind': kind.value,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'status': status.value,
      'meta': meta,
    };
  }
}

/// Export format enum
enum ExportFormat {
  pdf('pdf'),
  csv('csv'),
  json('json');

  const ExportFormat(this.value);
  final String value;

  static ExportFormat fromString(String? value) {
    switch (value) {
      case 'pdf':
        return ExportFormat.pdf;
      case 'csv':
        return ExportFormat.csv;
      default:
        return ExportFormat.json;
    }
  }
}

/// Notification platform enum
enum NotificationPlatform {
  ios('ios'),
  android('android'),
  web('web');

  const NotificationPlatform(this.value);
  final String value;

  static NotificationPlatform fromString(String value) {
    switch (value) {
      case 'ios':
        return NotificationPlatform.ios;
      case 'android':
        return NotificationPlatform.android;
      case 'web':
        return NotificationPlatform.web;
      default:
        return NotificationPlatform.android;
    }
  }
}

/// Notification kind enum
enum NotificationKind {
  reminder('reminder'),
  weeklyRecap('weekly_recap'),
  system('system');

  const NotificationKind(this.value);
  final String value;

  static NotificationKind fromString(String value) {
    switch (value) {
      case 'reminder':
        return NotificationKind.reminder;
      case 'weekly_recap':
        return NotificationKind.weeklyRecap;
      case 'system':
        return NotificationKind.system;
      default:
        return NotificationKind.reminder;
    }
  }
}

/// Notification status enum
enum NotificationStatus {
  scheduled('scheduled'),
  sent('sent'),
  canceled('canceled'),
  failed('failed');

  const NotificationStatus(this.value);
  final String value;

  static NotificationStatus fromString(String? value) {
    switch (value) {
      case 'sent':
        return NotificationStatus.sent;
      case 'canceled':
        return NotificationStatus.canceled;
      case 'failed':
        return NotificationStatus.failed;
      default:
        return NotificationStatus.scheduled;
    }
  }
}
