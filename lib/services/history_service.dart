import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry_models.dart';
import '../models/history_entry_model.dart';
import '../models/analytics_models.dart';
import 'connectivity_service.dart';
import 'entry_insight_storage_helper.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'data_fetch_service.dart';

class HistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DataFetchService? _dataFetchService;

  HistoryService({DataFetchService? dataFetchService})
    : _dataFetchService = dataFetchService;

  /// Fetch entries for a month with all related data using JOIN query
  /// [useLocalOnly] when true, reads from local SQLite only (no Supabase).
  Future<List<HistoryEntry>> getEntriesForMonth(
    String userId,
    DateTime month, {
    bool useLocalOnly = false,
  }) async {
    try {
      // 1. Calculate month start/end dates
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0);
      final startDateStr = DateFormat('yyyy-MM-dd').format(monthStart);
      final endDateStr = DateFormat('yyyy-MM-dd').format(monthEnd);

      // 2. Fetch entries with all related data using JOIN query (single call)
      List<Map<String, dynamic>> response;

      if (_dataFetchService != null) {
        response = await _dataFetchService.fetchEntriesWithJoins(
          userId: userId,
          startDate: monthStart,
          endDate: monthEnd,
          useLocalOnly: useLocalOnly,
        );
      } else if (!useLocalOnly) {
        // Fallback to direct Supabase query when DataFetchService not available
        final queryResponse = await _supabase
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
        response = List<Map<String, dynamic>>.from(queryResponse);
      } else {
        // useLocalOnly but no DataFetchService - cannot read local
        return [];
      }

      if (response.isEmpty) return [];

      // 3. Parse entries with nested related data (no insights - fetch on-demand)
      final historyEntries = <HistoryEntry>[];
      for (var row in response) {
        final entry = Entry.fromSupabaseJson(row);

        // Parse nested related data from JOIN response
        final selfCare = row['entry_self_care'] != null
            ? EntrySelfCare.fromSupabaseJson(
                row['entry_self_care'] as Map<String, dynamic>,
              )
            : null;

        final meals = row['entry_meals'] != null
            ? EntryMeals.fromSupabaseJson(
                row['entry_meals'] as Map<String, dynamic>,
              )
            : null;

        final affirmations = row['entry_affirmations'] != null
            ? EntryAffirmations.fromSupabaseJson(
                row['entry_affirmations'] as Map<String, dynamic>,
              )
            : null;

        final gratitude = row['entry_gratitude'] != null
            ? EntryGratitude.fromSupabaseJson(
                row['entry_gratitude'] as Map<String, dynamic>,
              )
            : null;

        final priorities = row['entry_priorities'] != null
            ? EntryPriorities.fromSupabaseJson(
                row['entry_priorities'] as Map<String, dynamic>,
              )
            : null;

        final tomorrowNotes = row['entry_tomorrow_notes'] != null
            ? EntryTomorrowNotes.fromSupabaseJson(
                row['entry_tomorrow_notes'] as Map<String, dynamic>,
              )
            : null;

        // Build history entry without insight (fetch on-demand)
        historyEntries.add(
          HistoryEntry(
            entry: entry,
            insight: null, // Fetch on-demand when user clicks
            selfCare: selfCare,
            meals: meals,
            affirmations: affirmations,
            gratitude: gratitude,
            priorities: priorities,
            tomorrowNotes: tomorrowNotes,
          ),
        );
      }

      // 4. Sort by date (newest first)
      historyEntries.sort(
        (a, b) => b.entry.entryDate.compareTo(a.entry.entryDate),
      );

      return historyEntries;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST001',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'month': DateFormat('yyyy-MM').format(month),
          },
        ),
      );
      return [];
    }
  }

  /// Fetch entry with full details by date (for bottom sheet) using JOIN query
  /// [useLocalOnly] when true, reads from local SQLite only (no Supabase).
  Future<HistoryEntry?> getEntryByDate(
    String userId,
    DateTime date, {
    bool useLocalOnly = false,
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // 1. Fetch entry with all related data using JOIN query (single call)
      Map<String, dynamic>? response;

      if (_dataFetchService != null) {
        final entries = await _dataFetchService.fetchEntriesWithJoins(
          userId: userId,
          startDate: date,
          endDate: date,
          useLocalOnly: useLocalOnly,
        );
        response = entries.isNotEmpty ? entries.first : null;
      } else if (!useLocalOnly) {
        response = await _supabase
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
      } else {
        return null;
      }

      if (response == null) return null;

      // 2. Parse entry with nested related data
      final entry = Entry.fromSupabaseJson(response);

      final selfCare = response['entry_self_care'] != null
          ? EntrySelfCare.fromSupabaseJson(
              response['entry_self_care'] as Map<String, dynamic>,
            )
          : null;

      final meals = response['entry_meals'] != null
          ? EntryMeals.fromSupabaseJson(
              response['entry_meals'] as Map<String, dynamic>,
            )
          : null;

      final affirmations = response['entry_affirmations'] != null
          ? EntryAffirmations.fromSupabaseJson(
              response['entry_affirmations'] as Map<String, dynamic>,
            )
          : null;

      final gratitude = response['entry_gratitude'] != null
          ? EntryGratitude.fromSupabaseJson(
              response['entry_gratitude'] as Map<String, dynamic>,
            )
          : null;

      final priorities = response['entry_priorities'] != null
          ? EntryPriorities.fromSupabaseJson(
              response['entry_priorities'] as Map<String, dynamic>,
            )
          : null;

      final tomorrowNotes = response['entry_tomorrow_notes'] != null
          ? EntryTomorrowNotes.fromSupabaseJson(
              response['entry_tomorrow_notes'] as Map<String, dynamic>,
            )
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
        ErrorContext.fromException(
          errorCode: 'ERRHIST002',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'date': DateFormat('yyyy-MM-dd').format(date),
          },
        ),
      );
      return null;
    }
  }

  /// Fetch insight for a specific entry (local-first, lazy store).
  ///
  /// 1. Check local first. 2. If missing and online, fetch from Supabase and store.
  Future<HistoryDailyInsight?> fetchInsightForEntry(
    String entryId, {
    required String userId,
    required DateTime entryDate,
  }) async {
    try {
      final local = await EntryInsightStorageHelper.getEntryInsightFromLocal(
        entryId,
      );
      if (local != null) return local;

      final isOnline = await ConnectivityService().isOnline();
      if (!isOnline) return null;

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

      final entryDateStr =
          '${entryDate.year.toString().padLeft(4, '0')}-'
          '${entryDate.month.toString().padLeft(2, '0')}-'
          '${entryDate.day.toString().padLeft(2, '0')}';

      await EntryInsightStorageHelper.storeEntryInsightLocal(
        userId,
        entryId,
        entryDateStr,
        Map<String, dynamic>.from(response),
      );

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

      final topics = List<String>.from(response['topics'] as List? ?? []);

      return HistoryDailyInsight(
        id: response['id'] as String,
        entryId: entryId,
        insightText:
            response['insight_text'] as String? ??
            response['summary'] as String? ??
            '',
        sentimentLabel: response['sentiment_label'] as String?,
        processedAt: DateTime.parse(response['processed_at'] as String),
        insightDetails: insightDetails,
        topics: topics,
        status: response['status'] as String? ?? 'success',
      );
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRHIST004',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'entry_id': entryId},
        ),
      );
      return null;
    }
  }

  /// Fetch entries by mood with pagination (for mood filter on History screen)
  ///
  /// Skips last 2 months (already loaded). Fetches from older months.
  Future<List<HistoryEntry>> getEntriesByMood({
    required String userId,
    required int moodScore,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      if (_dataFetchService == null) {
        return [];
      }

      final response = await _dataFetchService.fetchEntriesByMoodWithJoins(
        userId: userId,
        moodScore: moodScore,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        offset: offset,
      );

      if (response.isEmpty) return [];

      final historyEntries = <HistoryEntry>[];
      for (var row in response) {
        final entry = Entry.fromSupabaseJson(row);

        final selfCare = row['entry_self_care'] != null
            ? EntrySelfCare.fromSupabaseJson(
                row['entry_self_care'] as Map<String, dynamic>,
              )
            : null;

        final meals = row['entry_meals'] != null
            ? EntryMeals.fromSupabaseJson(
                row['entry_meals'] as Map<String, dynamic>,
              )
            : null;

        final affirmations = row['entry_affirmations'] != null
            ? EntryAffirmations.fromSupabaseJson(
                row['entry_affirmations'] as Map<String, dynamic>,
              )
            : null;

        final gratitude = row['entry_gratitude'] != null
            ? EntryGratitude.fromSupabaseJson(
                row['entry_gratitude'] as Map<String, dynamic>,
              )
            : null;

        final priorities = row['entry_priorities'] != null
            ? EntryPriorities.fromSupabaseJson(
                row['entry_priorities'] as Map<String, dynamic>,
              )
            : null;

        final tomorrowNotes = row['entry_tomorrow_notes'] != null
            ? EntryTomorrowNotes.fromSupabaseJson(
                row['entry_tomorrow_notes'] as Map<String, dynamic>,
              )
            : null;

        historyEntries.add(
          HistoryEntry(
            entry: entry,
            insight: null,
            selfCare: selfCare,
            meals: meals,
            affirmations: affirmations,
            gratitude: gratitude,
            priorities: priorities,
            tomorrowNotes: tomorrowNotes,
          ),
        );
      }

      historyEntries.sort(
        (a, b) => b.entry.entryDate.compareTo(a.entry.entryDate),
      );

      return historyEntries;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST011',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'mood_score': moodScore,
            'offset': offset,
          },
        ),
      );
      rethrow;
    }
  }

  /// Single fetch for mood map + months with entries (online refresh).
  /// Returns both moodMap and monthsWithEntries from one Supabase call.
  Future<({Map<String, int> moodMap, List<String> monthsWithEntries})?>
      getMoodMapAndMonthsWithEntries(String userId) async {
    try {
      if (_dataFetchService == null) return null;

      final now = DateTime.now();
      final startDate = DateTime(now.year - 10, 1, 1);
      final endDate = now;

      final response = await _dataFetchService.fetchEntriesWithSelect(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        select: 'entry_date, mood_score',
      );

      final moodMap = <String, int>{};
      final months = <String>{};

      for (var row in response) {
        final dateStr = row['entry_date'] as String;
        final moodScore = row['mood_score'] as int? ?? 3;
        moodMap[dateStr] = moodScore;

        final date = DateTime.parse(dateStr);
        months.add(
            '${date.year}-${date.month.toString().padLeft(2, '0')}');
      }

      return (
        moodMap: moodMap,
        monthsWithEntries: months.toList()..sort(),
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST013',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId},
        ),
      );
      return null;
    }
  }
}
