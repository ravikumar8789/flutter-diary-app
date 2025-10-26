import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streak_compassion_service.dart';
import '../services/error_logging_service.dart';

class StreakCompassionState {
  final bool isLoading;
  final bool compassionEnabled;
  final int gracePeriodDays;
  final int maxFreezeCredits;
  final int freezeCreditsRemaining;
  final int compassionUsedCount;
  final bool gracePeriodActive;
  final int freezeCreditsEarned;
  final bool isInitialized;
  final String? error;

  StreakCompassionState({
    this.isLoading = false,
    this.compassionEnabled = false,
    this.gracePeriodDays = 1,
    this.maxFreezeCredits = 3,
    this.freezeCreditsRemaining = 0,
    this.compassionUsedCount = 0,
    this.gracePeriodActive = false,
    this.freezeCreditsEarned = 0,
    this.isInitialized = false,
    this.error,
  });

  StreakCompassionState copyWith({
    bool? isLoading,
    bool? compassionEnabled,
    int? gracePeriodDays,
    int? maxFreezeCredits,
    int? freezeCreditsRemaining,
    int? compassionUsedCount,
    bool? gracePeriodActive,
    int? freezeCreditsEarned,
    bool? isInitialized,
    String? error,
  }) {
    return StreakCompassionState(
      isLoading: isLoading ?? this.isLoading,
      compassionEnabled: compassionEnabled ?? this.compassionEnabled,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      maxFreezeCredits: maxFreezeCredits ?? this.maxFreezeCredits,
      freezeCreditsRemaining:
          freezeCreditsRemaining ?? this.freezeCreditsRemaining,
      compassionUsedCount: compassionUsedCount ?? this.compassionUsedCount,
      gracePeriodActive: gracePeriodActive ?? this.gracePeriodActive,
      freezeCreditsEarned: freezeCreditsEarned ?? this.freezeCreditsEarned,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}

class StreakCompassionNotifier extends Notifier<StreakCompassionState> {
  @override
  StreakCompassionState build() => StreakCompassionState();

  String? _currentUserId;

  /// Initialize the provider with user data
  Future<void> initialize(String userId) async {
    print('🔥 StreakCompassion: initialize called with userId=$userId');
    _currentUserId = userId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load compassion settings
      final settings = await StreakCompassionService.getUserCompassionSettings(
        userId,
      );
      if (settings != null) {
        state = state.copyWith(
          compassionEnabled: settings['streak_compassion_enabled'] ?? false,
          gracePeriodDays: settings['grace_period_days'] ?? 1,
          maxFreezeCredits: settings['max_freeze_credits'] ?? 3,
          freezeCreditsEarned: settings['freeze_credits_earned'] ?? 0,
        );
      }

      // Load compassion stats
      final stats = await StreakCompassionService.getCompassionStats(userId);
      if (stats != null) {
        state = state.copyWith(
          freezeCreditsRemaining: stats['freeze_credits_remaining'] ?? 0,
          compassionUsedCount: stats['compassion_used_count'] ?? 0,
          gracePeriodActive: stats['grace_period_active'] ?? false,
        );
      }

      state = state.copyWith(isLoading: false, isInitialized: true);
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA110',
        errorMessage: 'Failed to initialize streak compassion: $e',
        errorContext: {
          'userId': userId,
          'service': 'StreakCompassionNotifier.initialize',
        },
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load compassion settings',
      );
    }
  }

  /// Toggle compassion enabled/disabled
  Future<void> toggleCompassion(bool enabled) async {
    print('🔥 StreakCompassion: toggleCompassion called with enabled=$enabled');
    print('🔥 StreakCompassion: _currentUserId=$_currentUserId');

    if (_currentUserId == null) {
      print('🔥 StreakCompassion: No user ID, returning early');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🔥 StreakCompassion: Calling updateCompassionSettings...');
      final success = await StreakCompassionService.updateCompassionSettings(
        userId: _currentUserId!,
        compassionEnabled: enabled,
      );

      print('🔥 StreakCompassion: updateCompassionSettings result: $success');

      if (success) {
        state = state.copyWith(compassionEnabled: enabled, isLoading: false);
        print('🔥 StreakCompassion: State updated successfully');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update compassion settings',
        );
        print('🔥 StreakCompassion: Failed to update settings');
      }
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA111',
        errorMessage: 'Failed to toggle compassion: $e',
        errorContext: {
          'userId': _currentUserId,
          'enabled': enabled,
          'service': 'StreakCompassionNotifier.toggleCompassion',
        },
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update compassion settings',
      );
    }
  }

  /// Update grace period days
  Future<void> updateGracePeriodDays(int days) async {
    if (_currentUserId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await StreakCompassionService.updateCompassionSettings(
        userId: _currentUserId!,
        compassionEnabled: state.compassionEnabled,
        gracePeriodDays: days,
      );

      if (success) {
        state = state.copyWith(gracePeriodDays: days, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update grace period',
        );
      }
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA112',
        errorMessage: 'Failed to update grace period: $e',
        errorContext: {
          'userId': _currentUserId,
          'days': days,
          'service': 'StreakCompassionNotifier.updateGracePeriodDays',
        },
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update grace period',
      );
    }
  }

  /// Use a freeze credit
  Future<bool> useFreezeCredit(String reason, int streakMaintained) async {
    if (_currentUserId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await StreakCompassionService.useFreezeCredit(
        userId: _currentUserId!,
        reason: reason,
        streakMaintained: streakMaintained,
      );

      if (success) {
        // Refresh stats after using credit
        await _refreshStats();
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to use freeze credit',
        );
        return false;
      }
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA113',
        errorMessage: 'Failed to use freeze credit: $e',
        errorContext: {
          'userId': _currentUserId,
          'reason': reason,
          'streakMaintained': streakMaintained,
          'service': 'StreakCompassionNotifier.useFreezeCredit',
        },
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to use freeze credit',
      );
      return false;
    }
  }

  /// Earn freeze credits
  Future<void> earnFreezeCredits(int credits) async {
    if (_currentUserId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await StreakCompassionService.earnFreezeCredits(
        userId: _currentUserId!,
        creditsEarned: credits,
      );

      if (success) {
        state = state.copyWith(freezeCreditsEarned: credits, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to earn freeze credits',
        );
      }
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA114',
        errorMessage: 'Failed to earn freeze credits: $e',
        errorContext: {
          'userId': _currentUserId,
          'credits': credits,
          'service': 'StreakCompassionNotifier.earnFreezeCredits',
        },
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to earn freeze credits',
      );
    }
  }

  /// Reset grace period (when user writes entry)
  Future<void> resetGracePeriod() async {
    if (_currentUserId == null) return;

    try {
      await StreakCompassionService.resetGracePeriod(_currentUserId!);
      state = state.copyWith(gracePeriodActive: false);
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA115',
        errorMessage: 'Failed to reset grace period: $e',
        errorContext: {
          'userId': _currentUserId,
          'service': 'StreakCompassionNotifier.resetGracePeriod',
        },
      );
    }
  }

  /// Refresh compassion stats
  Future<void> _refreshStats() async {
    if (_currentUserId == null) return;

    try {
      final stats = await StreakCompassionService.getCompassionStats(
        _currentUserId!,
      );
      if (stats != null) {
        state = state.copyWith(
          freezeCreditsRemaining: stats['freeze_credits_remaining'] ?? 0,
          compassionUsedCount: stats['compassion_used_count'] ?? 0,
          gracePeriodActive: stats['grace_period_active'] ?? false,
        );
      }
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA116',
        errorMessage: 'Failed to refresh compassion stats: $e',
        errorContext: {
          'userId': _currentUserId,
          'service': 'StreakCompassionNotifier._refreshStats',
        },
      );
    }
  }

  /// Check if user can use freeze credit
  Future<bool> canUseFreezeCredit() async {
    if (_currentUserId == null) return false;

    try {
      return await StreakCompassionService.canUseFreezeCredit(_currentUserId!);
    } catch (e) {
      ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA117',
        errorMessage: 'Failed to check freeze credit availability: $e',
        errorContext: {
          'userId': _currentUserId,
          'service': 'StreakCompassionNotifier.canUseFreezeCredit',
        },
      );
      return false;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider instances
final streakCompassionProvider =
    NotifierProvider<StreakCompassionNotifier, StreakCompassionState>(() {
      return StreakCompassionNotifier();
    });
