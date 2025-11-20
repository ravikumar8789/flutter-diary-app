import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';
import '../services/error_logging_service.dart';
import 'ai_service.dart';

class AnalyticsService {
  final SupabaseClient _supabase;
  final AIService _aiService;

  AnalyticsService({SupabaseClient? client, AIService? aiService})
      : _supabase = client ?? Supabase.instance.client,
        _aiService = aiService ?? AIService();

  /// Get weekly analytics data from Supabase
  Future<WeeklyAnalyticsData> getWeeklyAnalytics(DateTime weekStart) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

    final weekEnd = weekStart.add(const Duration(days: 6));
      final weekStartStr = '${weekStart.year.toString().padLeft(4, '0')}-'
          '${weekStart.month.toString().padLeft(2, '0')}-'
          '${weekStart.day.toString().padLeft(2, '0')}';
      final weekEndStr = '${weekEnd.year.toString().padLeft(4, '0')}-'
          '${weekEnd.month.toString().padLeft(2, '0')}-'
          '${weekEnd.day.toString().padLeft(2, '0')}';

      // Fetch entries for the week
      final entriesResponse = await _supabase
          .from('entries')
          .select('id, entry_date, mood_score')
          .eq('user_id', userId)
          .gte('entry_date', weekStartStr)
          .lte('entry_date', weekEndStr);

      // Fetch water cups from entry_meals
      final entryIds = (entriesResponse as List).map((e) => e['id'] as String).toList();
      List mealsResponse = [];
      if (entryIds.isNotEmpty) {
        mealsResponse = await _supabase
            .from('entry_meals')
            .select('entry_id, water_cups')
            .inFilter('entry_id', entryIds);
      }

      // Fetch self-care data from habits_daily
      List habitsResponse = [];
      habitsResponse = await _supabase
          .from('habits_daily')
          .select('date, self_care_completed_count')
          .eq('user_id', userId)
          .gte('date', weekStartStr)
          .lte('date', weekEndStr);

      final entries = entriesResponse as List;
      final meals = mealsResponse;
      final habits = habitsResponse;
      final mealsMap = <String, int>{};
      for (final meal in meals) {
        mealsMap[meal['entry_id'] as String] = (meal['water_cups'] as num?)?.toInt() ?? 0;
      }

      final entriesCount = entries.length;

      // Calculate averages
      double? moodAvg;
      double cupsAvg = 0;
      double selfCareRate = 0;
      if (entries.isNotEmpty) {
        final moodScores = entries
            .where((e) => e['mood_score'] != null)
            .map((e) => (e['mood_score'] as num).toDouble())
            .toList();
        moodAvg = moodScores.isNotEmpty
            ? moodScores.reduce((a, b) => a + b) / moodScores.length
            : null;

        final cups = entries
            .map((e) => mealsMap[e['id'] as String] ?? 0)
            .where((c) => c > 0)
            .toList();
        cupsAvg = cups.isNotEmpty ? cups.reduce((a, b) => a + b) / cups.length : 0;

        final selfCareCounts = habits
            .where((h) => h['self_care_completed_count'] != null)
            .map((h) => (h['self_care_completed_count'] as num).toDouble())
            .toList();
        final totalSelfCare = selfCareCounts.isNotEmpty
            ? selfCareCounts.reduce((a, b) => a + b)
            : 0;
        selfCareRate = entriesCount > 0 ? totalSelfCare / (entriesCount * 5) : 0; // Assuming 5 self-care items max
      }

      // Fetch AI-generated weekly insight
      final weeklyInsight = await _aiService.getWeeklyInsight(userId, weekStart);

      // Use AI-generated values if available, otherwise use calculated fallback
      final hasAiInsight = weeklyInsight != null && weeklyInsight.highlights.isNotEmpty;
      
      // Use AI values or calculated fallback
      final finalMoodAvg = weeklyInsight?.moodAvg ?? moodAvg;
      final finalCupsAvg = weeklyInsight?.cupsAvg ?? cupsAvg;
      final finalSelfCareRate = weeklyInsight?.selfCareRate ?? selfCareRate.clamp(0.0, 1.0);
      final finalConsistencyScore = weeklyInsight?.consistencyScore ?? (entriesCount / 7.0);
      final finalEntriesCount = weeklyInsight?.entriesCount ?? entriesCount;
      final finalTopTopics = weeklyInsight?.topTopics ?? [];

      // Build mood trend data
      final moodData = <MoodDataPoint>[];
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dayEntries = entries.where((e) {
          final entryDate = DateTime.parse(e['entry_date'] as String);
          return entryDate.year == date.year &&
              entryDate.month == date.month &&
              entryDate.day == date.day;
        }).toList();

        double? moodScore;
        if (dayEntries.isNotEmpty && dayEntries.first['mood_score'] != null) {
          moodScore = (dayEntries.first['mood_score'] as num).toDouble();
        }

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        moodData.add(MoodDataPoint(
          date: date,
          moodScore: moodScore ?? 0,
          label: dayNames[i],
        ));
      }

    return WeeklyAnalyticsData(
      id: 'weekly-${weekStart.toIso8601String()}',
      weekStart: weekStart,
      weekEnd: weekEnd,
        entriesCount: finalEntriesCount,
        moodAvg: finalMoodAvg,
        cupsAvg: finalCupsAvg,
        selfCareRate: finalSelfCareRate,
        moodTrend: weeklyInsight?.moodTrend,
        highlights: hasAiInsight
            ? weeklyInsight.highlights
            : '',
        keyInsights: hasAiInsight && weeklyInsight.keyInsights.isNotEmpty
            ? weeklyInsight.keyInsights
            : [],
        recommendations: hasAiInsight && weeklyInsight.recommendations.isNotEmpty
            ? weeklyInsight.recommendations
            : [],
        consistencyScore: finalConsistencyScore,
        topTopics: finalTopTopics,
      moodTrendData: moodData,
      weeklyInsight: weeklyInsight, // Store full AI insight for UI
    );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRANA001',
        errorMessage: 'Failed to get weekly analytics: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'week_start': weekStart.toIso8601String(),
          'operation': 'get_weekly_analytics',
        },
      );
      rethrow;
    }
  }

  /// Get monthly analytics data (aggregated from 4 weeks)
  Future<MonthlyAnalyticsData> getMonthlyAnalytics(DateTime monthStart) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
      final monthStartStr = '${monthStart.year.toString().padLeft(4, '0')}-'
          '${monthStart.month.toString().padLeft(2, '0')}-01';
      final monthEndStr = '${monthEnd.year.toString().padLeft(4, '0')}-'
          '${monthEnd.month.toString().padLeft(2, '0')}-'
          '${monthEnd.day.toString().padLeft(2, '0')}';

      // Fetch AI-generated monthly insight
      final monthlyInsight = await _aiService.getMonthlyInsight(userId, monthStart);

      // Fetch entries for the month
      final entriesResponse = await _supabase
          .from('entries')
          .select('id, entry_date, mood_score')
          .eq('user_id', userId)
          .gte('entry_date', monthStartStr)
          .lte('entry_date', monthEndStr);

      // Fetch water cups from entry_meals
      final entryIds = (entriesResponse as List).map((e) => e['id'] as String).toList();
      List mealsResponse = [];
      if (entryIds.isNotEmpty) {
        mealsResponse = await _supabase
            .from('entry_meals')
            .select('entry_id, water_cups')
            .inFilter('entry_id', entryIds);
      }

      // Fetch self-care data from habits_daily
      List habitsResponse = [];
      habitsResponse = await _supabase
          .from('habits_daily')
          .select('date, self_care_completed_count')
          .eq('user_id', userId)
          .gte('date', monthStartStr)
          .lte('date', monthEndStr);

      final entries = entriesResponse as List;
      final meals = mealsResponse;
      final habits = habitsResponse;
      final mealsMap = <String, int>{};
      for (final meal in meals) {
        mealsMap[meal['entry_id'] as String] = (meal['water_cups'] as num?)?.toInt() ?? 0;
      }

      final totalEntries = entries.length;

      // Calculate averages
      double? avgMood;
      double avgCups = 0;
      double avgSelfCareRate = 0;
      if (entries.isNotEmpty) {
        final moodScores = entries
            .where((e) => e['mood_score'] != null)
            .map((e) => (e['mood_score'] as num).toDouble())
            .toList();
        avgMood = moodScores.isNotEmpty
            ? moodScores.reduce((a, b) => a + b) / moodScores.length
            : null;

        final cups = entries
            .map((e) => mealsMap[e['id'] as String] ?? 0)
            .where((c) => c > 0)
            .toList();
        avgCups = cups.isNotEmpty ? cups.reduce((a, b) => a + b) / cups.length : 0;

        final selfCareCounts = habits
            .where((h) => h['self_care_completed_count'] != null)
            .map((h) => (h['self_care_completed_count'] as num).toDouble())
            .toList();
        final totalSelfCare = selfCareCounts.isNotEmpty
            ? selfCareCounts.reduce((a, b) => a + b)
            : 0;
        avgSelfCareRate = totalEntries > 0 ? totalSelfCare / (totalEntries * 5) : 0;
      }

      // Calculate overall consistency
      final daysInMonth = monthEnd.day;
      final overallConsistency = totalEntries / daysInMonth;

      // Build mood trend data (weekly averages)
      final moodData = <MoodDataPoint>[];
      for (int week = 0; week < 4; week++) {
        final weekStart = monthStart.add(Duration(days: week * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));
        final weekEntries = entries.where((e) {
          final entryDate = DateTime.parse(e['entry_date'] as String);
          return entryDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              entryDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();

        double? weekMood;
        if (weekEntries.isNotEmpty) {
          final weekMoodScores = weekEntries
              .where((e) => e['mood_score'] != null)
              .map((e) => (e['mood_score'] as num).toDouble())
              .toList();
          weekMood = weekMoodScores.isNotEmpty
              ? weekMoodScores.reduce((a, b) => a + b) / weekMoodScores.length
              : null;
        }

        moodData.add(MoodDataPoint(
          date: weekStart,
          moodScore: weekMood ?? 0,
          label: 'Week ${week + 1}',
        ));
      }

      // Use AI-generated insights if available, otherwise use calculated fallback
      final hasAiInsight = monthlyInsight != null && monthlyInsight.monthlyHighlights.isNotEmpty;
      
      return MonthlyAnalyticsData(
        monthStart: monthStart,
        monthEnd: monthEnd,
        totalEntries: totalEntries,
        avgMood: monthlyInsight?.moodAvg ?? avgMood ?? 0,
        avgCups: avgCups,
        avgSelfCareRate: avgSelfCareRate.clamp(0.0, 1.0),
        overallConsistency: monthlyInsight?.consistencyScore ?? overallConsistency,
        combinedTopics: monthlyInsight?.topTopics ?? [],
        overallMoodTrend: monthlyInsight?.moodTrendMonthly ?? (avgMood != null && avgMood > 3.5 ? 'improving' : 'stable'),
        combinedHighlights: hasAiInsight 
            ? monthlyInsight.monthlyHighlights
            : '',
        keyInsights: hasAiInsight && monthlyInsight.achievements.isNotEmpty
            ? monthlyInsight.achievements
            : [],
        recommendations: hasAiInsight && monthlyInsight.nextMonthGoals.isNotEmpty
            ? monthlyInsight.nextMonthGoals
            : [],
        moodTrendData: moodData,
        monthlyInsight: monthlyInsight, // Store full AI insight for UI
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRANA002',
        errorMessage: 'Failed to get monthly analytics: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'month_start': monthStart.toIso8601String(),
          'operation': 'get_monthly_analytics',
        },
      );
      rethrow;
    }
  }

  /// Get period comparison data
  Future<PeriodComparison> getPeriodComparison(
    String userId,
    AnalyticsPeriod period,
  ) async {
    try {
      DateTime currentStart, currentEnd, previousStart, previousEnd;

      if (period == AnalyticsPeriod.weekly) {
        final now = DateTime.now();
        final currentWeekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
        currentStart = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
        currentEnd = currentStart.add(const Duration(days: 6));
        previousStart = currentStart.subtract(const Duration(days: 7));
        previousEnd = previousStart.add(const Duration(days: 6));
      } else {
        final now = DateTime.now();
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime(now.year, now.month + 1, 0);
        previousStart = DateTime(now.year, now.month - 1, 1);
        previousEnd = DateTime(now.year, now.month, 0);
      }

      // Fetch current period data
      final currentData = await _fetchPeriodData(userId, currentStart, currentEnd);
      
      // Fetch previous period data
      final previousData = await _fetchPeriodData(userId, previousStart, previousEnd);

      // Calculate metrics
      final moodChange = (currentData.avgMood ?? 0) - (previousData.avgMood ?? 0);
      final entriesChange = currentData.entriesCount - previousData.entriesCount;
      final consistencyChange = currentData.consistencyScore - previousData.consistencyScore;
      final selfCareChange = currentData.selfCareRate - previousData.selfCareRate;

      // Determine overall trend
      String overallTrend = 'stable';
      final improvements = [
        moodChange > 0,
        entriesChange > 0,
        consistencyChange > 0,
        selfCareChange > 0,
      ].where((x) => x).length;
      final declines = [
        moodChange < 0,
        entriesChange < 0,
        consistencyChange < 0,
        selfCareChange < 0,
      ].where((x) => x).length;

      if (improvements > declines) {
        overallTrend = 'improving';
      } else if (declines > improvements) {
        overallTrend = 'declining';
      }

      return PeriodComparison(
        current: currentData,
        previous: previousData,
        metrics: ComparisonMetrics(
          moodChange: moodChange,
          entriesChange: entriesChange,
          consistencyChange: consistencyChange,
          selfCareChange: selfCareChange,
          overallTrend: overallTrend,
        ),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRANA003',
        errorMessage: 'Failed to get period comparison: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'period': period.toString(),
          'operation': 'get_period_comparison',
        },
      );
      rethrow;
    }
  }

  /// Helper: Fetch period data
  Future<PeriodData> _fetchPeriodData(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = '${startDate.year.toString().padLeft(4, '0')}-'
        '${startDate.month.toString().padLeft(2, '0')}-'
        '${startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year.toString().padLeft(4, '0')}-'
        '${endDate.month.toString().padLeft(2, '0')}-'
        '${endDate.day.toString().padLeft(2, '0')}';

    final entriesResponse = await _supabase
        .from('entries')
        .select('id, entry_date, mood_score')
        .eq('user_id', userId)
        .gte('entry_date', startStr)
        .lte('entry_date', endStr);

    // Fetch self-care data from habits_daily
    final habitsResponse = await _supabase
        .from('habits_daily')
        .select('date, self_care_completed_count')
        .eq('user_id', userId)
        .gte('date', startStr)
        .lte('date', endStr);

    final entries = entriesResponse as List;
    final habits = habitsResponse as List;
    final entriesCount = entries.length;

    double? avgMood;
    double selfCareRate = 0;
    if (entries.isNotEmpty) {
      final moodScores = entries
          .where((e) => e['mood_score'] != null)
          .map((e) => (e['mood_score'] as num).toDouble())
          .toList();
      avgMood = moodScores.isNotEmpty
          ? moodScores.reduce((a, b) => a + b) / moodScores.length
          : null;

      final selfCareCounts = habits
          .where((h) => h['self_care_completed_count'] != null)
          .map((h) => (h['self_care_completed_count'] as num).toDouble())
          .toList();
      final totalSelfCare = selfCareCounts.isNotEmpty
          ? selfCareCounts.reduce((a, b) => a + b)
          : 0;
      selfCareRate = entriesCount > 0 ? totalSelfCare / (entriesCount * 5) : 0;
    }

    final daysDiff = endDate.difference(startDate).inDays + 1;
    final consistencyScore = entriesCount / daysDiff;

    return PeriodData(
      startDate: startDate,
      endDate: endDate,
      entriesCount: entriesCount,
      avgMood: avgMood,
      consistencyScore: consistencyScore,
      selfCareRate: selfCareRate.clamp(0.0, 1.0),
    );
  }

  /// Format date range for display
  static String formatDateRange(DateTime start, DateTime end) {
    final startStr = '${start.day}/${start.month}';
    final endStr = '${end.day}/${end.month}/${end.year}';
    return '$startStr - $endStr';
  }

  /// Format month for display
  static String formatMonth(DateTime monthStart) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[monthStart.month - 1]} ${monthStart.year}';
  }
}
