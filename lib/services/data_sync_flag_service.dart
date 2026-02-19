import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';

/// Service for managing the data fetch flag using SharedPreferences
///
/// Uses date-based logic: stores last successful 7-day fetch date.
/// - `null` or ≥2 days ago: fetch 7 days
/// - 0 or 1 day ago: fetch today only
class DataSyncFlagService {
  static const String _needsDataFetchKey = 'needs_data_fetch';

  /// Check if full 7-day fetch is needed
  ///
  /// Returns `true` if:
  /// - Key is null (fresh install, logout, legacy bool)
  /// - Stored date is invalid
  /// - Stored date is 2+ days ago
  /// Returns `false` if stored date is 0 or 1 day ago (fetch today only)
  static Future<bool> needsDataFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString(_needsDataFetchKey);

      // null = fresh install, logout, or legacy bool (getString returns null for old bool)
      if (dateStr == null || dateStr.isEmpty) return true;

      // Parse stored date
      final storedDate = DateTime.tryParse(dateStr);
      if (storedDate == null) return true; // Invalid format → safe fetch 7d

      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final storedDateOnly = DateTime(
        storedDate.year,
        storedDate.month,
        storedDate.day,
      );
      final daysSince = today.difference(storedDateOnly).inDays;

      // Future date (clock skew) → treat as today
      if (daysSince < 0) return false;

      // 2+ days ago → fetch full week
      if (daysSince >= 2) return true;

      // 0 or 1 day → fetch today only
      return false;
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
      // Error → safe fetch 7d
      return true;
    }
  }

  /// Record successful 7-day fetch. Stores today's date.
  ///
  /// Called after prefetch7DaysData completes successfully.
  static Future<void> clearNeedsDataFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString(_needsDataFetchKey, todayStr);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS162',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'clearNeedsDataFetch',
            'key': _needsDataFetchKey,
          },
        ),
      );
    }
  }

  /// Clears the last fetch date. Next needsDataFetch() will return true (fetch 7 days).
  ///
  /// Call on logout and login to ensure full 7-day fetch on next app load.
  static Future<void> clearLastFetchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_needsDataFetchKey);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS161',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'clearLastFetchDate',
            'key': _needsDataFetchKey,
          },
        ),
      );
    }
  }
}
