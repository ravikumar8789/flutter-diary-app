import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pin_auth_service.dart';
import '../services/error_logging_service.dart';

/// Privacy lock states
enum PrivacyLockState {
  disabled, // Privacy lock is off
  locked, // App is locked, needs PIN
  unlocked, // App is unlocked and accessible
  lockout, // Too many failed attempts, temporary lockout
  setup, // Initial PIN setup in progress
}

/// PIN entry states
enum PinEntryState {
  idle, // No PIN entry in progress
  entering, // PIN being entered
  validating, // PIN validation in progress
  success, // PIN correct
  failure, // PIN incorrect
  lockout, // Account locked due to failed attempts
}

/// Privacy lock state data
class PrivacyLockData {
  final PrivacyLockState state;
  final PinEntryState pinEntryState;
  final bool isEnabled;
  final bool isUnlocked;
  final bool isLockedOut;
  final int failedAttempts;
  final int remainingLockoutTime;
  final int autoLockTimeout;
  final String? errorMessage;

  const PrivacyLockData({
    required this.state,
    required this.pinEntryState,
    required this.isEnabled,
    required this.isUnlocked,
    required this.isLockedOut,
    required this.failedAttempts,
    required this.remainingLockoutTime,
    required this.autoLockTimeout,
    this.errorMessage,
  });

  PrivacyLockData copyWith({
    PrivacyLockState? state,
    PinEntryState? pinEntryState,
    bool? isEnabled,
    bool? isUnlocked,
    bool? isLockedOut,
    int? failedAttempts,
    int? remainingLockoutTime,
    int? autoLockTimeout,
    String? errorMessage,
  }) {
    return PrivacyLockData(
      state: state ?? this.state,
      pinEntryState: pinEntryState ?? this.pinEntryState,
      isEnabled: isEnabled ?? this.isEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isLockedOut: isLockedOut ?? this.isLockedOut,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      remainingLockoutTime: remainingLockoutTime ?? this.remainingLockoutTime,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Privacy lock provider
final privacyLockProvider =
    NotifierProvider<PrivacyLockNotifier, PrivacyLockData>(() {
      return PrivacyLockNotifier();
    });

/// Privacy lock notifier
class PrivacyLockNotifier extends Notifier<PrivacyLockData> {
  final PinAuthService _pinAuthService = PinAuthService();

  @override
  PrivacyLockData build() {
    _initialize();
    return const PrivacyLockData(
      state: PrivacyLockState.disabled,
      pinEntryState: PinEntryState.idle,
      isEnabled: false,
      isUnlocked: true,
      isLockedOut: false,
      failedAttempts: 0,
      remainingLockoutTime: 0,
      autoLockTimeout: 5,
    );
  }

  /// Initialize privacy lock state
  Future<void> _initialize() async {
    try {
      final isEnabled = await _pinAuthService.isPrivacyLockEnabled();
      final isLockedOut = await _pinAuthService.isLockedOut();
      final shouldLock = await _pinAuthService.shouldLockApp();
      final autoLockTimeout = await _pinAuthService.getAutoLockTimeout();
      final remainingLockoutTime = await _pinAuthService
          .getRemainingLockoutTime();

      PrivacyLockState newState;
      bool isUnlocked = true;

      if (!isEnabled) {
        newState = PrivacyLockState.disabled;
      } else if (isLockedOut) {
        newState = PrivacyLockState.lockout;
        isUnlocked = false;
      } else if (shouldLock) {
        newState = PrivacyLockState.locked;
        isUnlocked = false;
      } else {
        newState = PrivacyLockState.unlocked;
        isUnlocked = true;
      }

      state = state.copyWith(
        state: newState,
        isEnabled: isEnabled,
        isUnlocked: isUnlocked,
        isLockedOut: isLockedOut,
        autoLockTimeout: autoLockTimeout,
        remainingLockoutTime: remainingLockoutTime,
        errorMessage: null,
      );
    } catch (e) {

      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS079',
        errorMessage: 'Privacy lock initialization failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'initialization_time': DateTime.now().toIso8601String(),
          'provider': 'PrivacyLockProvider',
        },
      );
      state = state.copyWith(
        state: PrivacyLockState.disabled,
        isEnabled: false,
        isUnlocked: true,
        errorMessage: 'Failed to initialize privacy lock',
      );
    }
  }

  /// Enable privacy lock
  Future<bool> enablePrivacyLock() async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final success = await _pinAuthService.enablePrivacyLock();

      if (success) {
        state = state.copyWith(
          state: PrivacyLockState.setup,
          isEnabled: true,
          isUnlocked: false,
          pinEntryState: PinEntryState.idle,
        );
        return true;
      } else {
        state = state.copyWith(
          pinEntryState: PinEntryState.failure,
          errorMessage: 'Failed to enable privacy lock',
        );
        return false;
      }
    } catch (e) {

      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS080',
        errorMessage: 'Privacy lock enable failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'enable_time': DateTime.now().toIso8601String(),
          'provider': 'PrivacyLockProvider',
        },
      );
      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: 'Error enabling privacy lock: $e',
      );
      return false;
    }
  }

  /// Disable privacy lock
  Future<bool> disablePrivacyLock() async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final success = await _pinAuthService.disablePrivacyLock();

      if (success) {
        state = state.copyWith(
          state: PrivacyLockState.disabled,
          isEnabled: false,
          isUnlocked: true,
          isLockedOut: false,
          failedAttempts: 0,
          remainingLockoutTime: 0,
          pinEntryState: PinEntryState.idle,
        );
        return true;
      } else {
        state = state.copyWith(
          pinEntryState: PinEntryState.failure,
          errorMessage: 'Failed to disable privacy lock',
        );
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: 'Error disabling privacy lock: $e',
      );
      return false;
    }
  }

  /// Set up PIN
  Future<bool> setupPin(String pin, String confirmPin) async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final success = await _pinAuthService.setupPin(pin, confirmPin);

      if (success) {
        state = state.copyWith(
          state: PrivacyLockState.unlocked,
          isUnlocked: true,
          pinEntryState: PinEntryState.success,
        );
        return true;
      } else {
        state = state.copyWith(
          pinEntryState: PinEntryState.failure,
          errorMessage: 'Failed to set up PIN',
        );
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Validate PIN
  Future<bool> validatePin(String pin) async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final isValid = await _pinAuthService.validatePin(pin);

      if (isValid) {
        await _pinAuthService.recordSuccessfulUnlock();
        state = state.copyWith(
          state: PrivacyLockState.unlocked,
          isUnlocked: true,
          isLockedOut: false,
          failedAttempts: 0,
          remainingLockoutTime: 0,
          pinEntryState: PinEntryState.success,
        );
        return true;
      } else {
        await _pinAuthService.recordFailedAttempt();
        final isLockedOut = await _pinAuthService.isLockedOut();
        final remainingTime = await _pinAuthService.getRemainingLockoutTime();

        state = state.copyWith(
          state: isLockedOut
              ? PrivacyLockState.lockout
              : PrivacyLockState.locked,
          isUnlocked: false,
          isLockedOut: isLockedOut,
          remainingLockoutTime: remainingTime,
          pinEntryState: PinEntryState.failure,
          errorMessage: isLockedOut
              ? 'Account locked. Try again in $remainingTime minutes.'
              : 'Incorrect PIN. Try again.',
        );
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: 'Error validating PIN: $e',
      );
      return false;
    }
  }

  /// Change PIN
  Future<bool> changePin(
    String currentPin,
    String newPin,
    String confirmPin,
  ) async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final success = await _pinAuthService.changePin(
        currentPin,
        newPin,
        confirmPin,
      );

      if (success) {
        state = state.copyWith(pinEntryState: PinEntryState.success);
        return true;
      } else {
        state = state.copyWith(
          pinEntryState: PinEntryState.failure,
          errorMessage: 'Failed to change PIN',
        );
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Set security questions
  Future<bool> setSecurityQuestions({
    required String question1,
    required String answer1,
    required String question2,
    required String answer2,
  }) async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final success = await _pinAuthService.setSecurityQuestions(
        question1: question1,
        answer1: answer1,
        question2: question2,
        answer2: answer2,
      );

      if (success) {
        state = state.copyWith(pinEntryState: PinEntryState.success);
        return true;
      } else {
        state = state.copyWith(
          pinEntryState: PinEntryState.failure,
          errorMessage: 'Failed to set security questions',
        );
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: 'Error setting security questions: $e',
      );
      return false;
    }
  }

  /// Verify security answers for PIN recovery
  Future<bool> verifySecurityAnswers(String answer1, String answer2) async {
    try {
      state = state.copyWith(
        pinEntryState: PinEntryState.validating,
        errorMessage: null,
      );

      final isValid = await _pinAuthService.verifySecurityAnswers(
        answer1,
        answer2,
      );

      if (isValid) {
        state = state.copyWith(pinEntryState: PinEntryState.success);
        return true;
      } else {
        state = state.copyWith(
          pinEntryState: PinEntryState.failure,
          errorMessage: 'Incorrect answers. Please try again.',
        );
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        pinEntryState: PinEntryState.failure,
        errorMessage: 'Error verifying security answers: $e',
      );
      return false;
    }
  }

  /// Set auto-lock timeout
  Future<bool> setAutoLockTimeout(int minutes) async {
    try {
      final success = await _pinAuthService.setAutoLockTimeout(minutes);

      if (success) {
        state = state.copyWith(autoLockTimeout: minutes);
        return true;
      } else {
        state = state.copyWith(errorMessage: 'Failed to set auto-lock timeout');
        return false;
      }
    } catch (e) {

      state = state.copyWith(
        errorMessage: 'Error setting auto-lock timeout: $e',
      );
      return false;
    }
  }

  /// Check if app should be locked
  Future<void> checkAutoLock() async {
    try {
      final shouldLock = await _pinAuthService.shouldLockApp();

      if (shouldLock && state.isEnabled && state.isUnlocked) {
        state = state.copyWith(
          state: PrivacyLockState.locked,
          isUnlocked: false,
        );
      }
    } catch (e) {

    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(
      errorMessage: null,
      pinEntryState: PinEntryState.idle,
    );
  }

  /// Reset PIN entry state
  void resetPinEntry() {
    state = state.copyWith(
      pinEntryState: PinEntryState.idle,
      errorMessage: null,
    );
  }

  /// Get security questions
  Future<Map<String, String>> getSecurityQuestions() async {
    try {
      return await _pinAuthService.getSecurityQuestions();
    } catch (e) {

      return {'question1': '', 'question2': ''};
    }
  }

  /// Check if PIN is set up
  Future<bool> isPinSetUp() async {
    try {
      return await _pinAuthService.isPinSetUp();
    } catch (e) {

      return false;
    }
  }
}
