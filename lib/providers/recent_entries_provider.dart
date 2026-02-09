import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/history_entry_model.dart';
import '../models/error_models.dart';
import '../services/history_service.dart';
import '../services/error_logging_service.dart';
import 'data_providers.dart';

/// Provider for recent entries (last 3-5 entries for home screen)
/// 
/// NOT autoDispose - uses DataRepository for caching.
/// Fetches entries for current + previous month and returns top 5.
final recentEntriesProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  try {
    // Get user directly from Supabase (more reliable than waiting for stream)
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final userId = user.id;
    final repository = ref.watch(dataRepositoryProvider);
    final dataFetchService = ref.watch(dataFetchServiceProvider);
    final service = HistoryService(dataFetchService: dataFetchService);

    // Get entries for current month and previous month
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final previousMonth = DateTime(now.year, now.month - 1, 1);

    // Cache key
    final key = 'recent_entries_${userId}_${currentMonth.toIso8601String()}_${previousMonth.toIso8601String()}';

    return await repository.fetch<List<HistoryEntry>>(
      key: key,
      fetcher: () async {
        final currentEntries = await service.getEntriesForMonth(userId, currentMonth);
        final previousEntries = await service.getEntriesForMonth(userId, previousMonth);

        // Combine and sort by date descending, take first 5
        final allEntries = [...currentEntries, ...previousEntries];
        allEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));

        return allEntries.take(5).toList();
      },
      ttl: const Duration(minutes: 5), // Cache for 5 minutes
    );
  } catch (e) {
    await ErrorLoggingService.logHighError(
      error: ErrorContext.fromException(
        errorCode: 'ERRDATA207',
        severity: ErrorSeverity.high,
        exception: e,
        stackTrace: StackTrace.current,
        errorContext: {
          'operation': 'recent_entries_provider',
        },
      ),
    );
    return [];
  }
});

