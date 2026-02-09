import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/data_repository.dart';
import '../services/data_fetch_service.dart';
import '../models/entry_models.dart';
import '../models/analytics_models.dart';
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

/// Query parameters for habits provider
class HabitsQueryParams {
  final String userId;
  final DateTime startDate;
  final DateTime endDate;

  HabitsQueryParams({
    required this.userId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitsQueryParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => userId.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

/// Repository provider (singleton, never disposed until app close)
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  final repo = DataRepository();

  // Dispose on app close
  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});

/// Fetch service provider (singleton)
final dataFetchServiceProvider = Provider<DataFetchService>((ref) {
  final repo = ref.watch(dataRepositoryProvider);
  return DataFetchService(repository: repo);
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

/// Habits provider (NOT autoDispose, shared across app)
/// 
/// Uses family provider to support different date ranges.
/// Data is cached and shared across all widgets using same params.
final habitsProvider = FutureProvider.family<List<HabitsDaily>, HabitsQueryParams>(
  (ref, params) async {
    final service = ref.watch(dataFetchServiceProvider);

    try {
      return await service.fetchHabitsDaily(
        userId: params.userId,
        startDate: params.startDate,
        endDate: params.endDate,
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA205',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': params.userId,
            'start_date': params.startDate.toIso8601String(),
            'end_date': params.endDate.toIso8601String(),
            'operation': 'habits_provider',
          },
        ),
      );
      rethrow;
    }
  },
);

/// Home summary provider (NOT autoDispose, cached)
/// 
/// Uses HomeSummaryService but results are cached via DataRepository.
/// This prevents duplicate fetches while maintaining existing logic.
final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  try {
    // Get user directly from Supabase (more reliable than waiting for stream)
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      return const HomeSummary();
    }

    final userId = user.id;
    final repository = ref.watch(dataRepositoryProvider);

    // Cache key for home summary (refreshes every 5 minutes)
    final key = 'home_summary_${userId}';

    return await repository.fetch<HomeSummary>(
      key: key,
      fetcher: () async {
        // Use HomeSummaryService with DataFetchService for caching
        final dataFetchService = ref.read(dataFetchServiceProvider);
        final homeSummaryService = HomeSummaryService(
          dataFetchService: dataFetchService,
        );
        return await homeSummaryService.fetchAll(userId);
      },
      ttl: const Duration(minutes: 5), // Cache for 5 minutes
      allowStale: true, // Enable stale-while-revalidate
    );
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

