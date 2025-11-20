import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/error_logging_service.dart';
import '../models/analytics_models.dart';

class AIService {
  final SupabaseClient _supabase;

  AIService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  /// Fetch yesterday's insight for user
  /// Returns insight for yesterday's entry (in user's timezone or UTC)
  Future<DailyInsight?> getYesterdayInsight(String userId) async {
    try {
      // Calculate yesterday
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('entry_insights')
          .select('''
            id, 
            entry_id,
            summary, 
            insight_text,
            insight_details,
            sentiment_label, 
            sentiment_score,
            topics,
            processed_at, 
            status,
            entries!inner(entry_date, user_id)
          ''')
          .eq('entries.user_id', userId)
          .eq('entries.entry_date', yesterdayStr)
          .eq('status', 'success')
          .maybeSingle();

      if (response == null) return null;

      // Parse insight_details if available
      InsightDetails? insightDetails;
      if (response['insight_details'] != null) {
        try {
          insightDetails = InsightDetails.fromJson(
            response['insight_details'] as Map<String, dynamic>
          );
        } catch (e) {
          // If parsing fails, continue without details
          insightDetails = null;
        }
      }

      return DailyInsight(
        id: response['id'] as String,
        entryId: response['entry_id'] as String,
        insightText: response['summary'] as String? ?? response['insight_text'] as String? ?? '',
        sentimentLabel: response['sentiment_label'] as String?,
        processedAt: DateTime.parse(response['processed_at'] as String),
        insightDetails: insightDetails,
      );
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRAI005',
        errorMessage: 'Failed to fetch yesterday insight: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId, 'operation': 'get_yesterday_insight'},
      );
      return null;
    }
  }

  /// Fetch daily insight for an entry
  Future<DailyInsight?> getDailyInsight(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_insights')
          .select('id, insight_text, summary, insight_details, sentiment_label, processed_at, status')
          .eq('entry_id', entryId)
          .eq('status', 'success')
          .maybeSingle();

      if (response == null) return null;

      // Parse insight_details if available
      InsightDetails? insightDetails;
      if (response['insight_details'] != null) {
        try {
          insightDetails = InsightDetails.fromJson(
            response['insight_details'] as Map<String, dynamic>
          );
        } catch (e) {
          insightDetails = null;
        }
      }

      return DailyInsight(
        id: response['id'] as String,
        entryId: entryId,
        insightText: response['insight_text'] as String? ?? response['summary'] as String? ?? '',
        sentimentLabel: response['sentiment_label'] as String?,
        processedAt: DateTime.parse(response['processed_at'] as String),
        insightDetails: insightDetails,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI005',
        errorMessage: 'Failed to fetch daily insight: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {'entry_id': entryId, 'operation': 'get_daily_insight'},
      );
      return null;
    }
  }

  /// Trigger weekly AI analysis for a user
  Future<void> triggerWeeklyAnalysis(String userId, DateTime weekStart) async {
    try {
      // Format week_start as YYYY-MM-DD
      final weekStartStr = '${weekStart.year.toString().padLeft(4, '0')}-'
          '${weekStart.month.toString().padLeft(2, '0')}-'
          '${weekStart.day.toString().padLeft(2, '0')}';

      // Call Edge Function
      final response = await _supabase.functions.invoke('ai-analyze-weekly', body: {
        'user_id': userId,
        'week_start': weekStartStr,
      });

      if (response.status != 200) {
        throw Exception('Weekly analysis failed: ${response.data}');
      }
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI006',
        errorMessage: 'Failed to trigger weekly analysis: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'week_start': weekStart.toIso8601String(),
          'operation': 'trigger_weekly_analysis',
        },
      );
      rethrow;
    }
  }

  /// Fetch weekly insight for a user
  Future<WeeklyInsight?> getWeeklyInsight(String userId, DateTime weekStart) async {
    try {
      final weekStartStr = '${weekStart.year.toString().padLeft(4, '0')}-'
          '${weekStart.month.toString().padLeft(2, '0')}-'
          '${weekStart.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('weekly_insights')
          .select('*')
          .eq('user_id', userId)
          .eq('week_start', weekStartStr)
          .eq('status', 'success')
          .maybeSingle();

      if (response == null) return null;

      return WeeklyInsight(
        id: response['id'] as String,
        userId: userId,
        weekStart: weekStart,
        moodAvg: (response['mood_avg'] as num?)?.toDouble(),
        cupsAvg: (response['cups_avg'] as num?)?.toDouble(),
        selfCareRate: (response['self_care_rate'] as num?)?.toDouble(),
        topTopics: (response['top_topics'] as List<dynamic>?)?.cast<String>() ?? [],
        highlights: response['highlights'] as String? ?? '',
        keyInsights: (response['key_insights'] as List<dynamic>?)?.cast<String>() ?? [],
        recommendations: (response['recommendations'] as List<dynamic>?)?.cast<String>() ?? [],
        moodTrend: response['mood_trend'] as String?,
        consistencyScore: (response['consistency_score'] as num?)?.toDouble(),
        entriesCount: response['entries_count'] as int? ?? 0,
        wordCountTotal: response['word_count_total'] as int? ?? 0,
        generatedAt: DateTime.parse(response['generated_at'] as String),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI007',
        errorMessage: 'Failed to fetch weekly insight: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'user_id': userId,
          'week_start': weekStart.toIso8601String(),
          'operation': 'get_weekly_insight',
        },
      );
      return null;
    }
  }

  /// Fetch recent insights for carousel display (last 7 insights)
  Future<List<DailyInsightWithDate>> getRecentInsights(
    String userId, {
    int limit = 7,
  }) async {
    try {
      final response = await _supabase
          .from('entry_insights')
          .select('''
            id,
            entry_id,
            insight_text,
            summary,
            sentiment_label,
            processed_at,
            entries!inner(
              entry_date,
              user_id,
              mood_score
            )
          ''')
          .eq('entries.user_id', userId)
          .eq('status', 'success')
          .not('insight_text', 'is', null)
          .order('processed_at', ascending: false)
          .limit(limit);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => DailyInsightWithDate.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI009',
        errorMessage: 'Failed to fetch recent insights: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {'user_id': userId, 'limit': limit, 'operation': 'get_recent_insights'},
      );
      return [];
    }
  }

  /// Fetch daily insights timeline for a period
  Future<List<DailyInsightWithMood>> getDailyInsightsTimeline(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startStr = '${startDate.year.toString().padLeft(4, '0')}-'
          '${startDate.month.toString().padLeft(2, '0')}-'
          '${startDate.day.toString().padLeft(2, '0')}';
      final endStr = '${endDate.year.toString().padLeft(4, '0')}-'
          '${endDate.month.toString().padLeft(2, '0')}-'
          '${endDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('entry_insights')
          .select('''
            id,
            entry_id,
            insight_text,
            summary,
            sentiment_label,
            processed_at,
            entries!inner(
              entry_date,
              user_id,
              mood_score
            )
          ''')
          .eq('entries.user_id', userId)
          .gte('entries.entry_date', startStr)
          .lte('entries.entry_date', endStr)
          .eq('status', 'success')
          .not('insight_text', 'is', null)
          .order('entries.entry_date', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => DailyInsightWithMood.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI010',
        errorMessage: 'Failed to fetch daily insights timeline: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'user_id': userId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'operation': 'get_daily_insights_timeline',
        },
      );
      return [];
    }
  }

  /// Check entry completion status
  Future<bool> checkEntryCompletion(String entryId) async {
    try {
      final response = await _supabase.rpc(
        'check_entry_completion',
        params: {'entry_uuid': entryId},
      );

      return response as bool? ?? false;
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI011',
        errorMessage: 'Failed to check entry completion: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {'entry_id': entryId, 'operation': 'check_entry_completion'},
      );
      return false;
    }
  }

  /// Get most recent insight (for fallback display)
  Future<DailyInsight?> getMostRecentInsight(String userId) async {
    try {
      final response = await _supabase
          .from('entry_insights')
          .select('id, entry_id, insight_text, summary, sentiment_label, processed_at, status')
          .eq('status', 'success')
          .not('insight_text', 'is', null)
          .order('processed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Verify it belongs to the user
      final entryResponse = await _supabase
          .from('entries')
          .select('user_id')
          .eq('id', response['entry_id'] as String)
          .maybeSingle();

      if (entryResponse == null || entryResponse['user_id'] != userId) {
        return null;
      }

      return DailyInsight(
        id: response['id'] as String,
        entryId: response['entry_id'] as String,
        insightText: response['insight_text'] as String? ?? response['summary'] as String? ?? '',
        sentimentLabel: response['sentiment_label'] as String?,
        processedAt: DateTime.parse(response['processed_at'] as String),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI012',
        errorMessage: 'Failed to get most recent insight: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {'user_id': userId, 'operation': 'get_most_recent_insight'},
      );
      return null;
    }
  }

  /// Fetch monthly insight for user
  /// Returns insight for a specific month
  Future<MonthlyInsight?> getMonthlyInsight(String userId, DateTime monthStart) async {
    try {
      final monthStartStr = '${monthStart.year.toString().padLeft(4, '0')}-'
          '${monthStart.month.toString().padLeft(2, '0')}-'
          '${monthStart.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('monthly_insights')
          .select('*')
          .eq('user_id', userId)
          .eq('month_start', monthStartStr)
          .eq('status', 'success')
          .maybeSingle();

      if (response == null) return null;

      return MonthlyInsight(
        id: response['id'] as String,
        userId: userId,
        monthStart: monthStart,
        moodAvg: (response['mood_avg'] as num?)?.toDouble(),
        entriesCount: response['entries_count'] as int? ?? 0,
        wordCountTotal: response['word_count_total'] as int? ?? 0,
        topTopics: (response['top_topics'] as List<dynamic>?)?.cast<String>() ?? [],
        monthlyHighlights: response['monthly_highlights'] as String? ?? '',
        growthAreas: (response['growth_areas'] as List<dynamic>?)?.cast<String>() ?? [],
        achievements: (response['achievements'] as List<dynamic>?)?.cast<String>() ?? [],
        nextMonthGoals: (response['next_month_goals'] as List<dynamic>?)?.cast<String>() ?? [],
        consistencyScore: (response['consistency_score'] as num?)?.toDouble(),
        moodTrendMonthly: response['mood_trend_monthly'] as String?,
        generatedAt: DateTime.parse(response['generated_at'] as String),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRAI013',
        errorMessage: 'Failed to fetch monthly insight: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'user_id': userId,
          'month_start': monthStart.toIso8601String(),
          'operation': 'get_monthly_insight',
        },
      );
      return null;
    }
  }
}

/// Model for weekly insight
class WeeklyInsight {
  final String id;
  final String userId;
  final DateTime weekStart;
  final double? moodAvg;
  final double? cupsAvg;
  final double? selfCareRate;
  final List<String> topTopics;
  final String highlights;
  final List<String> keyInsights;
  final List<String> recommendations;
  final String? moodTrend;
  final double? consistencyScore;
  final int entriesCount;
  final int wordCountTotal;
  final DateTime generatedAt;

  WeeklyInsight({
    required this.id,
    required this.userId,
    required this.weekStart,
    this.moodAvg,
    this.cupsAvg,
    this.selfCareRate,
    this.topTopics = const [],
    required this.highlights,
    required this.keyInsights,
    required this.recommendations,
    this.moodTrend,
    this.consistencyScore,
    this.entriesCount = 0,
    this.wordCountTotal = 0,
    required this.generatedAt,
  });
}

/// Model for monthly insight
class MonthlyInsight {
  final String id;
  final String userId;
  final DateTime monthStart;
  final double? moodAvg;
  final int entriesCount;
  final int wordCountTotal;
  final List<String> topTopics;
  final String monthlyHighlights;
  final List<String> growthAreas;
  final List<String> achievements;
  final List<String> nextMonthGoals;
  final double? consistencyScore;
  final String? moodTrendMonthly;
  final DateTime generatedAt;

  MonthlyInsight({
    required this.id,
    required this.userId,
    required this.monthStart,
    this.moodAvg,
    required this.entriesCount,
    required this.wordCountTotal,
    required this.topTopics,
    required this.monthlyHighlights,
    required this.growthAreas,
    required this.achievements,
    required this.nextMonthGoals,
    this.consistencyScore,
    this.moodTrendMonthly,
    required this.generatedAt,
  });
}

