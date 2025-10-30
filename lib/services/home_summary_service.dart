import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_summary_models.dart';
import '../services/error_logging_service.dart';

class HomeSummaryService {
  final SupabaseClient _supabase;
  HomeSummaryService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  Future<HomeSummary> fetchAll(String userId) async {
    try {
      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
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
        errorCode: 'ERRSYS151',
        errorMessage: 'Home summary fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'home_summary_fetchAll',
          'user_id': userId,
        },
      );
      rethrow;
    }
  }

  Future<StreakSummary?> _fetchStreak(String userId) async {
    try {
      final res = await _supabase
          .from('streaks')
          .select('current, longest, freeze_credits, grace_pieces_total')
          .eq('user_id', userId)
          .maybeSingle();
      if (res == null) return null;
      return StreakSummary(
        current: (res['current'] ?? 0) as int,
        longest: (res['longest'] ?? 0) as int,
        freezeCredits: (res['freeze_credits'] ?? 0) as int,
        gracePiecesTotal: (res['grace_pieces_total'] ?? 0).toDouble(),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS152',
        errorMessage: 'Streak fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'home_summary_fetchStreak',
          'user_id': userId,
        },
      );
      rethrow;
    }
  }

  Future<TodayProgressSummary?> _fetchTodayProgress(
      String userId, DateTime today) async {
    try {
      // Use date-only string to match DATE columns
      final local = DateTime(today.year, today.month, today.day);
      final dateOnly = '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';

      final habits = await _supabase
          .from('habits_daily')
          .select(
              'wrote_entry, filled_affirmations, filled_gratitude, self_care_completed_count, grace_pieces_earned')
          .eq('user_id', userId)
          .eq('date', dateOnly)
          .maybeSingle();

      final entry = await _supabase
          .from('entries')
          .select('id')
          .eq('user_id', userId)
          .eq('entry_date', dateOnly)
          .maybeSingle();

      int waterCups = 0;
      if (entry != null) {
        final meals = await _supabase
            .from('entry_meals')
            .select('water_cups')
            .eq('entry_id', entry['id'] as String)
            .maybeSingle();
        if (meals != null) waterCups = (meals['water_cups'] ?? 0) as int;
      }

      if (habits == null) {
        return TodayProgressSummary(
          wroteEntry: false,
          filledAffirmations: false,
          filledGratitude: false,
          selfCareCompletedCount: 0,
          gracePiecesEarned: 0,
          waterCups: waterCups,
        );
      }

      return TodayProgressSummary(
        wroteEntry: (habits['wrote_entry'] ?? false) as bool,
        filledAffirmations: (habits['filled_affirmations'] ?? false) as bool,
        filledGratitude: (habits['filled_gratitude'] ?? false) as bool,
        selfCareCompletedCount:
            (habits['self_care_completed_count'] ?? 0) as int,
        gracePiecesEarned: (habits['grace_pieces_earned'] ?? 0).toDouble(),
        waterCups: waterCups,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS153',
        errorMessage: 'Today progress fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'home_summary_fetchToday',
          'user_id': userId,
        },
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
      String dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final thisWeek = await _supabase
          .from('weekly_insights')
          .select(
              'mood_avg, cups_avg, self_care_rate, top_topics, highlights')
          .eq('user_id', userId)
          .eq('week_start', dateOnly(thisWeekStart))
          .maybeSingle();

      final prevWeek = await _supabase
          .from('weekly_insights')
          .select('mood_avg')
          .eq('user_id', userId)
          .eq('week_start', dateOnly(prevWeekStart))
          .maybeSingle();

      num? delta;
      if (thisWeek != null && prevWeek != null) {
        final current = thisWeek['mood_avg'] as num?;
        final previous = prevWeek['mood_avg'] as num?;
        if (current != null && previous != null) delta = current - previous;
      }

      if (thisWeek == null) return null;
      return WeeklySnapshotSummary(
        moodAvg: thisWeek['mood_avg'] as num?,
        cupsAvg: thisWeek['cups_avg'] as num?,
        selfCareRate: thisWeek['self_care_rate'] as num?,
        topTopics: thisWeek['top_topics'] as List<dynamic>?,
        highlights: thisWeek['highlights'] as String?,
        moodDelta: delta,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS154',
        errorMessage: 'Weekly snapshot fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'home_summary_fetchWeekly',
          'user_id': userId,
        },
      );
      rethrow;
    }
  }

  Future<PromptMotivationSummary?> _fetchPromptMotivation(String userId) async {
    try {
      final today = DateTime.now();
      final local = DateTime(today.year, today.month, today.day);
      final dateOnly = '${local.year.toString().padLeft(4, '0')}-'
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

      final streak = await _supabase
          .from('streaks')
          .select('freeze_credits')
          .eq('user_id', userId)
          .maybeSingle();
      final freeze = streak != null ? (streak['freeze_credits'] ?? 0) as int : 0;

      final settings = await _supabase
          .from('user_settings')
          .select('reminder_time_local')
          .eq('user_id', userId)
          .maybeSingle();

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
        errorCode: 'ERRSYS155',
        errorMessage: 'Prompt/motivation fetch failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'home_summary_fetchPrompt',
          'user_id': userId,
        },
      );
      rethrow;
    }
  }
}


