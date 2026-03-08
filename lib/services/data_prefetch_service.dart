import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'data_fetch_service.dart';
import 'entry_insight_storage_helper.dart';
import 'entry_storage_helper.dart';
import 'error_logging_service.dart';
import 'user_data_service.dart';
import 'database/database_manager.dart';
import '../models/error_models.dart';

/// Service for prefetching and merging data from Supabase.
class DataPrefetchService {
  /// Fetch and merge user profile (timestamp merge: only overwrite when Supabase newer).
  static Future<void> fetchAndMergeUserProfile(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      final response = await dataFetchService.fetchUserProfileFromSupabaseOnly(
        userId,
      );
      if (response == null) return;
      final db = await DatabaseManager().database;
      final localRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final supabaseUpdated = response['updated_at'] as String?;
      if (supabaseUpdated != null && localRows.isNotEmpty) {
        final localLastSync = localRows.first['last_sync_at'] as String?;
        if (localLastSync != null &&
            !DateTime.parse(
              supabaseUpdated,
            ).isAfter(DateTime.parse(localLastSync))) {
          return;
        }
      }
      await dataFetchService.storeUserProfile(userId, response);
    } catch (e) {
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS168',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetchAndMergeUserProfile',
          },
        ),
      );
    }
  }

  /// Fetch and merge user settings (no updated_at in Supabase — always store when fetched).
  static Future<void> fetchAndMergeUserSettings(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      final response = await dataFetchService.fetchUserSettingsFromSupabaseOnly(
        userId,
      );
      if (response == null) return;
      await dataFetchService.storeUserSettings(userId, response);
    } catch (e) {
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS169',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetchAndMergeUserSettings',
          },
        ),
      );
    }
  }

  /// Fetch and merge entries with joins (timestamp merge per entry).
  static Future<void> fetchAndMergeEntriesWithJoins(
    String userId,
    DateTime startDate,
    DateTime endDate,
    DataFetchService dataFetchService,
  ) async {
    try {
      final entries = await dataFetchService
          .fetchEntriesWithJoinsFromSupabaseOnly(userId, startDate, endDate);
      if (entries.isNotEmpty) {
        await EntryStorageHelper.storeEntriesWithRelatedDataWithMerge(
          entries,
          userId,
        );
      }
    } catch (e) {
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS165',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'operation': 'fetchAndMergeEntriesWithJoins',
          },
        ),
      );
    }
  }

  /// Fetch yesterday's insight from Supabase and store locally (overwrite).
  /// No timestamp merge — Supabase is source of truth.
  static Future<void> fetchAndStoreYesterdayInsight(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      final insight = await dataFetchService.fetchYesterdayInsightFromSupabase(
        userId,
      );
      if (insight != null) {
        await EntryInsightStorageHelper.storeYesterdayInsight(userId, insight);
      } else {
        await EntryInsightStorageHelper.clearYesterdayInsight(userId);
      }
    } catch (e) {
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS172',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetchAndStoreYesterdayInsight',
          },
        ),
      );
    }
  }

  /// Fetch and merge streaks (timestamp merge, apply gap logic when Supabase newer).
  /// Only used on splash — app open → populate local → read/write inside app uses local.
  static Future<void> fetchAndMergeStreaks(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      final response = await dataFetchService.fetchStreaksFromSupabaseOnly(
        userId,
      );
      final db = await DatabaseManager().database;
      final localRows = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final supabaseUpdated = response?['updated_at'] as String?;

      // Timestamp merge: skip overwrite when local is newer
      if (localRows.isNotEmpty && supabaseUpdated != null) {
        final isSynced = (localRows.first['is_synced'] as int? ?? 1) == 1;
        final localCompare = isSynced
            ? (localRows.first['last_sync_at'] as String?)
            : (localRows.first['updated_at'] as String?);
        if (localCompare == null && !isSynced) return;
        if (localCompare != null &&
            !DateTime.parse(
              supabaseUpdated,
            ).isAfter(DateTime.parse(localCompare))) {
          return;
        }
      }

      if (response != null) {
        await db.insert('streaks', {
          'user_id': response['user_id'],
          'current': response['current'] ?? 0,
          'longest': response['longest'] ?? 0,
          'last_entry_date': response['last_entry_date'],
          'freeze_credits': response['freeze_credits'] ?? 0,
          'grace_pieces_total': response['grace_pieces_total'] ?? 0.0,
          'today_date': response['today_date'],
          'today_diary': (response['today_diary'] ?? false) ? 1 : 0,
          'today_affirmations': (response['today_affirmations'] ?? false)
              ? 1
              : 0,
          'today_gratitude': (response['today_gratitude'] ?? false) ? 1 : 0,
          'today_self_care_count': response['today_self_care_count'] ?? 0,
          'today_grace_pieces': response['today_grace_pieces'] ?? 0.0,
          'updated_at':
              response['updated_at'] ?? DateTime.now().toIso8601String(),
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await UserDataService.applyGapIfNeeded(userId);
      } else {
        await UserDataService.ensureStreaksRecordExists(userId);
      }
    } catch (e) {
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS167',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetchAndMergeStreaks',
          },
        ),
      );
    }
  }

  /// Store entries with all related data in local DB
  static Future<void> storeEntriesWithRelatedData(
    List<Map<String, dynamic>> entries,
    String userId,
  ) async {
    await EntryStorageHelper.storeEntriesWithRelatedData(entries, userId);
  }

  /// Build habits_daily for today only (after fetch).
  /// Called on splash after Future.wait — ensures streak/grace logic has correct data.
  /// If today's entry exists: compute task flags from entry. If not: insert 0/0/0/0.
  /// Grace pieces come from streaks table (already merged from Supabase).
  static Future<void> ensureHabitsDailyFromEntries(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final todayStr =
          '${DateTime.now().year.toString().padLeft(4, '0')}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}';

      // Get grace pieces from streaks (source of truth, already merged from Supabase)
      double gracePieces = 0.0;
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (streaks.isNotEmpty) {
        gracePieces = (streaks.first['today_grace_pieces'] as num? ?? 0.0)
            .toDouble();
      }

      // Get today's entry only
      final todayEntries = await db.query(
        'entries',
        where: 'user_id = ? AND entry_date = ?',
        whereArgs: [userId, todayStr],
        columns: ['id', 'diary_text'],
        limit: 1,
      );

      int wroteEntry = 0;
      int filledAffirmations = 0;
      int filledGratitude = 0;
      int selfCareCount = 0;

      if (todayEntries.isNotEmpty) {
        final entry = todayEntries.first;
        final entryId = entry['id'] as String?;
        final diaryText = entry['diary_text'] as String?;
        if (entryId != null) {
          wroteEntry = (diaryText?.trim().isNotEmpty ?? false) ? 1 : 0;

          final affirmRows = await db.query(
            'entry_affirmations',
            where: 'entry_id = ?',
            whereArgs: [entryId],
            limit: 1,
          );
          filledAffirmations = affirmRows.isNotEmpty ? 1 : 0;

          final gratitudeRows = await db.query(
            'entry_gratitude',
            where: 'entry_id = ?',
            whereArgs: [entryId],
            limit: 1,
          );
          filledGratitude = gratitudeRows.isNotEmpty ? 1 : 0;

          final mealsRows = await db.query(
            'entry_meals',
            where: 'entry_id = ?',
            whereArgs: [entryId],
            limit: 1,
          );
          final selfCareRows = await db.query(
            'entry_self_care',
            where: 'entry_id = ?',
            whereArgs: [entryId],
            limit: 1,
          );
          bool hasMeals = false;
          if (mealsRows.isNotEmpty) {
            final m = mealsRows.first;
            hasMeals =
                (m['breakfast'] as String? ?? '').trim().isNotEmpty ||
                (m['lunch'] as String? ?? '').trim().isNotEmpty ||
                (m['dinner'] as String? ?? '').trim().isNotEmpty ||
                (m['water_cups'] as int? ?? 0) > 0;
          }
          bool hasSelfCare = false;
          if (selfCareRows.isNotEmpty) {
            final s = selfCareRows.first;
            hasSelfCare =
                (s['sleep'] as int? ?? 0) == 1 ||
                (s['get_up_early'] as int? ?? 0) == 1 ||
                (s['fresh_air'] as int? ?? 0) == 1 ||
                (s['learn_new'] as int? ?? 0) == 1 ||
                (s['balanced_diet'] as int? ?? 0) == 1 ||
                (s['podcast'] as int? ?? 0) == 1 ||
                (s['me_moment'] as int? ?? 0) == 1 ||
                (s['hydrated'] as int? ?? 0) == 1 ||
                (s['read_book'] as int? ?? 0) == 1 ||
                (s['exercise'] as int? ?? 0) == 1;
          }
          selfCareCount = (hasMeals || hasSelfCare) ? 1 : 0;
        }
      }

      // Remove old habits_daily rows (keep only today)
      await db.delete(
        'habits_daily',
        where: 'user_id = ? AND date != ?',
        whereArgs: [userId, todayStr],
      );

      await db.insert('habits_daily', {
        'id': Uuid().v4(),
        'user_id': userId,
        'date': todayStr,
        'wrote_entry': wroteEntry,
        'filled_affirmations': filledAffirmations,
        'filled_gratitude': filledGratitude,
        'self_care_completed_count': selfCareCount,
        'grace_pieces_earned': gracePieces,
        'is_synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS174',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'ensureHabitsDailyFromEntries',
          },
        ),
      );
    }
  }
}
