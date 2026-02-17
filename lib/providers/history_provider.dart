import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/history_entry_model.dart';
import '../models/error_models.dart';
import '../services/history_service.dart';
import '../services/error_logging_service.dart';
import 'data_providers.dart';

class HistoryState {
  final List<HistoryEntry> entries;
  final Set<String> loadedMonths; // e.g., "2024-01"
  final Set<String> loadedMoodEntries; // e.g., "mood_1", "mood_2"
  final Map<String, int> moodFilterPagination; // "mood_1" -> offset
  final bool isLoadingMoodFilter;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Map<String, int> moodMap; // date string -> mood (1-5)
  final List<String> monthsWithEntries; // All months that have entries (for Load More button)

  HistoryState({
    this.entries = const [],
    this.loadedMonths = const {},
    this.loadedMoodEntries = const {},
    this.moodFilterPagination = const {},
    this.isLoadingMoodFilter = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    Map<String, int>? moodMap,
    this.monthsWithEntries = const [],
  }) : moodMap = moodMap ?? {};

  HistoryState copyWith({
    List<HistoryEntry>? entries,
    Set<String>? loadedMonths,
    Set<String>? loadedMoodEntries,
    Map<String, int>? moodFilterPagination,
    bool? isLoadingMoodFilter,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Map<String, int>? moodMap,
    List<String>? monthsWithEntries,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      loadedMonths: loadedMonths ?? this.loadedMonths,
      loadedMoodEntries: loadedMoodEntries ?? this.loadedMoodEntries,
      moodFilterPagination: moodFilterPagination ?? this.moodFilterPagination,
      isLoadingMoodFilter: isLoadingMoodFilter ?? this.isLoadingMoodFilter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      moodMap: moodMap ?? this.moodMap,
      monthsWithEntries: monthsWithEntries ?? this.monthsWithEntries,
    );
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  late final HistoryService _service;
  
  @override
  HistoryState build() {
    final dataFetchService = ref.read(dataFetchServiceProvider);
    _service = HistoryService(dataFetchService: dataFetchService);
    return HistoryState();
  }


  /// Load current month on init
  /// Loads 2 months initially (current + previous) with full data
  /// Also loads months with entries list for Load More button
  Future<void> loadCurrentMonth() async {
    final userId = _getUserId();
    if (userId == null) {
      state = state.copyWith(
        error: 'User not authenticated',
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);
      final previousMonth = DateTime(now.year, now.month - 1, 1);
      
      final loadedMonthsSet = <String>{};
      final allEntries = <HistoryEntry>[];
      final allMoodMap = <String, int>{};

      // Load 2 months initially (current + previous) in parallel
      final results = await Future.wait([
        _service.getEntriesForMonth(userId, currentMonth),
        _service.getEntriesForMonth(userId, previousMonth),
        _service.getMonthsWithEntries(userId), // Get all months with entries for Load More button
      ]);

      final currentMonthEntries = results[0] as List<HistoryEntry>;
      final previousMonthEntries = results[1] as List<HistoryEntry>;
      final monthsWithEntries = results[2] as List<String>;

      // Add current month entries
      if (currentMonthEntries.isNotEmpty) {
        allEntries.addAll(currentMonthEntries);
        final currentMonthKey = DateFormat('yyyy-MM').format(currentMonth);
        loadedMonthsSet.add(currentMonthKey);
        final moodMap = _buildMoodMap(currentMonthEntries);
        allMoodMap.addAll(moodMap);
      }

      // Add previous month entries
      if (previousMonthEntries.isNotEmpty) {
        allEntries.addAll(previousMonthEntries);
        final previousMonthKey = DateFormat('yyyy-MM').format(previousMonth);
        loadedMonthsSet.add(previousMonthKey);
        final moodMap = _buildMoodMap(previousMonthEntries);
        allMoodMap.addAll(moodMap);
      }

      // Sort all entries by date (newest first)
      allEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));

      state = state.copyWith(
        entries: allEntries,
        loadedMonths: loadedMonthsSet,
        isLoading: false,
        moodMap: {...state.moodMap, ...allMoodMap},
        monthsWithEntries: monthsWithEntries,
        loadedMoodEntries: {},
        moodFilterPagination: {},
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST005',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId},
        ),
      );

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load entries: ${e.toString()}',
      );
    }
  }

  /// Load calendar mood data (lightweight - only date + mood)
  /// Fetches ALL mood data from Supabase (no date limit) for calendar view
  Future<void> loadCalendarMoodData() async {
    final userId = _getUserId();
    if (userId == null) return;

    try {
      // Fetch all mood data (no date limit)
      final calendarMoodMap = await _service.getMoodMapForDateRange(
        userId,
        null, // No start date - fetch all
        null, // No end date - fetch all
      );

      // Merge with existing mood map (calendar data takes precedence for dates)
      final mergedMoodMap = <String, int>{
        ...state.moodMap,
        ...calendarMoodMap,
      };

      state = state.copyWith(moodMap: mergedMoodMap);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
          errorCode: 'ERRHIST010',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId},
        ),
      );
      // Don't update state on error - use existing mood map
    }
  }

  /// Load previous month (pagination)
  Future<void> loadPreviousMonth(String monthKey) async {
    debugPrint('HISTORY DEBUG: loadPreviousMonth START monthKey=$monthKey');
    final userId = _getUserId();
    if (userId == null) {
      debugPrint('HISTORY DEBUG: loadPreviousMonth EXIT - userId null');
      state = state.copyWith(
        error: 'User not authenticated',
        isLoadingMore: false,
      );
      return;
    }

    // Check if already loaded
    if (state.loadedMonths.contains(monthKey)) {
      debugPrint('HISTORY DEBUG: loadPreviousMonth EXIT - month already loaded');
      return;
    }

    // Parse monthKey (e.g., "2024-01")
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      state = state.copyWith(
        error: 'Invalid month key format',
        isLoadingMore: false,
      );
      return;
    }

    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);

    state = state.copyWith(isLoadingMore: true);
    debugPrint('HISTORY DEBUG: loadPreviousMonth fetching month=$monthKey');

    try {
      final entries = await _service.getEntriesForMonth(userId, month);
      debugPrint('HISTORY DEBUG: loadPreviousMonth fetched ${entries.length} entries');
      final newMoodMap = _buildMoodMap(entries);

      state = state.copyWith(
        entries: [...state.entries, ...entries],
        loadedMonths: {...state.loadedMonths, monthKey},
        isLoadingMore: false,
        moodMap: {...state.moodMap, ...newMoodMap},
      );
      debugPrint(
        'HISTORY DEBUG: loadPreviousMonth SUCCESS totalEntries=${state.entries.length}',
      );
    } catch (e) {
      debugPrint('HISTORY DEBUG: loadPreviousMonth ERROR: $e');
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST006',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'month_key': monthKey,
          },
        ),
      );

      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load month: ${e.toString()}',
      );
    }
  }

  /// Refresh current month
  Future<void> refresh() async {
    await loadCurrentMonth();
  }

  /// Get entry by date (for calendar tap)
  Future<HistoryEntry?> getEntryByDate(DateTime date) async {
    final userId = _getUserId();
    if (userId == null) return null;

    try {
      return await _service.getEntryByDate(userId, date);
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST007',
          severity: ErrorSeverity.low,
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

  /// Load entries for a specific mood when filter is applied
  ///
  /// Skips last 2 months (already loaded). Fetches from older months with pagination.
  Future<void> loadMoodFilteredEntries(int moodScore) async {
    debugPrint('HISTORY DEBUG: loadMoodFilteredEntries START moodScore=$moodScore');
    final userId = _getUserId();
    if (userId == null) {
      debugPrint('HISTORY DEBUG: loadMoodFilteredEntries EXIT - userId null');
      return;
    }

    if (state.isLoadingMoodFilter) {
      debugPrint('HISTORY DEBUG: loadMoodFilteredEntries EXIT - already loading');
      return;
    }

    if (state.loadedMoodEntries.contains('mood_$moodScore')) {
      debugPrint('HISTORY DEBUG: loadMoodFilteredEntries EXIT - mood already loaded');
      return;
    }

    final totalCount =
        state.moodMap.values.where((m) => m == moodScore).length;
    final loadedCount = state.entries
        .where((e) => e.entry.moodScore == moodScore)
        .length;

    debugPrint(
      'HISTORY DEBUG: loadMoodFilteredEntries totalCount=$totalCount '
      'loadedCount=$loadedCount moodMap.size=${state.moodMap.length}',
    );

    if (loadedCount >= totalCount) {
      debugPrint('HISTORY DEBUG: loadMoodFilteredEntries EXIT - loadedCount>=totalCount');
      return;
    }

    state = state.copyWith(isLoadingMoodFilter: true, error: null);
    debugPrint('HISTORY DEBUG: loadMoodFilteredEntries set isLoadingMoodFilter=true');

    try {
      final now = DateTime.now();
      // Skip last 2 loaded months (current + previous). Use first day of previous month.
      // DateTime(2026, 0, 1) auto-rolls to Dec 1, 2025 for January.
      final skipUntilDate = DateTime(now.year, now.month - 1, 1);

      const limit = 30;
      final currentOffset =
          state.moodFilterPagination['mood_$moodScore'] ?? 0;

      debugPrint(
        'HISTORY DEBUG: loadMoodFilteredEntries skipUntilDate=$skipUntilDate '
        'currentOffset=$currentOffset limit=$limit',
      );

      final fetchedEntries = await _service.getEntriesByMood(
        userId: userId,
        moodScore: moodScore,
        startDate: null,
        endDate: skipUntilDate,
        limit: limit,
        offset: currentOffset,
      );

      debugPrint(
        'HISTORY DEBUG: loadMoodFilteredEntries fetched ${fetchedEntries.length} entries',
      );

      final existingIds = state.entries.map((e) => e.entry.id).toSet();
      final newEntries = fetchedEntries
          .where((e) => !existingIds.contains(e.entry.id))
          .toList();

      debugPrint(
        'HISTORY DEBUG: loadMoodFilteredEntries newEntries=${newEntries.length} '
        'existingIds=${existingIds.length}',
      );

      final allEntries = [...state.entries, ...newEntries];
      allEntries.sort(
        (a, b) => b.entry.entryDate.compareTo(a.entry.entryDate),
      );

      final updatedLoadedCount = allEntries
          .where((e) => e.entry.moodScore == moodScore)
          .length;
      final isFullyLoaded =
          fetchedEntries.length < limit || updatedLoadedCount >= totalCount;

      final updatedLoadedMoodEntries = {...state.loadedMoodEntries};
      final updatedPagination = {...state.moodFilterPagination};

      if (isFullyLoaded) {
        updatedLoadedMoodEntries.add('mood_$moodScore');
      } else {
        updatedPagination['mood_$moodScore'] = currentOffset + limit;
      }

      final newMoodMap = _buildMoodMap(newEntries);

      debugPrint(
        'HISTORY DEBUG: loadMoodFilteredEntries SUCCESS allEntries=${allEntries.length} '
        'isFullyLoaded=$isFullyLoaded updatedLoadedCount=$updatedLoadedCount',
      );

      state = state.copyWith(
        entries: allEntries,
        loadedMoodEntries: updatedLoadedMoodEntries,
        moodFilterPagination: updatedPagination,
        isLoadingMoodFilter: false,
        moodMap: {...state.moodMap, ...newMoodMap},
      );
    } catch (e) {
      debugPrint('HISTORY DEBUG: loadMoodFilteredEntries ERROR: $e');
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST012',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'mood_score': moodScore,
          },
        ),
      );

      state = state.copyWith(
        isLoadingMoodFilter: false,
        error: 'Failed to load entries: ${e.toString()}',
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Helper: Build mood map for calendar
  /// Defaults mood to 3 if NULL (consistent with card display)
  Map<String, int> _buildMoodMap(List<HistoryEntry> entries) {
    final map = <String, int>{};
    for (var entry in entries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.entry.entryDate);
      // Default mood to 3 if NULL (consistent with card display)
      map[dateStr] = entry.entry.moodScore ?? 3;
    }
    return map;
  }

  String? _getUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  () => HistoryNotifier(),
);

