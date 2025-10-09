/// Core user model matching the users table
class User {
  final String id;
  final String? email;
  final bool emailVerified;
  final String? displayName;
  final String? avatarUrl;
  final String? locale;
  final String? timezone;
  final bool marketingOptIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.avatarUrl,
    this.locale,
    this.timezone,
    this.marketingOptIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      locale: json['locale'] as String?,
      timezone: json['timezone'] as String?,
      marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'email_verified': emailVerified,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'locale': locale,
      'timezone': timezone,
      'marketing_opt_in': marketingOptIn,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// User profile model matching the user_profiles table
class UserProfile {
  final String userId;
  final String? bio;
  final bool onboardingComplete;
  final ThemePreference themePreference;
  final String? diaryFont;
  final int? fontSize;
  final PaperStyle paperStyle;
  final Gender gender;

  UserProfile({
    required this.userId,
    this.bio,
    this.onboardingComplete = false,
    this.themePreference = ThemePreference.system,
    this.diaryFont,
    this.fontSize,
    this.paperStyle = PaperStyle.ruled,
    this.gender = Gender.unspecified,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      bio: json['bio'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      themePreference: ThemePreference.fromString(
        json['theme_preference'] as String?,
      ),
      diaryFont: json['diary_font'] as String?,
      fontSize: json['font_size'] as int?,
      paperStyle: PaperStyle.fromString(json['paper_style'] as String?),
      gender: Gender.fromString(json['gender'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bio': bio,
      'onboarding_complete': onboardingComplete,
      'theme_preference': themePreference.value,
      'diary_font': diaryFont,
      'font_size': fontSize,
      'paper_style': paperStyle.value,
      'gender': gender.value,
    };
  }
}

/// Auth provider model matching the auth_providers table
class AuthProvider {
  final String id;
  final String userId;
  final String provider;
  final String? providerUid;
  final DateTime linkedAt;

  AuthProvider({
    required this.id,
    required this.userId,
    required this.provider,
    this.providerUid,
    required this.linkedAt,
  });

  factory AuthProvider.fromJson(Map<String, dynamic> json) {
    return AuthProvider(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      provider: json['provider'] as String,
      providerUid: json['provider_uid'] as String?,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'provider': provider,
      'provider_uid': providerUid,
      'linked_at': linkedAt.toIso8601String(),
    };
  }
}

/// Theme preference enum
enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.value);
  final String value;

  static ThemePreference fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
      default:
        return ThemePreference.system;
    }
  }
}

/// Paper style enum
enum PaperStyle {
  plain('plain'),
  ruled('ruled'),
  grid('grid');

  const PaperStyle(this.value);
  final String value;

  static PaperStyle fromString(String? value) {
    switch (value) {
      case 'plain':
        return PaperStyle.plain;
      case 'grid':
        return PaperStyle.grid;
      default:
        return PaperStyle.ruled;
    }
  }
}

/// Gender enum
enum Gender {
  unspecified('unspecified'),
  male('male'),
  female('female'),
  other('other');

  const Gender(this.value);
  final String value;

  static Gender fromString(String? value) {
    switch (value) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.unspecified;
    }
  }
}
