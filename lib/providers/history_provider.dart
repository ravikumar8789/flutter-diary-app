import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/history_entry_model.dart';
import '../models/error_models.dart';
import '../services/history_service.dart';
import '../services/connectivity_service.dart';
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
  /// Offline: local-only. Online: local-first; monthsWithEntries from loadCalendarMoodData
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
      final isOnline = await ConnectivityService().isOnline();
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);
      final previousMonth = DateTime(now.year, now.month - 1, 1);

      final loadedMonthsSet = <String>{};
      final allEntries = <HistoryEntry>[];
      final allMoodMap = <String, int>{};

      // Load 2 months (current + previous)
      final currentMonthEntries = await _service.getEntriesForMonth(
        userId,
        currentMonth,
        useLocalOnly: !isOnline,
      );
      final previousMonthEntries = await _service.getEntriesForMonth(
        userId,
        previousMonth,
        useLocalOnly: !isOnline,
      );

      // Add current month entries
      if (currentMonthEntries.isNotEmpty) {
        allEntries.addAll(currentMonthEntries);
        loadedMonthsSet.add(DateFormat('yyyy-MM').format(currentMonth));
        allMoodMap.addAll(_buildMoodMap(currentMonthEntries));
      }

      // Add previous month entries
      if (previousMonthEntries.isNotEmpty) {
        allEntries.addAll(previousMonthEntries);
        loadedMonthsSet.add(DateFormat('yyyy-MM').format(previousMonth));
        allMoodMap.addAll(_buildMoodMap(previousMonthEntries));
      }

      // Sort all entries by date (newest first)
      allEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));

      // Derive monthsWithEntries from loaded entries (loadCalendarMoodData overwrites when online)
      final monthsFromEntries = allEntries
          .map((e) => DateFormat('yyyy-MM').format(e.entry.entryDate))
          .toSet()
          .toList()
        ..sort();

      state = state.copyWith(
        entries: allEntries,
        loadedMonths: loadedMonthsSet,
        isLoading: false,
        moodMap: {...state.moodMap, ...allMoodMap},
        monthsWithEntries: monthsFromEntries,
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

  /// Load calendar mood data (runs after loadCurrentMonth)
  /// Offline: build from state.entries. Online: single fetch for moodMap + monthsWithEntries
  Future<void> loadCalendarMoodData() async {
    final userId = _getUserId();
    if (userId == null) return;

    try {
      final isOnline = await ConnectivityService().isOnline();

      if (!isOnline) {
        // Offline: build from loaded entries only
        final moodMapFromEntries = _buildMoodMap(state.entries);
        final monthsFromEntries = state.entries
            .map((e) => DateFormat('yyyy-MM').format(e.entry.entryDate))
            .toSet()
            .toList()
          ..sort();
        state = state.copyWith(
          moodMap: {...state.moodMap, ...moodMapFromEntries},
          monthsWithEntries: monthsFromEntries,
        );
        return;
      }

      // Online: single fetch for mood map + months
      final result = await _service.getMoodMapAndMonthsWithEntries(userId);
      if (result == null) {
        await ErrorLoggingService.logLowError(
          error: ErrorContext.fromException(
            errorCode: 'ERRHIST014',
            severity: ErrorSeverity.low,
            exception: Exception('getMoodMapAndMonthsWithEntries returned null'),
            stackTrace: StackTrace.current,
            errorContext: {'user_id': userId},
          ),
        );
        return;
      }

      final mergedMoodMap = <String, int>{
        ...state.moodMap,
        ...result.moodMap,
      };

      state = state.copyWith(
        moodMap: mergedMoodMap,
        monthsWithEntries: result.monthsWithEntries,
      );
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
    }
  }

  /// Load previous month (pagination)
  /// Returns: true = success, false = offline (no fetch), null = error
  Future<bool?> loadPreviousMonth(String monthKey) async {
    final userId = _getUserId();
    if (userId == null) {
      state = state.copyWith(
        error: 'User not authenticated',
        isLoadingMore: false,
      );
      return null;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      return false;
    }

    // Check if already loaded
    if (state.loadedMonths.contains(monthKey)) {
      return true;
    }

    // Parse monthKey (e.g., "2024-01")
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      state = state.copyWith(
        error: 'Invalid month key format',
        isLoadingMore: false,
      );
      return null;
    }

    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);

    state = state.copyWith(isLoadingMore: true);

    try {
      final entries = await _service.getEntriesForMonth(userId, month);
      final newMoodMap = _buildMoodMap(entries);

      state = state.copyWith(
        entries: [...state.entries, ...entries],
        loadedMonths: {...state.loadedMonths, monthKey},
        isLoadingMore: false,
        moodMap: {...state.moodMap, ...newMoodMap},
      );
      return true;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST006',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'month_key': monthKey,
            'offline_blocked': false,
          },
        ),
      );

      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load month: ${e.toString()}',
      );
      return null;
    }
  }

  /// Refresh current month
  Future<void> refresh() async {
    await loadCurrentMonth();
  }

  /// Get entry by date (for calendar tap)
  /// Returns (entry, wasOffline). When wasOffline true and entry null = show "No internet"
  Future<({HistoryEntry? entry, bool wasOffline})> getEntryByDate(DateTime date) async {
    final userId = _getUserId();
    if (userId == null) return (entry: null, wasOffline: false);

    try {
      final isOnline = await ConnectivityService().isOnline();

      if (!isOnline) {
        // Check if date is in loaded entries (2 months)
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final found = state.entries
            .where((e) => DateFormat('yyyy-MM-dd').format(e.entry.entryDate) == dateStr)
            .toList();
        if (found.isNotEmpty) {
          return (entry: found.first, wasOffline: false);
        }
        return (entry: null, wasOffline: true);
      }

      final entry = await _service.getEntryByDate(userId, date);
      return (entry: entry, wasOffline: false);
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
      return (entry: null, wasOffline: false);
    }
  }

  /// Load entries for a specific mood when filter is applied
  ///
  /// Skips last 2 months (already loaded). Fetches from older months with pagination.
  /// Returns: true = fetch attempted/success, false = offline (no fetch)
  Future<bool> loadMoodFilteredEntries(int moodScore) async {
    final userId = _getUserId();
    if (userId == null) {
      return true;
    }

    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      return false;
    }

    if (state.isLoadingMoodFilter) {
      return true;
    }

    if (state.loadedMoodEntries.contains('mood_$moodScore')) {
      return true;
    }

    final totalCount =
        state.moodMap.values.where((m) => m == moodScore).length;
    final loadedCount = state.entries
        .where((e) => e.entry.moodScore == moodScore)
        .length;

    if (loadedCount >= totalCount) {
      return true;
    }

    state = state.copyWith(isLoadingMoodFilter: true, error: null);

    try {
      final now = DateTime.now();
      // Skip last 2 loaded months (current + previous). Use first day of previous month.
      // DateTime(2026, 0, 1) auto-rolls to Dec 1, 2025 for January.
      final skipUntilDate = DateTime(now.year, now.month - 1, 1);

      const limit = 30;
      final currentOffset =
          state.moodFilterPagination['mood_$moodScore'] ?? 0;

      final fetchedEntries = await _service.getEntriesByMood(
        userId: userId,
        moodScore: moodScore,
        startDate: null,
        endDate: skipUntilDate,
        limit: limit,
        offset: currentOffset,
      );

      final existingIds = state.entries.map((e) => e.entry.id).toSet();
      final newEntries = fetchedEntries
          .where((e) => !existingIds.contains(e.entry.id))
          .toList();

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

      state = state.copyWith(
        entries: allEntries,
        loadedMoodEntries: updatedLoadedMoodEntries,
        moodFilterPagination: updatedPagination,
        isLoadingMoodFilter: false,
        moodMap: {...state.moodMap, ...newMoodMap},
      );
      return true;
    } catch (e) {
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRHIST012',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'mood_score': moodScore,
            'offline_blocked': false,
          },
        ),
      );

      state = state.copyWith(
        isLoadingMoodFilter: false,
        error: 'Failed to load entries: ${e.toString()}',
      );
      return true;
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

