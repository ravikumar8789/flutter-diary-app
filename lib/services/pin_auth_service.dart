import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'error_logging_service.dart';

class PinAuthService {
  static const String _pinHashKey = 'pin_hash';
  static const String _securityQuestion1Key = 'security_question_1';
  static const String _securityAnswer1Key = 'security_answer_1';
  static const String _securityQuestion2Key = 'security_question_2';
  static const String _securityAnswer2Key = 'security_answer_2';

  static const String _privacyLockEnabledKey = 'privacy_lock_enabled';
  static const String _autoLockTimeoutKey = 'auto_lock_timeout';
  static const String _lastUnlockTimeKey = 'last_unlock_time';
  static const String _failedAttemptsKey = 'failed_attempts';
  static const String _lockoutUntilKey = 'lockout_until';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Create a hash for the PIN with salt
  String _hashPin(String pin) {
    final salt = _generateSalt();
    final bytes = utf8.encode('$pin$salt');
    final digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }

  /// Generate a random salt
  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Validate PIN against stored hash
  Future<bool> validatePin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _pinHashKey);
      if (storedHash == null) return false;

      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final storedDigest = parts[1];

      final bytes = utf8.encode('$pin$salt');
      final digest = sha256.convert(bytes);

      return digest.toString() == storedDigest;
    } catch (e) {
      print('Error validating PIN: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS061',
        errorMessage: 'PIN validation failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'validation_time': DateTime.now().toIso8601String(),
          'service': 'PinAuthService',
        },
      );
      return false;
    }
  }

  /// Set up PIN with confirmation
  Future<bool> setupPin(String pin, String confirmPin) async {
    if (pin != confirmPin) {
      throw Exception('PINs do not match');
    }

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw Exception('PIN must be exactly 4 digits');
    }

    try {
      final pinHash = _hashPin(pin);
      await _secureStorage.write(key: _pinHashKey, value: pinHash);
      return true;
    } catch (e) {
      print('Error setting up PIN: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS062',
        errorMessage: 'PIN setup failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'setup_time': DateTime.now().toIso8601String(),
          'service': 'PinAuthService',
        },
      );
      return false;
    }
  }

  /// Change existing PIN
  Future<bool> changePin(
    String currentPin,
    String newPin,
    String confirmPin,
  ) async {
    // Validate current PIN
    final isValid = await validatePin(currentPin);
    if (!isValid) {
      throw Exception('Current PIN is incorrect');
    }

    // Validate new PIN
    if (newPin != confirmPin) {
      throw Exception('New PINs do not match');
    }

    if (newPin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(newPin)) {
      throw Exception('PIN must be exactly 4 digits');
    }

    try {
      final pinHash = _hashPin(newPin);
      await _secureStorage.write(key: _pinHashKey, value: pinHash);
      return true;
    } catch (e) {
      print('Error changing PIN: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS063',
        errorMessage: 'PIN change failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'change_time': DateTime.now().toIso8601String(),
          'service': 'PinAuthService',
        },
      );
      return false;
    }
  }

  /// Check if PIN is set up
  Future<bool> isPinSetUp() async {
    try {
      final pinHash = await _secureStorage.read(key: _pinHashKey);
      return pinHash != null;
    } catch (e) {
      print('Error checking PIN setup: $e');
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
      await _secureStorage.write(key: _securityQuestion1Key, value: question1);
      await _secureStorage.write(
        key: _securityAnswer1Key,
        value: _hashAnswer(answer1),
      );
      await _secureStorage.write(key: _securityQuestion2Key, value: question2);
      await _secureStorage.write(
        key: _securityAnswer2Key,
        value: _hashAnswer(answer2),
      );
      return true;
    } catch (e) {
      print('Error setting security questions: $e');
      return false;
    }
  }

  /// Hash security answer
  String _hashAnswer(String answer) {
    final bytes = utf8.encode(answer.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify security answers
  Future<bool> verifySecurityAnswers(String answer1, String answer2) async {
    try {
      final storedAnswer1 = await _secureStorage.read(key: _securityAnswer1Key);
      final storedAnswer2 = await _secureStorage.read(key: _securityAnswer2Key);

      if (storedAnswer1 == null || storedAnswer2 == null) return false;

      final hashedAnswer1 = _hashAnswer(answer1);
      final hashedAnswer2 = _hashAnswer(answer2);

      return hashedAnswer1 == storedAnswer1 && hashedAnswer2 == storedAnswer2;
    } catch (e) {
      print('Error verifying security answers: $e');
      return false;
    }
  }

  /// Get security questions
  Future<Map<String, String>> getSecurityQuestions() async {
    try {
      final question1 = await _secureStorage.read(key: _securityQuestion1Key);
      final question2 = await _secureStorage.read(key: _securityQuestion2Key);

      return {'question1': question1 ?? '', 'question2': question2 ?? ''};
    } catch (e) {
      print('Error getting security questions: $e');
      return {'question1': '', 'question2': ''};
    }
  }

  /// Enable privacy lock
  Future<bool> enablePrivacyLock() async {
    try {
      await _initPrefs();
      await _prefs!.setBool(_privacyLockEnabledKey, true);
      await _prefs!.setInt(_autoLockTimeoutKey, 5); // Default 5 minutes
      await _prefs!.setInt(_failedAttemptsKey, 0);
      return true;
    } catch (e) {
      print('Error enabling privacy lock: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS068',
        errorMessage: 'Privacy lock enable failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'enable_time': DateTime.now().toIso8601String(),
          'service': 'PinAuthService',
        },
      );
      return false;
    }
  }

  /// Disable privacy lock
  Future<bool> disablePrivacyLock() async {
    try {
      await _initPrefs();
      await _prefs!.setBool(_privacyLockEnabledKey, false);
      await _prefs!.remove(_lastUnlockTimeKey);
      await _prefs!.remove(_failedAttemptsKey);
      await _prefs!.remove(_lockoutUntilKey);

      // Clear all PIN-related data from secure storage
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.delete(key: _securityQuestion1Key);
      await _secureStorage.delete(key: _securityAnswer1Key);
      await _secureStorage.delete(key: _securityQuestion2Key);
      await _secureStorage.delete(key: _securityAnswer2Key);

      return true;
    } catch (e) {
      print('Error disabling privacy lock: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS069',
        errorMessage: 'Privacy lock disable failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'disable_time': DateTime.now().toIso8601String(),
          'service': 'PinAuthService',
        },
      );
      return false;
    }
  }

  /// Check if privacy lock is enabled
  Future<bool> isPrivacyLockEnabled() async {
    try {
      await _initPrefs();
      return _prefs!.getBool(_privacyLockEnabledKey) ?? false;
    } catch (e) {
      print('Error checking privacy lock status: $e');
      return false;
    }
  }

  /// Set auto-lock timeout
  Future<bool> setAutoLockTimeout(int minutes) async {
    try {
      await _initPrefs();
      await _prefs!.setInt(_autoLockTimeoutKey, minutes);
      return true;
    } catch (e) {
      print('Error setting auto-lock timeout: $e');
      return false;
    }
  }

  /// Get auto-lock timeout
  Future<int> getAutoLockTimeout() async {
    try {
      await _initPrefs();
      return _prefs!.getInt(_autoLockTimeoutKey) ?? 5;
    } catch (e) {
      print('Error getting auto-lock timeout: $e');
      return 5;
    }
  }

  /// Record successful unlock
  Future<void> recordSuccessfulUnlock() async {
    try {
      await _initPrefs();
      await _prefs!.setString(
        _lastUnlockTimeKey,
        DateTime.now().toIso8601String(),
      );
      await _prefs!.setInt(_failedAttemptsKey, 0);
      await _prefs!.remove(_lockoutUntilKey);
    } catch (e) {
      print('Error recording successful unlock: $e');
    }
  }

  /// Record failed attempt
  Future<void> recordFailedAttempt() async {
    try {
      await _initPrefs();
      final failedAttempts = _prefs!.getInt(_failedAttemptsKey) ?? 0;
      final newFailedAttempts = failedAttempts + 1;

      await _prefs!.setInt(_failedAttemptsKey, newFailedAttempts);

      // Implement progressive lockout
      if (newFailedAttempts >= 5) {
        final lockoutDuration = _getLockoutDuration(newFailedAttempts);
        final lockoutUntil = DateTime.now().add(
          Duration(minutes: lockoutDuration),
        );
        await _prefs!.setString(
          _lockoutUntilKey,
          lockoutUntil.toIso8601String(),
        );
      }
    } catch (e) {
      print('Error recording failed attempt: $e');
    }
  }

  /// Get lockout duration based on failed attempts
  int _getLockoutDuration(int failedAttempts) {
    if (failedAttempts <= 5) return 5; // 5 minutes
    if (failedAttempts <= 10) return 15; // 15 minutes
    return 30; // 30 minutes
  }

  /// Check if account is locked out
  Future<bool> isLockedOut() async {
    try {
      await _initPrefs();
      final lockoutUntilStr = _prefs!.getString(_lockoutUntilKey);
      if (lockoutUntilStr == null) return false;

      final lockoutUntil = DateTime.parse(lockoutUntilStr);
      return DateTime.now().isBefore(lockoutUntil);
    } catch (e) {
      print('Error checking lockout status: $e');
      return false;
    }
  }

  /// Get remaining lockout time in minutes
  Future<int> getRemainingLockoutTime() async {
    try {
      await _initPrefs();
      final lockoutUntilStr = _prefs!.getString(_lockoutUntilKey);
      if (lockoutUntilStr == null) return 0;

      final lockoutUntil = DateTime.parse(lockoutUntilStr);
      final now = DateTime.now();

      if (now.isAfter(lockoutUntil)) return 0;

      return lockoutUntil.difference(now).inMinutes;
    } catch (e) {
      print('Error getting remaining lockout time: $e');
      return 0;
    }
  }

  /// Check if app should be locked based on auto-lock timeout
  Future<bool> shouldLockApp() async {
    try {
      if (!await isPrivacyLockEnabled()) return false;

      await _initPrefs();
      final lastUnlockStr = _prefs!.getString(_lastUnlockTimeKey);
      if (lastUnlockStr == null) return true;

      final lastUnlock = DateTime.parse(lastUnlockStr);
      final autoLockTimeout = await getAutoLockTimeout();

      if (autoLockTimeout == 0) return false; // Never auto-lock

      final timeSinceUnlock = DateTime.now().difference(lastUnlock);
      return timeSinceUnlock.inMinutes >= autoLockTimeout;
    } catch (e) {
      print('Error checking if app should be locked: $e');
      return true; // Default to locked for security
    }
  }

  /// Clear all privacy lock data
  Future<void> clearAllData() async {
    try {
      // Clear secure storage
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.delete(key: _securityQuestion1Key);
      await _secureStorage.delete(key: _securityAnswer1Key);
      await _secureStorage.delete(key: _securityQuestion2Key);
      await _secureStorage.delete(key: _securityAnswer2Key);

      // Clear preferences
      await _initPrefs();
      await _prefs!.remove(_privacyLockEnabledKey);
      await _prefs!.remove(_autoLockTimeoutKey);
      await _prefs!.remove(_lastUnlockTimeKey);
      await _prefs!.remove(_failedAttemptsKey);
      await _prefs!.remove(_lockoutUntilKey);
    } catch (e) {
      print('Error clearing privacy lock data: $e');
    }
  }
}
