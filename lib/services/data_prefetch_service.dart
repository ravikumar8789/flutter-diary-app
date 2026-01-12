import 'data_fetch_service.dart';
import 'error_logging_service.dart';

/// Service for prefetching 7 days of data
/// 
/// Used after logout/login to ensure local database has recent data
/// for calculations and UI display
class DataPrefetchService {
  /// Prefetch 7 days of data for user
  /// 
  /// Fetches:
  /// - Last 7 days of entries
  /// - Last 7 days of habits_daily
  /// - Current streak data
  /// 
  /// Fetches in parallel for better performance.
  /// Does not throw exceptions - errors are logged but app continues.
  static Future<void> prefetch7DaysData(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      final today = DateTime.now();
      final weekStart = today.subtract(const Duration(days: 6)); // Last 7 days
      
      // Fetch in parallel for better performance
      await Future.wait([
        _fetchEntries(userId, weekStart, today, dataFetchService),
        _fetchHabits(userId, weekStart, today, dataFetchService),
        _fetchStreaks(userId, dataFetchService),
      ]);
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS164',
        errorMessage: 'Failed to prefetch 7 days data: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'prefetch7DaysData',
        },
      );
      // Don't rethrow - allow app to continue even if prefetch fails
      // Data will be fetched on-demand when screens need it
    }
  }
  
  /// Fetch entries for date range
  static Future<void> _fetchEntries(
    String userId,
    DateTime startDate,
    DateTime endDate,
    DataFetchService dataFetchService,
  ) async {
    try {
      await dataFetchService.fetchEntries(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS165',
        errorMessage: 'Failed to prefetch entries: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        },
      );
      // Don't rethrow - continue with other fetches
    }
  }
  
  /// Fetch habits for date range
  static Future<void> _fetchHabits(
    String userId,
    DateTime startDate,
    DateTime endDate,
    DataFetchService dataFetchService,
  ) async {
    try {
      await dataFetchService.fetchHabitsDaily(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS166',
        errorMessage: 'Failed to prefetch habits: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        },
      );
      // Don't rethrow - continue with other fetches
    }
  }
  
  /// Fetch streak data
  static Future<void> _fetchStreaks(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      await dataFetchService.fetchStreaks(userId);
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS167',
        errorMessage: 'Failed to prefetch streaks: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
        },
      );
      // Don't rethrow - continue with other fetches
    }
  }
}
