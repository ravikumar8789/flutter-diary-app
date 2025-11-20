import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';

/// Period selector provider
final analyticsPeriodProvider = NotifierProvider<AnalyticsPeriodNotifier, AnalyticsPeriod>(
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

/// Weekly analytics provider
final weeklyAnalyticsProvider = FutureProvider.autoDispose<WeeklyAnalyticsData>((ref) async {
  final now = DateTime.now();
  // Calculate current week start (Monday)
  final weekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
  final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
  
  final service = AnalyticsService();
  return await service.getWeeklyAnalytics(weekStartDate);
});

/// Monthly analytics provider
final monthlyAnalyticsProvider = FutureProvider.autoDispose<MonthlyAnalyticsData>((ref) async {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  
  final service = AnalyticsService();
  return await service.getMonthlyAnalytics(monthStart);
});

