import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';

/// Service for managing the data fetch flag using SharedPreferences
///
/// Stores last successful fetch date (last_open). Used for login vs resume:
/// - null → login (full 60-day fetch)
/// - non-null → resume (gap fetch from last_open to today)
class DataSyncFlagService {
  static const String _lastFetchDateKey = 'last_fetch_date';

  /// Get the last fetch date. Returns null if not set (fresh install, logout).
  static Future<DateTime?> getLastFetchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString(_lastFetchDateKey);
      if (dateStr == null || dateStr.isEmpty) return null;
      return DateTime.tryParse(dateStr);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS160',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'getLastFetchDate',
            'key': _lastFetchDateKey,
          },
        ),
      );
      return null;
    }
  }

  /// Store the last fetch date. Call after every successful fetch (login or resume).
  static Future<void> setLastFetchDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      await prefs.setString(_lastFetchDateKey, dateStr);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS162',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'setLastFetchDate',
            'key': _lastFetchDateKey,
          },
        ),
      );
    }
  }

  /// Clears the last fetch date. Call on logout. Next app open = login (full 60-day fetch).
  static Future<void> clearLastFetchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastFetchDateKey);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS161',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'clearLastFetchDate',
            'key': _lastFetchDateKey,
          },
        ),
      );
    }
  }
}
