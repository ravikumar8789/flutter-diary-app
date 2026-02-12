import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';
import 'ai_service.dart';
import 'data_fetch_service.dart';

class AnalyticsService {
  final SupabaseClient _supabase;
  final AIService _aiService;
  final DataFetchService? _dataFetchService;

  AnalyticsService({
    SupabaseClient? client,
    AIService? aiService,
    DataFetchService? dataFetchService,
  }) : _supabase = client ?? Supabase.instance.client,
       _aiService = aiService ?? AIService(),
       _dataFetchService = dataFetchService;

  /// Get weekly analytics data from Supabase
  Future<WeeklyAnalyticsData> getWeeklyAnalytics(DateTime weekStart) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekStartStr =
          '${weekStart.year.toString().padLeft(4, '0')}-'
          '${weekStart.month.toString().padLeft(2, '0')}-'
          '${weekStart.day.toString().padLeft(2, '0')}';
      final weekEndStr =
          '${weekEnd.year.toString().padLeft(4, '0')}-'
          '${weekEnd.month.toString().padLeft(2, '0')}-'
          '${weekEnd.day.toString().padLeft(2, '0')}';

      // Fetch entries for the week
      List<Map<String, dynamic>> entries;
      List<Map<String, dynamic>> mealsResponse = [];
      List<Map<String, dynamic>> habitsResponse = [];

      if (_dataFetchService != null) {
        // Use cached fetchEntries and fetchHabitsDaily
        final entriesList = await _dataFetchService.fetchEntries(
          userId: userId,
          startDate: weekStart,
          endDate: weekEnd,
        );
        entries = entriesList
            .map(
              (e) => {
                'id': e.id,
                'entry_date': e.entryDate.toIso8601String().split('T')[0],
                'mood_score': e.moodScore,
              },
            )
            .toList();

        // DISCONNECTED: Habits feature disabled
        habitsResponse = <Map<String, dynamic>>[]; // Return empty list

        /* DISCONNECTED CODE - Habits feature disabled
        final habitsList = await _dataFetchService.fetchHabitsDaily(
          userId: userId,
          startDate: weekStart,
          endDate: weekEnd,
        );
        habitsResponse = habitsList.map((h) => {
          'date': h.date.toIso8601String().split('T')[0],
          'self_care_completed_count': h.selfCareCompletedCount,
        }).toList();
        */

        // For meals, we still need to query directly since we don't have a cached method for entry_meals
        final entryIds = entries.map((e) => e['id'] as String).toList();
        if (entryIds.isNotEmpty) {
          mealsResponse = List<Map<String, dynamic>>.from(
            await _supabase
                .from('entry_meals')
                .select('entry_id, water_cups')
                .inFilter('entry_id', entryIds),
          );
        }
      } else {
        // Fallback to direct queries
        final entriesResponse = await _supabase
            .from('entries')
            .select('id, entry_date, mood_score')
            .eq('user_id', userId)
            .gte('entry_date', weekStartStr)
            .lte('entry_date', weekEndStr);

        final entryIds = (entriesResponse as List)
            .map((e) => e['id'] as String)
            .toList();
        if (entryIds.isNotEmpty) {
          mealsResponse = List<Map<String, dynamic>>.from(
            await _supabase
                .from('entry_meals')
                .select('entry_id, water_cups')
                .inFilter('entry_id', entryIds),
          );
        }

        // DISCONNECTED: Habits feature disabled
        habitsResponse = <Map<String, dynamic>>[]; // Return empty list

        /* DISCONNECTED CODE - Habits feature disabled
        habitsResponse = List<Map<String, dynamic>>.from(
          await _supabase
          .from('habits_daily')
          .select('date, self_care_completed_count')
          .eq('user_id', userId)
          .gte('date', weekStartStr)
              .lte('date', weekEndStr),
        );
        */

        entries = List<Map<String, dynamic>>.from(entriesResponse);
      }
      final meals = mealsResponse;
      final habits = habitsResponse;
      final mealsMap = <String, int>{};
      for (final meal in meals) {
        mealsMap[meal['entry_id'] as String] =
            (meal['water_cups'] as num?)?.toInt() ?? 0;
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
        cupsAvg = cups.isNotEmpty
            ? cups.reduce((a, b) => a + b) / cups.length
            : 0;

        final selfCareCounts = habits
            .where((h) => h['self_care_completed_count'] != null)
            .map((h) => (h['self_care_completed_count'] as num).toDouble())
            .toList();
        final totalSelfCare = selfCareCounts.isNotEmpty
            ? selfCareCounts.reduce((a, b) => a + b)
            : 0;
        // self_care_completed_count in habits_daily can include up to 10 checklist items.
        // Use 10 as the denominator to keep the rate within 0-1.
        selfCareRate = entriesCount > 0
            ? totalSelfCare / (entriesCount * 10)
            : 0;
      }

      // Fetch AI-generated weekly insight
      final weeklyInsight = await _aiService.getWeeklyInsight(
        userId,
        weekStart,
      );

      // Use AI-generated values if available, otherwise use calculated fallback
      final hasAiInsight =
          weeklyInsight != null && weeklyInsight.highlights.isNotEmpty;

      // Use AI values or calculated fallback
      final finalMoodAvg = weeklyInsight?.moodAvg ?? moodAvg;
      final finalCupsAvg = weeklyInsight?.cupsAvg ?? cupsAvg;
      // weeklyInsight.selfCareRate is percentage (0-100) from database - use directly
      // selfCareRate from local calc is decimal (0-1) - convert to percentage (0-100)
      final finalSelfCareRate =
          weeklyInsight?.selfCareRate ?? (selfCareRate * 100.0);
      final finalConsistencyScore =
          weeklyInsight?.consistencyScore ?? (entriesCount / 7.0);
      final finalEntriesCount = weeklyInsight?.entriesCount ?? entriesCount;
      final finalTopTopics = weeklyInsight?.topTopics ?? [];

      // Build mood trend data and daily progress
      final moodData = <MoodDataPoint>[];
      final dailyProgressList = <DailyProgress>[];
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      // Fetch entries with full data for daily progress
      List<Map<String, dynamic>> entriesWithData;
      final entryIds = entries.map((e) => e['id'] as String).toList();

      if (_dataFetchService != null) {
        // Use cached fetchEntries
        final entriesList = await _dataFetchService.fetchEntries(
          userId: userId,
          startDate: weekStart,
          endDate: weekEnd,
        );
        entriesWithData = entriesList
            .map(
              (e) => {
                'id': e.id,
                'entry_date': e.entryDate.toIso8601String().split('T')[0],
                'mood_score': e.moodScore,
                'diary_text': e.diaryText,
              },
            )
            .toList();
      } else {
        // Fallback to direct query
        entriesWithData = List<Map<String, dynamic>>.from(
          await _supabase
              .from('entries')
              .select('id, entry_date, mood_score, diary_text')
              .eq('user_id', userId)
              .gte('entry_date', weekStartStr)
              .lte('entry_date', weekEndStr),
        );
      }

      final entriesMap = <String, Map<String, dynamic>>{};
      for (final entry in entriesWithData) {
        final dateStr = entry['entry_date'] as String;
        entriesMap[dateStr] = entry;
      }

      // Fetch self-care data per entry
      final selfCareData = await _supabase
          .from('entry_self_care')
          .select('entry_id')
          .inFilter('entry_id', entryIds);

      final selfCareEntryIds = (selfCareData as List)
          .map((e) => e['entry_id'] as String)
          .toSet();

      int wordCountTotal = 0;

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

        final dayEntry = entriesMap[dateStr];
        double? moodScore;
        int waterCups = 0;
        double selfCareCompletion = 0.0;
        bool hasEntry = dayEntry != null;
        String? entryPreview;

        if (dayEntry != null) {
          moodScore = (dayEntry['mood_score'] as num?)?.toDouble() ?? 3.0;
          final entryId = dayEntry['id'] as String;

          // Get water cups
          final mealData = meals.firstWhere(
            (m) => m['entry_id'] == entryId,
            orElse: () => <String, dynamic>{},
          );
          waterCups = (mealData['water_cups'] as num?)?.toInt() ?? 0;

          // Calculate self-care completion
          final hasSelfCare = selfCareEntryIds.contains(entryId);
          if (hasSelfCare) {
            // Count self-care activities (simplified - assume 5 max)
            selfCareCompletion =
                0.8; // Placeholder, will be calculated properly
          }

          // Get entry preview
          final diaryText = dayEntry['diary_text'] as String?;
          if (diaryText != null) {
            wordCountTotal += diaryText.split(RegExp(r'\s+')).length;
            entryPreview = diaryText.length > 100
                ? '${diaryText.substring(0, 100)}...'
                : diaryText;
          }
        }

        moodData.add(
          MoodDataPoint(
            date: date,
            moodScore: moodScore ?? 0,
            label: dayNames[i],
          ),
        );

        dailyProgressList.add(
          DailyProgress(
            date: date,
            moodScore: moodScore,
            waterCups: waterCups,
            selfCareCompletion: selfCareCompletion,
            hasEntry: hasEntry,
            entryPreview: entryPreview,
            dayLabel: dayNames[date.weekday - 1],
          ),
        );
      }

      // Check if current week
      final now = DateTime.now();
      final currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
      final isCurrentWeek =
          weekStart.year == currentWeekStart.year &&
          weekStart.month == currentWeekStart.month &&
          weekStart.day == currentWeekStart.day;

      return WeeklyAnalyticsData(
        id: 'weekly-${weekStart.toIso8601String()}',
        weekStart: weekStart,
        weekEnd: weekEnd,
        entriesCount: finalEntriesCount,
        moodAvg: finalMoodAvg,
        cupsAvg: finalCupsAvg,
        selfCareRate: finalSelfCareRate,
        moodTrend: weeklyInsight?.moodTrend,
        highlights: hasAiInsight ? weeklyInsight.highlights : '',
        keyInsights: hasAiInsight && weeklyInsight.keyInsights.isNotEmpty
            ? weeklyInsight.keyInsights
            : [],
        recommendations:
            hasAiInsight && weeklyInsight.recommendations.isNotEmpty
            ? weeklyInsight.recommendations
            : [],
        consistencyScore: finalConsistencyScore,
        topTopics: finalTopTopics,
        moodTrendData: moodData,
        weeklyInsight: weeklyInsight, // Store full AI insight for UI
        habitCorrelations: weeklyInsight != null
            ? _parseHabitCorrelations(weeklyInsight.habitCorrelations)
            : null,
        wordCountTotal: weeklyInsight?.wordCountTotal ?? wordCountTotal,
        dailyProgress: dailyProgressList,
        generatedAt: weeklyInsight?.generatedAt,
        isCurrentWeek: isCurrentWeek,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRANA001',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'week_start': weekStart.toIso8601String(),
            'operation': 'get_weekly_analytics',
          },
        ),
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
      final monthStartStr =
          '${monthStart.year.toString().padLeft(4, '0')}-'
          '${monthStart.month.toString().padLeft(2, '0')}-01';
      final monthEndStr =
          '${monthEnd.year.toString().padLeft(4, '0')}-'
          '${monthEnd.month.toString().padLeft(2, '0')}-'
          '${monthEnd.day.toString().padLeft(2, '0')}';

      // Fetch AI-generated monthly insight
      final monthlyInsight = await _aiService.getMonthlyInsight(
        userId,
        monthStart,
      );

      // Fetch entries for the month
      List<Map<String, dynamic>> entries;
      List<Map<String, dynamic>> mealsResponse = [];
      List<Map<String, dynamic>> habitsResponse = [];

      if (_dataFetchService != null) {
        // Use cached fetchEntries and fetchHabitsDaily
        final entriesList = await _dataFetchService.fetchEntries(
          userId: userId,
          startDate: monthStart,
          endDate: monthEnd,
        );
        entries = entriesList
            .map(
              (e) => {
                'id': e.id,
                'entry_date': e.entryDate.toIso8601String().split('T')[0],
                'mood_score': e.moodScore,
              },
            )
            .toList();

        // DISCONNECTED: Habits feature disabled
        habitsResponse = <Map<String, dynamic>>[]; // Return empty list

        /* DISCONNECTED CODE - Habits feature disabled
        final habitsList = await _dataFetchService.fetchHabitsDaily(
          userId: userId,
          startDate: monthStart,
          endDate: monthEnd,
        );
        habitsResponse = habitsList.map((h) => {
          'date': h.date.toIso8601String().split('T')[0],
          'self_care_completed_count': h.selfCareCompletedCount,
        }).toList();
        */

        // For meals, we still need to query directly
        final entryIds = entries.map((e) => e['id'] as String).toList();
        if (entryIds.isNotEmpty) {
          mealsResponse = List<Map<String, dynamic>>.from(
            await _supabase
                .from('entry_meals')
                .select('entry_id, water_cups')
                .inFilter('entry_id', entryIds),
          );
        }
      } else {
        // Fallback to direct queries
        final entriesResponse = await _supabase
            .from('entries')
            .select('id, entry_date, mood_score')
            .eq('user_id', userId)
            .gte('entry_date', monthStartStr)
            .lte('entry_date', monthEndStr);

        final entryIds = (entriesResponse as List)
            .map((e) => e['id'] as String)
            .toList();
        if (entryIds.isNotEmpty) {
          mealsResponse = List<Map<String, dynamic>>.from(
            await _supabase
                .from('entry_meals')
                .select('entry_id, water_cups')
                .inFilter('entry_id', entryIds),
          );
        }

        // DISCONNECTED: Habits feature disabled
        habitsResponse = <Map<String, dynamic>>[]; // Return empty list

        /* DISCONNECTED CODE - Habits feature disabled
        habitsResponse = List<Map<String, dynamic>>.from(
          await _supabase
          .from('habits_daily')
          .select('date, self_care_completed_count')
          .eq('user_id', userId)
          .gte('date', monthStartStr)
              .lte('date', monthEndStr),
        );
        */

        entries = List<Map<String, dynamic>>.from(entriesResponse);
      }
      final meals = mealsResponse;
      final habits = habitsResponse;
      final mealsMap = <String, int>{};
      for (final meal in meals) {
        mealsMap[meal['entry_id'] as String] =
            (meal['water_cups'] as num?)?.toInt() ?? 0;
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
        avgCups = cups.isNotEmpty
            ? cups.reduce((a, b) => a + b) / cups.length
            : 0;

        final selfCareCounts = habits
            .where((h) => h['self_care_completed_count'] != null)
            .map((h) => (h['self_care_completed_count'] as num).toDouble())
            .toList();
        final totalSelfCare = selfCareCounts.isNotEmpty
            ? selfCareCounts.reduce((a, b) => a + b)
            : 0;
        avgSelfCareRate = totalEntries > 0
            ? totalSelfCare / (totalEntries * 5)
            : 0;
      }

      // Calculate overall consistency
      final daysInMonth = monthEnd.day;
      final overallConsistency = totalEntries / daysInMonth;

      // Build mood trend data (daily points for full month)
      final moodData = <MoodDataPoint>[];
      final moodByDay = <int, List<double>>{};
      for (final entry in entries) {
        final moodScore = (entry['mood_score'] as num?)?.toDouble();
        if (moodScore == null) continue;
        final entryDate = DateTime.parse(entry['entry_date'] as String);
        final day = entryDate.day;
        moodByDay.putIfAbsent(day, () => []).add(moodScore);
      }

      for (int day = 1; day <= daysInMonth; day++) {
        final scores = moodByDay[day];
        if (scores == null || scores.isEmpty) continue;
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        moodData.add(
          MoodDataPoint(
            date: DateTime(monthStart.year, monthStart.month, day),
            moodScore: avg,
            label: day.toString(),
          ),
        );
      }

      // Use AI-generated insights if available, otherwise use calculated fallback
      final hasAiInsight =
          monthlyInsight != null && monthlyInsight.monthlyHighlights.isNotEmpty;

      return MonthlyAnalyticsData(
        monthStart: monthStart,
        monthEnd: monthEnd,
        totalEntries: totalEntries,
        avgMood: monthlyInsight?.moodAvg ?? avgMood ?? 0,
        avgCups: avgCups,
        avgSelfCareRate: avgSelfCareRate.clamp(0.0, 1.0),
        overallConsistency:
            monthlyInsight?.consistencyScore ?? overallConsistency,
        combinedTopics: monthlyInsight?.topTopics ?? [],
        overallMoodTrend:
            monthlyInsight?.moodTrendMonthly ??
            (avgMood != null && avgMood > 3.5 ? 'improving' : 'stable'),
        combinedHighlights: hasAiInsight
            ? monthlyInsight.monthlyHighlights
            : '',
        keyInsights: hasAiInsight && monthlyInsight.achievements.isNotEmpty
            ? monthlyInsight.achievements
            : [],
        recommendations:
            hasAiInsight && monthlyInsight.nextMonthGoals.isNotEmpty
            ? monthlyInsight.nextMonthGoals
            : [],
        moodTrendData: moodData,
        monthlyInsight: monthlyInsight, // Store full AI insight for UI
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRANA002',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'month_start': monthStart.toIso8601String(),
            'operation': 'get_monthly_analytics',
          },
        ),
      );
      rethrow;
    }
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

  /// Get week list metadata for navigation (lightweight query)
  Future<List<WeekMetadata>> getWeeklyInsightsList(String userId) async {
    try {
      // Fetch weeks with insights
      final insightsResponse = await _supabase
          .from('weekly_insights')
          .select('week_start, week_end, status, entries_count, mood_avg')
          .eq('user_id', userId)
          .order('week_start', ascending: false)
          .limit(12); // Last 12 weeks

      final weeksList = <WeekMetadata>[];

      // Process weeks with insights
      for (final insight in insightsResponse as List) {
        weeksList.add(WeekMetadata.fromJson(insight));
      }

      // Get all week starts we already have
      final existingWeekStarts = weeksList
          .map(
            (w) =>
                '${w.weekStart.year}-${w.weekStart.month}-${w.weekStart.day}',
          )
          .toSet();

      // Also check for weeks with entries but no insights (last 4 weeks) - optimized batch query
      final now = DateTime.now();
      final weekStartsToCheck = <String>[];
      final weekStartDates = <String, DateTime>{};

      for (int i = 0; i < 4; i++) {
        final weekStart = now.subtract(
          Duration(days: now.weekday % 7 + (i * 7)),
        );
        final weekStartStr =
            '${weekStart.year.toString().padLeft(4, '0')}-'
            '${weekStart.month.toString().padLeft(2, '0')}-'
            '${weekStart.day.toString().padLeft(2, '0')}';
        final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';

        if (!existingWeekStarts.contains(weekKey)) {
          weekStartsToCheck.add(weekStartStr);
          weekStartDates[weekStartStr] = weekStart;
        }
      }

      // Batch query for entries in all weeks at once (much faster)
      if (weekStartsToCheck.isNotEmpty) {
        final earliestWeek = weekStartsToCheck.last;
        final latestWeekEnd = weekStartDates[weekStartsToCheck.first]!.add(
          const Duration(days: 6),
        );
        final latestWeekEndStr =
            '${latestWeekEnd.year.toString().padLeft(4, '0')}-'
            '${latestWeekEnd.month.toString().padLeft(2, '0')}-'
            '${latestWeekEnd.day.toString().padLeft(2, '0')}';

        final entriesResponse = await _supabase
            .from('entries')
            .select('entry_date')
            .eq('user_id', userId)
            .gte('entry_date', earliestWeek)
            .lte('entry_date', latestWeekEndStr);

        // Group entries by week
        final entriesByWeek = <String, int>{};
        for (final entry in entriesResponse) {
          final entryDate = DateTime.parse(entry['entry_date'] as String);
          final weekStart = entryDate.subtract(
            Duration(days: entryDate.weekday % 7),
          );
          final weekKey =
              '${weekStart.year}-${weekStart.month}-${weekStart.day}';
          entriesByWeek[weekKey] = (entriesByWeek[weekKey] ?? 0) + 1;
        }

        // Add weeks with entries
        for (final weekStartStr in weekStartsToCheck) {
          final weekStart = weekStartDates[weekStartStr]!;
          final weekKey =
              '${weekStart.year}-${weekStart.month}-${weekStart.day}';
          final entriesCount = entriesByWeek[weekKey] ?? 0;

          if (entriesCount > 0) {
            weeksList.add(
              WeekMetadata(
                weekStart: weekStart,
                weekEnd: weekStart.add(const Duration(days: 6)),
                status: 'none',
                entriesCount: entriesCount,
                hasAnalysis: false,
              ),
            );
          }
        }
      }

      // Sort by week_start descending
      weeksList.sort((a, b) => b.weekStart.compareTo(a.weekStart));

      return weeksList;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRANA002',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'get_weekly_insights_list',
          },
        ),
      );
      return [];
    }
  }

  /// Get list of months with insights (for navigation chips)
  Future<List<MonthMetadata>> getMonthlyInsightsList(String userId) async {
    try {
      // Fetch months with insights
      final insightsResponse = await _supabase
          .from('monthly_insights')
          .select('month_start, status, entries_count, mood_avg')
          .eq('user_id', userId)
          .order('month_start', ascending: false)
          .limit(12); // Last 12 months

      final monthsList = <MonthMetadata>[];

      // Process months with insights
      for (final insight in insightsResponse as List) {
        try {
          monthsList.add(MonthMetadata.fromJson(insight));
        } catch (e) {
          await ErrorLoggingService.logError(
            ErrorContext.fromException(
              errorCode: 'ERRMODEL001',
              severity: ErrorSeverity.medium,
              exception: e,
              stackTrace: StackTrace.current,
              errorContext: {
                'user_id': userId,
                'insight_data': insight.toString(),
                'operation': 'month_metadata_fromJson',
              },
            ),
          );
          // Continue processing other months
        }
      }

      // Get all month starts we already have
      final existingMonthStarts = monthsList
          .map((m) => '${m.monthStart.year}-${m.monthStart.month}')
          .toSet();

      // Also check for months with entries but no insights (last 3 months)
      final now = DateTime.now();
      final monthsToCheck = <String>[];
      final monthStartDates = <String, DateTime>{};

      for (int i = 1; i <= 3; i++) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthKey = '${monthStart.year}-${monthStart.month}';

        if (!existingMonthStarts.contains(monthKey)) {
          final monthStartStr =
              '${monthStart.year.toString().padLeft(4, '0')}-'
              '${monthStart.month.toString().padLeft(2, '0')}-01';
          monthsToCheck.add(monthStartStr);
          monthStartDates[monthStartStr] = monthStart;
        }
      }

      // Batch query for entries in all months at once
      if (monthsToCheck.isNotEmpty) {
        final earliestMonth = monthsToCheck.last;
        final latestMonthEnd = DateTime(
          monthStartDates[monthsToCheck.first]!.year,
          monthStartDates[monthsToCheck.first]!.month + 1,
          0,
        );
        final latestMonthEndStr =
            '${latestMonthEnd.year.toString().padLeft(4, '0')}-'
            '${latestMonthEnd.month.toString().padLeft(2, '0')}-'
            '${latestMonthEnd.day.toString().padLeft(2, '0')}';

        final entriesResponse = await _supabase
            .from('entries')
            .select('entry_date')
            .eq('user_id', userId)
            .gte('entry_date', earliestMonth)
            .lte('entry_date', latestMonthEndStr);

        // Group entries by month
        final entriesByMonth = <String, int>{};
        for (final entry in entriesResponse) {
          final entryDate = DateTime.parse(entry['entry_date'] as String);
          final monthKey = '${entryDate.year}-${entryDate.month}';
          entriesByMonth[monthKey] = (entriesByMonth[monthKey] ?? 0) + 1;
        }

        // Add months with entries
        for (final monthStartStr in monthsToCheck) {
          final monthStart = monthStartDates[monthStartStr]!;
          final monthKey = '${monthStart.year}-${monthStart.month}';
          final entriesCount = entriesByMonth[monthKey] ?? 0;

          if (entriesCount > 0) {
            monthsList.add(
              MonthMetadata(
                monthStart: monthStart,
                monthEnd: DateTime(monthStart.year, monthStart.month + 1, 0),
                status: 'none',
                entriesCount: entriesCount,
                hasAnalysis: false,
              ),
            );
          }
        }
      }

      // Sort by month_start descending
      monthsList.sort((a, b) => b.monthStart.compareTo(a.monthStart));

      return monthsList;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRANA004',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'get_monthly_insights_list',
          },
        ),
      );
      return [];
    }
  }

  /// Get daily progress for bar chart
  Future<List<DailyProgress>> getDailyProgress(
    String userId,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    try {
      final weekStartStr =
          '${weekStart.year.toString().padLeft(4, '0')}-'
          '${weekStart.month.toString().padLeft(2, '0')}-'
          '${weekStart.day.toString().padLeft(2, '0')}';
      final weekEndStr =
          '${weekEnd.year.toString().padLeft(4, '0')}-'
          '${weekEnd.month.toString().padLeft(2, '0')}-'
          '${weekEnd.day.toString().padLeft(2, '0')}';

      // Fetch entries with full data
      final entriesResponse = await _supabase
          .from('entries')
          .select('id, entry_date, mood_score, diary_text')
          .eq('user_id', userId)
          .gte('entry_date', weekStartStr)
          .lte('entry_date', weekEndStr);

      final entryIds = (entriesResponse as List)
          .map((e) => e['id'] as String)
          .toList();

      // Fetch meals and self-care in parallel
      final results = await Future.wait([
        entryIds.isNotEmpty
            ? _supabase
                  .from('entry_meals')
                  .select('entry_id, water_cups')
                  .inFilter('entry_id', entryIds)
            : Future.value([]),
        entryIds.isNotEmpty
            ? _supabase
                  .from('entry_self_care')
                  .select(
                    'entry_id, sleep, exercise, hydrated, balanced_diet, fresh_air, learn_new, podcast, me_moment, read_book',
                  )
                  .inFilter('entry_id', entryIds)
            : Future.value([]),
      ]);

      final mealsResponse = results[0];
      final selfCareResponse = results[1];

      // Create maps for quick lookup
      final mealsMap = <String, int>{};
      for (final meal in mealsResponse) {
        mealsMap[meal['entry_id'] as String] =
            (meal['water_cups'] as num?)?.toInt() ?? 0;
      }

      final selfCareMap = <String, int>{};
      for (final sc in selfCareResponse) {
        int count = 0;
        if (sc['sleep'] == true) count++;
        if (sc['exercise'] == true) count++;
        if (sc['hydrated'] == true) count++;
        if (sc['balanced_diet'] == true) count++;
        if (sc['fresh_air'] == true) count++;
        if (sc['learn_new'] == true) count++;
        if (sc['podcast'] == true) count++;
        if (sc['me_moment'] == true) count++;
        if (sc['read_book'] == true) count++;
        selfCareMap[sc['entry_id'] as String] = count;
      }

      // Build daily progress list
      final dailyProgressList = <DailyProgress>[];
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final entriesMap = <String, Map<String, dynamic>>{};

      for (final entry in entriesResponse) {
        final dateStr = entry['entry_date'] as String;
        entriesMap[dateStr] = entry;
      }

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

        final dayEntry = entriesMap[dateStr];
        double? moodScore;
        int waterCups = 0;
        double selfCareCompletion = 0.0;
        bool hasEntry = dayEntry != null;
        String? entryPreview;

        if (dayEntry != null) {
          moodScore = (dayEntry['mood_score'] as num?)?.toDouble();
          final entryId = dayEntry['id'] as String;

          waterCups = mealsMap[entryId] ?? 0;

          final selfCareCount = selfCareMap[entryId] ?? 0;
          selfCareCompletion = (selfCareCount / 9.0).clamp(
            0.0,
            1.0,
          ); // 9 max self-care activities

          final diaryText = dayEntry['diary_text'] as String?;
          if (diaryText != null) {
            entryPreview = diaryText.length > 100
                ? '${diaryText.substring(0, 100)}...'
                : diaryText;
          }
        }

        dailyProgressList.add(
          DailyProgress(
            date: date,
            moodScore: moodScore,
            waterCups: waterCups,
            selfCareCompletion: selfCareCompletion,
            hasEntry: hasEntry,
            entryPreview: entryPreview,
            dayLabel: dayNames[date.weekday - 1],
          ),
        );
      }

      return dailyProgressList;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRANA003',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'week_start': weekStart.toIso8601String(),
            'operation': 'get_daily_progress',
          },
        ),
      );
      return [];
    }
  }

  /// Parse habit correlations from JSONB
  Map<String, dynamic>? _parseHabitCorrelations(dynamic correlations) {
    if (correlations == null) return null;
    if (correlations is Map<String, dynamic>) return correlations;
    if (correlations is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(correlations));
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
