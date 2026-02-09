import 'package:shared_preferences/shared_preferences.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';

/// Service for managing the data fetch flag using SharedPreferences
/// 
/// This flag indicates whether 7 days of data needs to be fetched:
/// - `true`: Data fetch needed (after logout or fresh install)
/// - `false`: Data is synced, no fetch needed
class DataSyncFlagService {
  static const String _needsDataFetchKey = 'needs_data_fetch';
  
  /// Check if data fetch is needed
  /// 
  /// Returns `true` if data needs to be fetched (defaults to `true` for fresh installs)
  static Future<bool> needsDataFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flag = prefs.getBool(_needsDataFetchKey);
      
      // Default to true if flag doesn't exist (fresh install)
      return flag ?? true;
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS160',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'needsDataFetch',
            'key': _needsDataFetchKey,
          },
        ),
      );
      // Default to true on error (safe side - ensures data is fetched)
      return true;
    }
  }
  
  /// Set flag to indicate data fetch is needed
  /// 
  /// Set to `true` when user logs out to ensure data is fetched on next login
  static Future<void> setNeedsDataFetch(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_needsDataFetchKey, value);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS161',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'setNeedsDataFetch',
            'key': _needsDataFetchKey,
            'value': value.toString(),
          },
        ),
      );
      // Don't rethrow - flag write failure shouldn't break logout flow
    }
  }
  
  /// Clear the flag (set to false)
  /// 
  /// Called after successfully fetching 7 days of data
  static Future<void> clearNeedsDataFetch() async {
    try {
      await setNeedsDataFetch(false);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS162',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'clearNeedsDataFetch',
          },
        ),
      );
      // Don't rethrow - flag clear failure shouldn't break login flow
    }
  }
}
