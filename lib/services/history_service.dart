import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry_models.dart';
import '../models/history_entry_model.dart';
import '../models/analytics_models.dart';
import 'database/local_entry_service.dart';
import 'error_logging_service.dart';

class HistoryService {
  final LocalEntryService _localService = LocalEntryService();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch entries for a month with all related data
  Future<List<HistoryEntry>> getEntriesForMonth(
    String userId,
    DateTime month, // First day of month
  ) async {
    try {
      // 1. Calculate month start/end dates
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0);

      // 2. Fetch entries from local database
      final entries = await _localService.getEntriesInRange(
        userId,
        monthStart,
        monthEnd,
      );

      if (entries.isEmpty) return [];

      // 3. Fetch insights for the date range (from Supabase)
      final insightsMap = await _fetchInsightsForMonth(userId, monthStart, monthEnd);

      // 4. Fetch related data for all entries in parallel
      final historyEntries = await Future.wait(
        entries.map((entry) => _buildHistoryEntry(entry, insightsMap[entry.id])),
      );

      // 5. Sort by date (newest first)
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

  /// Fetch entry with full details by date (for bottom sheet)
  Future<HistoryEntry?> getEntryByDate(
    String userId,
    DateTime date,
  ) async {
    try {
      // 1. Fetch entry from local database
      final entry = await _localService.getEntryByDate(userId, date);
      if (entry == null) return null;

      // 2. Fetch insight for this entry
      final insight = await _fetchInsightForEntry(entry.id);

      // 3. Build complete history entry
      return await _buildHistoryEntry(entry, insight);
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

  /// Fetch insights for a month and return as map (entry_id -> insight)
  Future<Map<String, HistoryDailyInsight>> _fetchInsightsForMonth(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Get entry IDs first
      final entryIds = await _getEntryIdsInRange(userId, startDate, endDate);
      if (entryIds.isEmpty) return {};

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
          .eq('status', 'success')
          .not('insight_text', 'is', null)
          .inFilter('entry_id', entryIds);

      if (response.isEmpty) return {};

      final insightsMap = <String, HistoryDailyInsight>{};
      for (var item in response) {
        final entryId = item['entry_id'] as String;
        
        // Parse insight_details
        InsightDetails? insightDetails;
        if (item['insight_details'] != null) {
          try {
            insightDetails = InsightDetails.fromJson(
              item['insight_details'] as Map<String, dynamic>,
            );
          } catch (e) {
            // Continue without details if parsing fails
            insightDetails = null;
          }
        }

        // Parse topics
        final topics = List<String>.from(item['topics'] as List? ?? []);

        final insight = HistoryDailyInsight(
          id: item['id'] as String,
          entryId: entryId,
          insightText: item['insight_text'] as String? ?? item['summary'] as String? ?? '',
          sentimentLabel: item['sentiment_label'] as String?,
          processedAt: DateTime.parse(item['processed_at'] as String),
          insightDetails: insightDetails,
          topics: topics,
          status: item['status'] as String? ?? 'success',
        );

        insightsMap[entryId] = insight;
      }

      return insightsMap;
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRHIST003',
        errorMessage: 'Failed to fetch insights for month: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': DateFormat('yyyy-MM-dd').format(startDate),
          'end_date': DateFormat('yyyy-MM-dd').format(endDate),
        },
      );
      return {};
    }
  }

  /// Fetch insight for a specific entry
  Future<HistoryDailyInsight?> _fetchInsightForEntry(String entryId) async {
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

  /// Get entry IDs in date range (helper for insights query)
  Future<List<String>> _getEntryIdsInRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final entries = await _localService.getEntriesInRange(userId, startDate, endDate);
    return entries.map((e) => e.id).toList();
  }

  /// Build HistoryEntry from Entry and related data
  Future<HistoryEntry> _buildHistoryEntry(
    Entry entry,
    HistoryDailyInsight? insight,
  ) async {
    // Fetch all related data in parallel
    final results = await Future.wait([
      _localService.getSelfCare(entry.id),
      _localService.getMeals(entry.id),
      _localService.getAffirmations(entry.id),
      _localService.getGratitude(entry.id),
      _localService.getPriorities(entry.id),
      _localService.getTomorrowNotes(entry.id),
    ]);

    return HistoryEntry(
      entry: entry,
      insight: insight,
      selfCare: results[0] as EntrySelfCare?,
      meals: results[1] as EntryMeals?,
      affirmations: results[2] as EntryAffirmations?,
      gratitude: results[3] as EntryGratitude?,
      priorities: results[4] as EntryPriorities?,
      tomorrowNotes: results[5] as EntryTomorrowNotes?,
    );
  }

  /// Get mood map for date range (lightweight - only date + mood)
  /// Used for calendar view to show mood indicators without loading full entries
  Future<Map<String, int>> getMoodMapForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _localService.getMoodMapForDateRange(userId, startDate, endDate);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRHIST008',
        errorMessage: 'Failed to get mood map for date range: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'start_date': DateFormat('yyyy-MM-dd').format(startDate),
          'end_date': DateFormat('yyyy-MM-dd').format(endDate),
        },
      );
      return {};
    }
  }

  /// Get list of months that have entries (for Load More button)
  /// Returns list of month keys (e.g., ["2024-01", "2024-02"]) sorted oldest first
  Future<List<String>> getMonthsWithEntries(String userId) async {
    try {
      return await _localService.getMonthsWithEntries(userId);
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

