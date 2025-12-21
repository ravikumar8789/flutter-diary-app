import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';

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

/// Monthly analytics provider
final monthlyAnalyticsProvider =
    FutureProvider.autoDispose<MonthlyAnalyticsData>((ref) async {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final service = AnalyticsService();
      return await service.getMonthlyAnalytics(monthStart);
    });
