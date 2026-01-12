import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../services/error_logging_service.dart';
import 'data_providers.dart';

/// Period selector provider
final analyticsPeriodProvider =
    NotifierProvider<AnalyticsPeriodNotifier, AnalyticsPeriod>(
      () => AnalyticsPeriodNotifier(),
    );

/// Analytics period notifier
class AnalyticsPeriodNotifier extends Notifier<AnalyticsPeriod> {
  @override
  AnalyticsPeriod build() => AnalyticsPeriod.weekly;

  void setPeriod(AnalyticsPeriod period) {
    state = period;
  }
}

/// Selected week notifier
class SelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    // Calculate current week start (Sunday)
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    return DateTime(weekStart.year, weekStart.month, weekStart.day);
  }

  void setWeek(DateTime weekStart) {
    state = weekStart;
  }
}

/// Selected week provider (defaults to current week or last analyzed week)
final selectedWeekProvider = NotifierProvider<SelectedWeekNotifier, DateTime>(
  () => SelectedWeekNotifier(),
);

/// Selected month notifier (defaults to last month)
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    // Default to last month (not current month)
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return lastMonth;
  }

  void setMonth(DateTime monthStart) {
    try {
      state = monthStart;
    } catch (e) {
      ErrorLoggingService.logError(
        errorCode: 'ERRPROV001',
        errorMessage: 'Failed to set selected month: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'month_start': monthStart.toIso8601String(),
          'operation': 'set_month',
        },
      );
      rethrow;
    }
  }
}

/// Selected month provider
final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  () => SelectedMonthNotifier(),
);

/// Week list provider (lightweight metadata for navigation)
final weeklyInsightsListProvider =
    FutureProvider.autoDispose<List<WeekMetadata>>((ref) async {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final service = AnalyticsService();
      return await service.getWeeklyInsightsList(userId);
    });

/// Weekly analytics provider (uses selected week)
final weeklyAnalyticsProvider = FutureProvider.autoDispose<WeeklyAnalyticsData>(
  (ref) async {
    final selectedWeek = ref.watch(selectedWeekProvider);
    final service = AnalyticsService();
    return await service.getWeeklyAnalytics(selectedWeek);
  },
);

/// Monthly insights list provider (uses centralized fetching)
final monthlyInsightsListProvider =
    FutureProvider.autoDispose<List<MonthMetadata>>((ref) async {
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          await ErrorLoggingService.logError(
            errorCode: 'ERRPROV002',
            errorMessage: 'User not authenticated for monthly insights list',
            stackTrace: StackTrace.current.toString(),
            severity: 'MEDIUM',
            errorContext: {'operation': 'monthly_insights_list_provider'},
          );
          return [];
        }

        // Use centralized DataFetchService if available, else direct service
        try {
          final dataFetchService = ref.watch(dataFetchServiceProvider);
          return await dataFetchService.fetchMonthlyInsightsList(userId: userId);
        } catch (e) {
          // Fallback to direct service if DataFetchService fails
          await ErrorLoggingService.logError(
            errorCode: 'ERRPROV003',
            errorMessage: 'DataFetchService unavailable, using direct service: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            severity: 'MEDIUM',
            errorContext: {'operation': 'monthly_insights_list_provider_fallback'},
          );
          final service = AnalyticsService();
          return await service.getMonthlyInsightsList(userId);
        }
      } catch (e) {
        await ErrorLoggingService.logError(
          errorCode: 'ERRPROV003',
          errorMessage: 'Monthly insights list provider failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          severity: 'HIGH',
          errorContext: {'operation': 'monthly_insights_list_provider'},
        );
        rethrow;
      }
    });

/// Monthly analytics provider (uses selected month, centralized fetching)
final monthlyAnalyticsProvider =
    FutureProvider.autoDispose<MonthlyAnalyticsData>((ref) async {
      try {
        final selectedMonth = ref.watch(selectedMonthProvider);
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        
        if (userId == null) {
          await ErrorLoggingService.logError(
            errorCode: 'ERRPROV004',
            errorMessage: 'User not authenticated for monthly analytics',
            stackTrace: StackTrace.current.toString(),
            severity: 'MEDIUM',
            errorContext: {
              'operation': 'monthly_analytics_provider',
              'month_start': selectedMonth.toIso8601String(),
            },
          );
          throw Exception('User not authenticated');
        }

        // Use centralized DataFetchService if available, else direct service
        try {
          final dataFetchService = ref.watch(dataFetchServiceProvider);
          return await dataFetchService.fetchMonthlyAnalytics(
            userId: userId,
            monthStart: selectedMonth,
          );
        } catch (e) {
          // Fallback to direct service if DataFetchService fails
          await ErrorLoggingService.logError(
            errorCode: 'ERRPROV005',
            errorMessage: 'DataFetchService unavailable, using direct service: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            severity: 'MEDIUM',
            errorContext: {
              'operation': 'monthly_analytics_provider_fallback',
              'month_start': selectedMonth.toIso8601String(),
            },
          );
          final service = AnalyticsService();
          return await service.getMonthlyAnalytics(selectedMonth);
        }
      } catch (e) {
        await ErrorLoggingService.logError(
          errorCode: 'ERRPROV005',
          errorMessage: 'Monthly analytics provider failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          severity: 'HIGH',
          errorContext: {
            'operation': 'monthly_analytics_provider',
            'month_start': ref.read(selectedMonthProvider).toIso8601String(),
          },
        );
        rethrow;
      }
    });
