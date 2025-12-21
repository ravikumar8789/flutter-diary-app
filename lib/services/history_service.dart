import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry_models.dart';
import '../models/history_entry_model.dart';
import '../models/analytics_models.dart';
import 'error_logging_service.dart';

class HistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch entries for a month with all related data using JOIN query
  Future<List<HistoryEntry>> getEntriesForMonth(
    String userId,
    DateTime month, // First day of month
  ) async {
    try {
      // 1. Calculate month start/end dates
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0);
      final startDateStr = DateFormat('yyyy-MM-dd').format(monthStart);
      final endDateStr = DateFormat('yyyy-MM-dd').format(monthEnd);

      // 2. Fetch entries with all related data using JOIN query (single call)
      final response = await _supabase
          .from('entries')
          .select('''
            *,
            entry_self_care(*),
            entry_meals(*),
            entry_affirmations(*),
            entry_gratitude(*),
            entry_priorities(*),
            entry_tomorrow_notes(*)
          ''')
          .eq('user_id', userId)
          .gte('entry_date', startDateStr)
          .lte('entry_date', endDateStr)
          .order('entry_date', ascending: false);

      if (response.isEmpty) return [];

      // 3. Parse entries with nested related data (no insights - fetch on-demand)
      final historyEntries = <HistoryEntry>[];
      for (var row in response) {
        final entry = Entry.fromSupabaseJson(row);

        // Parse nested related data from JOIN response
        final selfCare = row['entry_self_care'] != null
            ? EntrySelfCare.fromSupabaseJson(
                row['entry_self_care'] as Map<String, dynamic>)
            : null;

        final meals = row['entry_meals'] != null
            ? EntryMeals.fromSupabaseJson(
                row['entry_meals'] as Map<String, dynamic>)
            : null;

        final affirmations = row['entry_affirmations'] != null
            ? EntryAffirmations.fromSupabaseJson(
                row['entry_affirmations'] as Map<String, dynamic>)
            : null;

        final gratitude = row['entry_gratitude'] != null
            ? EntryGratitude.fromSupabaseJson(
                row['entry_gratitude'] as Map<String, dynamic>)
            : null;

        final priorities = row['entry_priorities'] != null
            ? EntryPriorities.fromSupabaseJson(
                row['entry_priorities'] as Map<String, dynamic>)
            : null;

        final tomorrowNotes = row['entry_tomorrow_notes'] != null
            ? EntryTomorrowNotes.fromSupabaseJson(
                row['entry_tomorrow_notes'] as Map<String, dynamic>)
            : null;

        // Build history entry without insight (fetch on-demand)
        historyEntries.add(HistoryEntry(
          entry: entry,
          insight: null, // Fetch on-demand when user clicks
          selfCare: selfCare,
          meals: meals,
          affirmations: affirmations,
          gratitude: gratitude,
          priorities: priorities,
          tomorrowNotes: tomorrowNotes,
        ));
      }

      // 4. Sort by date (newest first)
      historyEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));

      return historyEntries;
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRHIST001',
        errorMessage: 'Failed to fetch entries for month: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'month': DateFormat('yyyy-MM').format(month),
        },
      );
      return [];
    }
  }

  /// Fetch entry with full details by date (for bottom sheet) using JOIN query
  Future<HistoryEntry?> getEntryByDate(
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // 1. Fetch entry with all related data using JOIN query (single call)
      final response = await _supabase
          .from('entries')
          .select('''
            *,
            entry_self_care(*),
            entry_meals(*),
            entry_affirmations(*),
            entry_gratitude(*),
            entry_priorities(*),
            entry_tomorrow_notes(*)
          ''')
          .eq('user_id', userId)
          .eq('entry_date', dateStr)
          .maybeSingle();

      if (response == null) return null;

      // 2. Parse entry with nested related data
      final entry = Entry.fromSupabaseJson(response);

      final selfCare = response['entry_self_care'] != null
          ? EntrySelfCare.fromSupabaseJson(
              response['entry_self_care'] as Map<String, dynamic>)
          : null;

      final meals = response['entry_meals'] != null
          ? EntryMeals.fromSupabaseJson(
              response['entry_meals'] as Map<String, dynamic>)
          : null;

      final affirmations = response['entry_affirmations'] != null
          ? EntryAffirmations.fromSupabaseJson(
              response['entry_affirmations'] as Map<String, dynamic>)
          : null;

      final gratitude = response['entry_gratitude'] != null
          ? EntryGratitude.fromSupabaseJson(
              response['entry_gratitude'] as Map<String, dynamic>)
          : null;

      final priorities = response['entry_priorities'] != null
          ? EntryPriorities.fromSupabaseJson(
              response['entry_priorities'] as Map<String, dynamic>)
          : null;

      final tomorrowNotes = response['entry_tomorrow_notes'] != null
          ? EntryTomorrowNotes.fromSupabaseJson(
              response['entry_tomorrow_notes'] as Map<String, dynamic>)
          : null;

      // 3. Don't fetch insight here - fetch on-demand when user expands card
      return HistoryEntry(
        entry: entry,
        insight: null, // Fetch on-demand when user expands
        selfCare: selfCare,
        meals: meals,
        affirmations: affirmations,
        gratitude: gratitude,
        priorities: priorities,
        tomorrowNotes: tomorrowNotes,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRHIST002',
        errorMessage: 'Failed to fetch entry by date: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'date': DateFormat('yyyy-MM-dd').format(date),
        },
      );
      return null;
    }
  }


  /// Fetch insight for a specific entry (public method for on-demand fetching)
  Future<HistoryDailyInsight?> fetchInsightForEntry(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_insights')
          .select('''
            id,
            entry_id,
            insight_text,
            summary,
            sentiment_label,
            topics,
            insight_details,
            processed_at,
            status
          ''')
          .eq('entry_id', entryId)
          .eq('status', 'success')
          .maybeSingle();

      if (response == null) return null;

      // Parse insight_details
      InsightDetails? insightDetails;
      if (response['insight_details'] != null) {
        try {
          insightDetails = InsightDetails.fromJson(
            response['insight_details'] as Map<String, dynamic>,
          );
        } catch (e) {
          insightDetails = null;
        }
      }

      // Parse topics
      final topics = List<String>.from(response['topics'] as List? ?? []);

      return HistoryDailyInsight(
        id: response['id'] as String,
        entryId: entryId,
        insightText: response['insight_text'] as String? ?? response['summary'] as String? ?? '',
        sentimentLabel: response['sentiment_label'] as String?,
        processedAt: DateTime.parse(response['processed_at'] as String),
        insightDetails: insightDetails,
        topics: topics,
        status: response['status'] as String? ?? 'success',
      );
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRHIST004',
        errorMessage: 'Failed to fetch insight for entry: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'entry_id': entryId},
      );
      return null;
    }
  }


  /// Get mood map for date range (lightweight - only date + mood)
  /// Used for calendar view to show mood indicators without loading full entries
  /// Fetches from Supabase - no date limit (fetches all mood data)
  Future<Map<String, int>> getMoodMapForDateRange(
    String userId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      var query = _supabase
          .from('entries')
          .select('entry_date, mood_score')
          .eq('user_id', userId);

      // Apply date filters if provided (for calendar view, fetch all if not provided)
      if (startDate != null) {
        final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
        query = query.gte('entry_date', startDateStr);
      }
      if (endDate != null) {
        final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
        query = query.lte('entry_date', endDateStr);
      }

      final response = await query;

      final moodMap = <String, int>{};
      for (var row in response) {
        final dateStr = row['entry_date'] as String;
        // Default mood to 3 if NULL (consistent with card display)
        final moodScore = row['mood_score'] as int? ?? 3;
        moodMap[dateStr] = moodScore;
      }

      return moodMap;
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRHIST008',
        errorMessage: 'Failed to get mood map for date range: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : 'all',
          'end_date': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : 'all',
        },
      );
      return {};
    }
  }

  /// Get list of months that have entries (for Load More button)
  /// Returns list of month keys (e.g., ["2024-01", "2024-02"]) sorted oldest first
  Future<List<String>> getMonthsWithEntries(String userId) async {
    try {
      // Fetch all entry dates from Supabase
      final response = await _supabase
          .from('entries')
          .select('entry_date')
          .eq('user_id', userId)
          .order('entry_date', ascending: true);

      // Extract unique months
      final months = <String>{};
      for (var row in response) {
        final dateStr = row['entry_date'] as String;
        final date = DateTime.parse(dateStr);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        months.add(monthKey);
      }

      return months.toList()..sort();
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRHIST009',
        errorMessage: 'Failed to get months with entries: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId},
      );
      return [];
    }
  }
}

