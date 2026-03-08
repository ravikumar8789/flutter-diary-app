import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_fetch_service.dart';
import '../models/entry_models.dart';
import '../models/home_summary_models.dart';
import '../models/error_models.dart';
import '../services/error_logging_service.dart';
import '../services/home_summary_service.dart';

/// Query parameters for entries provider
class EntryQueryParams {
  final String userId;
  final DateTime startDate;
  final DateTime endDate;

  EntryQueryParams({
    required this.userId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryQueryParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => userId.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

/// Fetch service provider (singleton)
final dataFetchServiceProvider = Provider<DataFetchService>((ref) {
  return DataFetchService();
});

/// Entries provider (NOT autoDispose, shared across app)
/// 
/// Uses family provider to support different date ranges.
/// Data is cached and shared across all widgets using same params.
final entriesProvider = FutureProvider.family<List<Entry>, EntryQueryParams>(
  (ref, params) async {
    final service = ref.watch(dataFetchServiceProvider);

    try {
      return await service.fetchEntries(
        userId: params.userId,
        startDate: params.startDate,
        endDate: params.endDate,
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA204',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': params.userId,
            'start_date': params.startDate.toIso8601String(),
            'end_date': params.endDate.toIso8601String(),
            'operation': 'entries_provider',
          },
        ),
      );
      rethrow;
    }
  },
);

/// Home summary provider (NOT autoDispose)
final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const HomeSummary();
    }

    final userId = user.id;
    final dataFetchService = ref.read(dataFetchServiceProvider);
    final homeSummaryService = HomeSummaryService(
      dataFetchService: dataFetchService,
    );
    return await homeSummaryService.fetchAll(userId);
  } catch (e) {
    await ErrorLoggingService.logHighError(
      error: ErrorContext.fromException(
        errorCode: 'ERRDATA206',
        severity: ErrorSeverity.high,
        exception: e,
        stackTrace: StackTrace.current,
        errorContext: {
          'operation': 'home_summary_provider',
        },
      ),
    );
    // Return empty summary on error
    return const HomeSummary();
  }
});

