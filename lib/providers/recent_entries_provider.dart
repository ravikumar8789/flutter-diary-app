import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/history_entry_model.dart';
import '../models/error_models.dart';
import '../services/history_service.dart';
import '../services/connectivity_service.dart';
import '../services/error_logging_service.dart';
import 'data_providers.dart';

/// Provider for recent entries (last 3-5 entries for home screen)
/// Fetches entries for current + previous month and returns top 5.
final recentEntriesProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final userId = user.id;
    final isOnline = await ConnectivityService().isOnline();
    final dataFetchService = ref.watch(dataFetchServiceProvider);
    final service = HistoryService(dataFetchService: dataFetchService);

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final previousMonth = DateTime(now.year, now.month - 1, 1);

    final currentEntries = await service.getEntriesForMonth(userId, currentMonth, useLocalOnly: !isOnline);
    final previousEntries = await service.getEntriesForMonth(userId, previousMonth, useLocalOnly: !isOnline);

    final allEntries = [...currentEntries, ...previousEntries];
    allEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));

    return allEntries.take(5).toList();
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

