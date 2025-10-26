import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_data_service.dart';
import '../services/error_logging_service.dart';

/// Global user data provider
final userDataProvider = NotifierProvider<UserDataNotifier, UserDataState>(
  () => UserDataNotifier(),
);

/// User data state
class UserDataState {
  final UserData? userData;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? additionalData;

  UserDataState({
    this.userData,
    this.isLoading = false,
    this.error,
    this.additionalData,
  });

  UserDataState copyWith({
    UserData? userData,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? additionalData,
  }) {
    return UserDataState(
      userData: userData ?? this.userData,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}

/// User data notifier for managing user data state
class UserDataNotifier extends Notifier<UserDataState> {
  @override
  UserDataState build() => UserDataState();

  /// Load user data (called from splash screen)
  Future<void> loadUserData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await UserDataService.fetchUserData();

      if (result.success && result.userData != null) {
        state = state.copyWith(
          userData: result.userData,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? 'Failed to load user data',
        );
      }
    } catch (e) {
      // Log error to Supabase
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS011',
        errorMessage: 'User data fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': state.userData?.id,
          'fetch_time': DateTime.now().toIso8601String(),
          'fetch_method': 'loadUserData',
        },
      );

      state = state.copyWith(
        isLoading: false,
        error: 'Error loading user data: $e',
      );
    }
  }

  /// Refresh user data
  Future<void> refreshUserData() async {
    await loadUserData();
  }

  /// Update user data locally (for immediate UI updates)
  void updateUserData(UserData userData) {
    state = state.copyWith(userData: userData);
  }

  /// Add additional data (for future features)
  void addAdditionalData(String key, dynamic data) {
    final currentAdditionalData = Map<String, dynamic>.from(
      state.additionalData ?? {},
    );
    currentAdditionalData[key] = data;
    state = state.copyWith(additionalData: currentAdditionalData);
  }

  /// Get additional data
  T? getAdditionalData<T>(String key) {
    return state.additionalData?[key] as T?;
  }

  /// Clear user data (on logout)
  void clearUserData() {
    state = UserDataState();
  }

  /// Future: Add methods for specific data fetching
  /// These can be called from anywhere in the app to fetch additional data

  /// Fetch wellness data
  Future<void> fetchWellnessData() async {
    if (state.userData == null) return;

    try {
      final result = await UserDataService.fetchWellnessData(
        state.userData!.id,
      );
      if (result.success) {
        addAdditionalData('wellness', result.data);
      }
    } catch (e) {
      // Handle error silently or show notification
    }
  }

  /// Fetch gratitude data
  Future<void> fetchGratitudeData() async {
    if (state.userData == null) return;

    try {
      final result = await UserDataService.fetchGratitudeData(
        state.userData!.id,
      );
      if (result.success) {
        addAdditionalData('gratitude', result.data);
      }
    } catch (e) {}
  }

  /// Fetch morning rituals data
  Future<void> fetchMorningRitualsData() async {
    if (state.userData == null) return;

    try {
      final result = await UserDataService.fetchMorningRitualsData(
        state.userData!.id,
      );
      if (result.success) {
        addAdditionalData('morning_rituals', result.data);
      }
    } catch (e) {}
  }

  /// Fetch analytics data
  Future<void> fetchAnalyticsData() async {
    if (state.userData == null) return;

    try {
      final result = await UserDataService.fetchAnalyticsData(
        state.userData!.id,
      );
      if (result.success) {
        addAdditionalData('analytics', result.data);
      }
    } catch (e) {}
  }

  /// Fetch all additional data at once
  Future<void> fetchAllAdditionalData() async {
    if (state.userData == null) return;

    await Future.wait([
      fetchWellnessData(),
      fetchGratitudeData(),
      fetchMorningRitualsData(),
      fetchAnalyticsData(),
    ]);
  }
}

/// Convenience providers for specific data
final userStatsProvider = Provider<Map<String, dynamic>?>((ref) {
  final userData = ref.watch(userDataProvider).userData;
  return userData?.stats;
});

final userPreferencesProvider = Provider<Map<String, dynamic>?>((ref) {
  final userData = ref.watch(userDataProvider).userData;
  return userData?.preferences;
});

final wellnessDataProvider = Provider<Map<String, dynamic>?>((ref) {
  final additionalData = ref.watch(userDataProvider).additionalData;
  return additionalData?['wellness'];
});

final gratitudeDataProvider = Provider<Map<String, dynamic>?>((ref) {
  final additionalData = ref.watch(userDataProvider).additionalData;
  return additionalData?['gratitude'];
});

final morningRitualsDataProvider = Provider<Map<String, dynamic>?>((ref) {
  final additionalData = ref.watch(userDataProvider).additionalData;
  return additionalData?['morning_rituals'];
});

final analyticsDataProvider = Provider<Map<String, dynamic>?>((ref) {
  final additionalData = ref.watch(userDataProvider).additionalData;
  return additionalData?['analytics'];
});
