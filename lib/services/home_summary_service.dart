import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_summary_models.dart';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';
import 'ai_service.dart';
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
    try {
      final now = DateTime.now();
      // Calculate Sunday of current week (weekday: Mon=1, Sun=7)
      final thisWeekStart = now.subtract(
        Duration(days: now.weekday == 7 ? 0 : now.weekday),
      );
      final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));

      final results = await Future.wait([
        _fetchStreak(userId),
        _fetchTodayProgress(userId, now),
        _fetchWeeklySnapshot(userId, thisWeekStart, prevWeekStart),
        _fetchPromptMotivation(userId),
      ]);

      return HomeSummary(
        streak: results[0] as StreakSummary?,
        today: results[1] as TodayProgressSummary?,
        weekly: results[2] as WeeklySnapshotSummary?,
        prompt: results[3] as PromptMotivationSummary?,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS151',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'operation': 'home_summary_fetchAll', 'user_id': userId},
        ),
      );
      rethrow;
    }
  }

  Future<StreakSummary?> _fetchStreak(String userId) async {
    try {
      Map<String, dynamic>? res;

      if (_dataFetchService != null) {
        // Use cached fetchStreaks (now reconnected)
        res = await _dataFetchService.fetchStreaks(userId);
      } else {
        // Fallback: read from local SQLite
        final db = await DatabaseManager().database;
        final streaks = await db.query(
          'streaks',
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1,
        );

        if (streaks.isNotEmpty) {
          final streak = streaks.first;
          res = {
            'current': streak['current'],
            'longest': streak['longest'],
            'freeze_credits': streak['freeze_credits'],
            'grace_pieces_total': streak['grace_pieces_total'],
          };
        }
      }

      if (res == null) return null;
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
      rethrow;
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
        // Use cached methods (now reconnected)
        final habitsData = await _dataFetchService.fetchHabitsForDate(
          userId,
          today,
        );
        final entryData = await _dataFetchService.fetchEntryByDate(
          userId,
          today,
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
        final meals = await _supabase
            .from('entry_meals')
            .select('water_cups')
            .eq('entry_id', entry['id'] as String)
            .maybeSingle();
        if (meals != null) waterCups = (meals['water_cups'] ?? 0) as int;
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
      rethrow;
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

  Future<PromptMotivationSummary?> _fetchPromptMotivation(String userId) async {
    try {
      final today = DateTime.now();
      final local = DateTime(today.year, today.month, today.day);
      final dateOnly =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';

      String promptText = '';

      final assigned = await _supabase
          .from('prompt_assignments')
          .select('prompt_id, prompts(text)')
          .eq('user_id', userId)
          .eq('assigned_for_date', dateOnly)
          .limit(1)
          .maybeSingle();

      if (assigned != null) {
        final nested = assigned['prompts'] as Map<String, dynamic>?;
        if (nested != null && nested['text'] is String) {
          promptText = nested['text'] as String;
        }
      }

      if (promptText.isEmpty) {
        final prompt = await _supabase
            .from('prompts')
            .select('text')
            .eq('active', true)
            .limit(1)
            .maybeSingle();
        promptText = (prompt != null && prompt['text'] is String)
            ? prompt['text'] as String
            : 'What’s on your mind today?';
      }

      // Fetch streak and settings using DataFetchService if available
      Map<String, dynamic>? streak;
      Map<String, dynamic>? settings;

      if (_dataFetchService != null) {
        // Use cached methods
        streak = await _dataFetchService.fetchStreaks(userId);
        settings = await _dataFetchService.fetchUserSettings(userId);
      } else {
        // Fallback to direct queries
        streak = await _supabase
            .from('streaks')
            .select('freeze_credits')
            .eq('user_id', userId)
            .maybeSingle();

        settings = await _supabase
            .from('user_settings')
            .select('reminder_time_local')
            .eq('user_id', userId)
            .maybeSingle();
      }

      final freeze = streak != null
          ? (streak['freeze_credits'] ?? 0) as int
          : 0;

      final nextReminder = settings != null
          ? (settings['reminder_time_local'] as String?)
          : null;

      return PromptMotivationSummary(
        promptText: promptText,
        freezeCredits: freeze,
        nextReminderTime: nextReminder,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRSYS155',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'operation': 'home_summary_fetchPrompt',
            'user_id': userId,
          },
        ),
      );
      rethrow;
    }
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
