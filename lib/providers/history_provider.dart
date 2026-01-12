import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/history_entry_model.dart';
import '../services/history_service.dart';
import '../services/error_logging_service.dart';
import 'data_providers.dart';

class HistoryState {
  final List<HistoryEntry> entries;
  final Set<String> loadedMonths; // e.g., "2024-01"
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Map<String, int> moodMap; // date string -> mood (1-5)
  final List<String> monthsWithEntries; // All months that have entries (for Load More button)

  HistoryState({
    this.entries = const [],
    this.loadedMonths = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    Map<String, int>? moodMap,
    this.monthsWithEntries = const [],
  }) : moodMap = moodMap ?? {};

  HistoryState copyWith({
    List<HistoryEntry>? entries,
    Set<String>? loadedMonths,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Map<String, int>? moodMap,
    List<String>? monthsWithEntries,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      loadedMonths: loadedMonths ?? this.loadedMonths,
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
        moodMap: allMoodMap,
        monthsWithEntries: monthsWithEntries,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRHIST005',
        errorMessage: 'Failed to load current month: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {'user_id': userId},
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
        errorCode: 'ERRHIST010',
        errorMessage: 'Failed to load calendar mood data: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId},
      );
      // Don't update state on error - use existing mood map
    }
  }

  /// Load previous month (pagination)
  Future<void> loadPreviousMonth(String monthKey) async {
    final userId = _getUserId();
    if (userId == null) {
      state = state.copyWith(
        error: 'User not authenticated',
        isLoadingMore: false,
      );
      return;
    }

    // Check if already loaded
    if (state.loadedMonths.contains(monthKey)) {
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

    try {
      final entries = await _service.getEntriesForMonth(userId, month);
      final newMoodMap = _buildMoodMap(entries);

      state = state.copyWith(
        entries: [...state.entries, ...entries],
        loadedMonths: {...state.loadedMonths, monthKey},
        isLoadingMore: false,
        moodMap: {...state.moodMap, ...newMoodMap},
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRHIST006',
        errorMessage: 'Failed to load previous month: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'user_id': userId,
          'month_key': monthKey,
        },
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
        errorCode: 'ERRHIST007',
        errorMessage: 'Failed to get entry by date: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'user_id': userId,
          'date': DateFormat('yyyy-MM-dd').format(date),
        },
      );
      return null;
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

