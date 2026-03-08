import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_summary_models.dart';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';
import 'ai_service.dart';
import 'connectivity_service.dart';
import '../services/database/local_entry_service.dart';
import '../models/entry_models.dart';
import 'data_fetch_service.dart';
import 'database/database_manager.dart';

class HomeSummaryService {
  final SupabaseClient _supabase;
  final AIService _aiService;
  final DataFetchService? _dataFetchService;

  HomeSummaryService({
    SupabaseClient? client,
    AIService? aiService,
    DataFetchService? dataFetchService,
  }) : _supabase = client ?? Supabase.instance.client,
       _aiService = aiService ?? AIService(client: client),
       _dataFetchService = dataFetchService;

  Future<HomeSummary> fetchAll(String userId) async {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(
      Duration(days: now.weekday == 7 ? 0 : now.weekday),
    );
    final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final results = await Future.wait([
      _safeFetch(() => _fetchStreak(userId), 'fetchStreak', userId),
      _safeFetch(() => _fetchTodayProgress(userId, now), 'fetchToday', userId),
      _safeFetch(
        () => _fetchWeeklySnapshot(userId, thisWeekStart, prevWeekStart),
        'fetchWeekly',
        userId,
      ),
    ]);

    return HomeSummary(
      streak: results[0] as StreakSummary?,
      today: results[1] as TodayProgressSummary?,
      weekly: results[2] as WeeklySnapshotSummary?,
    );
  }

  /// Wraps a fetch in try/catch; logs error and returns null on failure.
  Future<T?> _safeFetch<T>(
    Future<T?> Function() fn,
    String operation,
    String userId,
  ) async {
    try {
      return await fn();
    } catch (e, st) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS151',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: st,
          errorContext: {'operation': operation, 'user_id': userId},
        ),
      );
      return null;
    }
  }

  Future<StreakSummary?> _fetchStreak(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (streaks.isEmpty) return null;
      final streak = streaks.first;
      final res = {
        'current': streak['current'],
        'longest': streak['longest'],
        'freeze_credits': streak['freeze_credits'],
        'grace_pieces_total': streak['grace_pieces_total'],
      };
      return StreakSummary(
        current: (res['current'] ?? 0) as int,
        longest: (res['longest'] ?? 0) as int,
        freezeCredits: (res['freeze_credits'] ?? 0) as int,
        gracePiecesTotal: ((res['grace_pieces_total'] ?? 0) as num).toDouble(),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS152',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'home_summary_fetchStreak',
            'user_id': userId,
          },
        ),
      );
      return null;
    }
  }

  Future<TodayProgressSummary?> _fetchTodayProgress(
    String userId,
    DateTime today,
  ) async {
    try {
      // Use date-only string to match DATE columns
      final local = DateTime(today.year, today.month, today.day);
      final dateOnly =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';

      // Fetch entry and habits using DataFetchService or local SQLite
      Map<String, dynamic>? entry;
      Map<String, dynamic>? habits;

      if (_dataFetchService != null) {
        final isOnline = await ConnectivityService().isOnline();
        final habitsData = await _dataFetchService.fetchHabitsForDate(
          userId,
          today,
        );
        final entryData = await _dataFetchService.fetchEntryByDate(
          userId,
          today,
          useLocalOnly: !isOnline,
        );

        if (habitsData != null) {
          habits = {
            'wrote_entry': habitsData.wroteEntry,
            'filled_affirmations': habitsData.filledAffirmations,
            'filled_gratitude': habitsData.filledGratitude,
            'self_care_completed_count': habitsData.selfCareCompletedCount,
            'grace_pieces_earned': habitsData.gracePiecesEarned,
          };
        }

        if (entryData != null) {
          entry = {'id': entryData.id};
        }
      } else {
        // Fallback: read from local SQLite
        final db = await DatabaseManager().database;

        final habitsList = await db.query(
          'habits_daily',
          where: 'user_id = ? AND date = ?',
          whereArgs: [userId, dateOnly],
          limit: 1,
        );

        if (habitsList.isNotEmpty) {
          final habit = habitsList.first;
          habits = {
            'wrote_entry': (habit['wrote_entry'] as int? ?? 0) == 1,
            'filled_affirmations':
                (habit['filled_affirmations'] as int? ?? 0) == 1,
            'filled_gratitude': (habit['filled_gratitude'] as int? ?? 0) == 1,
            'self_care_completed_count':
                habit['self_care_completed_count'] as int? ?? 0,
            'grace_pieces_earned': (habit['grace_pieces_earned'] as num? ?? 0.0)
                .toDouble(),
          };
        }

        final entriesList = await db.query(
          'entries',
          columns: ['id'],
          where: 'user_id = ? AND entry_date = ?',
          whereArgs: [userId, dateOnly],
          limit: 1,
        );

        if (entriesList.isNotEmpty) {
          entry = {'id': entriesList.first['id']};
        }
      }

      int waterCups = 0;
      if (entry != null) {
        final db = await DatabaseManager().database;
        final mealsRows = await db.query(
          'entry_meals',
          columns: ['water_cups'],
          where: 'entry_id = ?',
          whereArgs: [entry['id'] as String],
          limit: 1,
        );
        if (mealsRows.isNotEmpty) {
          waterCups = mealsRows.first['water_cups'] as int? ?? 0;
        }
      }

      // Return today's progress with habits data
      return TodayProgressSummary(
        wroteEntry: habits?['wrote_entry'] ?? false,
        filledAffirmations: habits?['filled_affirmations'] ?? false,
        filledGratitude: habits?['filled_gratitude'] ?? false,
        selfCareCompletedCount: habits?['self_care_completed_count'] ?? 0,
        gracePiecesEarned: ((habits?['grace_pieces_earned'] ?? 0.0) as num)
            .toDouble(),
        waterCups: waterCups,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS153',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'home_summary_fetchToday',
            'user_id': userId,
          },
        ),
      );
      return null;
    }
  }

  Future<WeeklySnapshotSummary?> _fetchWeeklySnapshot(
    String userId,
    DateTime thisWeekStart,
    DateTime prevWeekStart,
  ) async {
    try {
      // Skip weekly_insights check - directly calculate from local DB
      return await _calculateCurrentWeekFromLocal(userId, thisWeekStart);
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS154',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: stackTrace,
          errorContext: {
            'operation': 'home_summary_fetchWeekly',
            'user_id': userId,
          },
        ),
      );
      return null; // Graceful degradation - show no data
    }
  }

  /// Calculate current week metrics from local database
  Future<WeeklySnapshotSummary?> _calculateCurrentWeekFromLocal(
    String userId,
    DateTime weekStart,
  ) async {
    try {
      // Calculate days elapsed
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final weekStartOnly = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final daysElapsed = todayOnly.difference(weekStartOnly).inDays + 1;

      // Get current week entries from local DB
      final localService = LocalEntryService();
      final weekEnd = todayOnly; // Only up to today
      final entries = await localService.getEntriesInRange(
        userId,
        weekStartOnly,
        weekEnd,
      );

      // If no entries, return null (will show 0.0 in UI)
      if (entries.isEmpty) {
        return null;
      }

      // Calculate Avg Mood
      double? moodAvg;
      final moodScores = entries
          .where((e) => e.moodScore != null)
          .map((e) => e.moodScore!.toDouble())
          .toList();
      if (moodScores.isNotEmpty) {
        final sum = moodScores.reduce((a, b) => a + b);
        moodAvg = sum / moodScores.length; // Divide by entries with mood data
      }

      // Calculate Water Intake
      double cupsAvg = 0.0;
      int totalCups = 0;
      for (final entry in entries) {
        final meals = await localService.getMeals(entry.id);
        if (meals != null) {
          totalCups += meals.waterCups;
        }
      }
      cupsAvg = daysElapsed > 0 ? totalCups / daysElapsed : 0.0;

      // Calculate Self-Care %
      double selfCareRate = 0.0;
      int totalSelfCareCount = 0;
      for (final entry in entries) {
        final selfCare = await localService.getSelfCare(entry.id);
        if (selfCare != null) {
          // Count completed self-care items (10 max)
          totalSelfCareCount += _countSelfCareItems(selfCare);
        }
      }
      selfCareRate = daysElapsed > 0
          ? totalSelfCareCount / (daysElapsed * 10)
          : 0.0;

      // Calculate Consistency
      final consistency = daysElapsed > 0 ? entries.length / daysElapsed : 0.0;

      return WeeklySnapshotSummary(
        moodAvg: moodAvg,
        cupsAvg: cupsAvg,
        selfCareRate: selfCareRate.clamp(0.0, 1.0),
        topTopics: null, // Not calculated from local
        highlights: null, // Not calculated from local
        moodDelta: null, // Not calculated (would need prev week)
        consistency: consistency.clamp(0.0, 1.0),
      );
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS155',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: stackTrace,
          errorContext: {
            'operation': 'home_summary_calculateCurrentWeek',
            'user_id': userId,
            'week_start': weekStart.toIso8601String(),
          },
        ),
      );
      return null; // Graceful degradation - show no data
    }
  }

  /// Count completed self-care items from EntrySelfCare model
  int _countSelfCareItems(EntrySelfCare selfCare) {
    int count = 0;
    if (selfCare.sleep) count++;
    if (selfCare.getUpEarly) count++;
    if (selfCare.freshAir) count++;
    if (selfCare.learnNew) count++;
    if (selfCare.balancedDiet) count++;
    if (selfCare.podcast) count++;
    if (selfCare.meMoment) count++;
    if (selfCare.hydrated) count++;
    if (selfCare.readBook) count++;
    if (selfCare.exercise) count++;
    return count; // Returns 0-10
  }

  /// Fetch AI insight with fallback ladder
  /// DEPRECATED: Use yesterdayInsightProvider instead
  Future<String?> fetchAiInsight(String userId) async {
    try {
      final insight = await _aiService.getYesterdayInsight(userId);
      return insight?.insightText;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS156',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'home_summary_fetchAiInsight',
            'user_id': userId,
          },
        ),
      );
      return null;
    }
  }
}
