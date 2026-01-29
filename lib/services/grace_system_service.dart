import 'dart:async';
import 'package:uuid/uuid.dart';
import 'error_logging_service.dart';
import 'data_fetch_service.dart';
import 'database/database_manager.dart';
import 'notification_service.dart';
import 'sync/supabase_sync_service.dart';

class GraceSystemService {
  static final SupabaseSyncService _syncService = SupabaseSyncService();
  static Timer? _debounceTimer;
  static const _uuid = Uuid();

  // Constants
  static const double PIECES_PER_TASK = 0.5; // 0.5 pieces per task
  static const double PIECES_PER_DAY =
      2.0; // 4 tasks × 0.5 pieces = 2 pieces per day
  static const double PIECES_PER_GRACE_DAY = 10.0; // 10 pieces = 1 grace day
  static const int MAX_GRACE_DAYS = 5; // Cap at 5 grace days

  // Get user's grace status from local SQLite
  // Uses local-first approach: reads from local SQLite, calculates pieces locally
  static Future<Map<String, dynamic>?> getGraceStatus(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;

      // Read from local streaks table
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      double totalPieces = 0.0;
      if (streaks.isNotEmpty) {
        totalPieces = (streaks.first['grace_pieces_total'] as num? ?? 0.0)
            .toDouble();
      }

      // Read today's habits_daily from local SQLite
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );

      double todayPieces = 0.0;
      int todayTasks = 0;

      if (todayHabits.isNotEmpty) {
        final habit = todayHabits.first;
        todayPieces = (habit['grace_pieces_earned'] as num? ?? 0.0).toDouble();

        // Count completed tasks for today
        if ((habit['filled_affirmations'] as int? ?? 0) == 1) todayTasks++;
        if ((habit['filled_gratitude'] as int? ?? 0) == 1) todayTasks++;
        if ((habit['wrote_entry'] as int? ?? 0) == 1) todayTasks++;
        if ((habit['self_care_completed_count'] as int? ?? 0) > 0) todayTasks++;
      }

      // Calculate grace days (10 pieces = 1 grace day, max 5)
      final graceDays = (totalPieces / PIECES_PER_GRACE_DAY).floor().clamp(
        0,
        MAX_GRACE_DAYS,
      );

      final result = {
        'grace_days_available': graceDays,
        'grace_pieces_total': totalPieces,
        'pieces_today': todayPieces,
        'tasks_completed_today': todayTasks,
        'progress_percentage': ((todayPieces / PIECES_PER_DAY) * 100).round(),
      };

      return result;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA120',
        errorMessage: 'Failed to get grace status: $e',
        errorContext: {'userId': userId},
      );
      return null;
    }
  }

  // Track task completion by updating local habits_daily table
  // Uses incremental updates: adds today's pieces to total, doesn't recalculate from all records
  static Future<bool> trackTaskCompletion({
    required String userId,
    required DateTime date,
    required String
    taskType, // 'affirmations', 'gratitude', 'diary', 'self_care'
    required bool completed,
    DataFetchService? dataFetchService,
  }) async {
    print('🔥 STREAK DEBUG: GraceSystemService.trackTaskCompletion START - userId: $userId, taskType: $taskType, completed: $completed');
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      print('🔥 STREAK DEBUG: dateStr: $dateStr');
      final db = await DatabaseManager().database;

      // Get or create today's habits record in local SQLite
      await _getOrCreateTodayHabitsRecord(
        userId,
        date,
        dataFetchService: dataFetchService,
      );
      print('🔥 STREAK DEBUG: Habits record retrieved/created');

      // Update the specific task completion in local SQLite
      Map<String, dynamic> updateData = {};

      switch (taskType) {
        case 'affirmations':
          updateData['filled_affirmations'] = completed ? 1 : 0;
          break;
        case 'gratitude':
          updateData['filled_gratitude'] = completed ? 1 : 0;
          break;
        case 'diary':
          updateData['wrote_entry'] = completed ? 1 : 0;
          break;
        case 'self_care':
          updateData['self_care_completed_count'] = completed ? 1 : 0;
          break;
      }
      print('🔥 STREAK DEBUG: Update data: $updateData');

      // Update local SQLite
      await db.update(
        'habits_daily',
        updateData,
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
      );
      print('🔥 STREAK DEBUG: habits_daily updated');

      // Get updated record to calculate pieces
      final updatedRecord = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );
      print('🔥 STREAK DEBUG: Updated record: ${updatedRecord.length} records');

      if (updatedRecord.isEmpty) {
        throw Exception('No habits record found after update');
      }

      final habit = updatedRecord.first;
      print('🔥 STREAK DEBUG: Habit data: $habit');

      // Calculate pieces earned (0.5 per completed task, max 2.0/day)
      final piecesEarned =
          ((habit['filled_affirmations'] as int? ?? 0) == 1 ? 0.5 : 0) +
          ((habit['filled_gratitude'] as int? ?? 0) == 1 ? 0.5 : 0) +
          ((habit['wrote_entry'] as int? ?? 0) == 1 ? 0.5 : 0) +
          ((habit['self_care_completed_count'] as int? ?? 0) > 0 ? 0.5 : 0);
      print('🔥 STREAK DEBUG: Pieces earned: $piecesEarned');

      // Update grace_pieces_earned for today in local SQLite
      await db.update(
        'habits_daily',
        {'grace_pieces_earned': piecesEarned, 'is_synced': 0},
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
      );

      // Get current streaks from local SQLite
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      // Check if day changed (edge case: day changes while app is open)
      final todayDateStr = DateTime.now().toIso8601String().split('T')[0];
      if (streaks.isNotEmpty) {
        final streakTodayDate = streaks.first['today_date'] as String?;
        if (streakTodayDate != null && streakTodayDate != todayDateStr) {
          // Day changed - clear habits_daily and reset today_* fields
          await db.delete(
            'habits_daily',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          // Reset today_* fields will be done below
        }
      }

      // Get old today_grace_pieces to calculate difference
      double oldTodayPieces = 0.0;
      double currentTotalPieces = 0.0;
      if (streaks.isNotEmpty) {
        oldTodayPieces = (streaks.first['today_grace_pieces'] as num? ?? 0.0).toDouble();
        currentTotalPieces = (streaks.first['grace_pieces_total'] as num? ?? 0.0).toDouble();
      }
      print('🔥 STREAK DEBUG: oldTodayPieces: $oldTodayPieces, currentTotalPieces: $currentTotalPieces');

      // Calculate new total: subtract old today's pieces, add new today's pieces
      double newTotalPieces = currentTotalPieces - oldTodayPieces + piecesEarned;
      print('🔥 STREAK DEBUG: newTotalPieces: $newTotalPieces');

      // Calculate grace days (10 pieces = 1 grace day, max 5)
      final graceDays = (newTotalPieces / PIECES_PER_GRACE_DAY).floor().clamp(
        0,
        MAX_GRACE_DAYS,
      );
      print('🔥 STREAK DEBUG: Calculated grace days: $graceDays');

      // Update streaks table in local SQLite with today_* fields
      if (streaks.isEmpty) {
        print('🔥 STREAK DEBUG: Creating new streaks record');
        // Create streaks record
        final newStreakData = {
          'user_id': userId,
          'current': 0,
          'longest': 0,
          'last_entry_date': null,
          'freeze_credits': graceDays,
          'grace_pieces_total': newTotalPieces,
          'today_date': todayDateStr,
          'today_diary': (habit['wrote_entry'] as int? ?? 0) == 1 ? 1 : 0,
          'today_affirmations': (habit['filled_affirmations'] as int? ?? 0) == 1 ? 1 : 0,
          'today_gratitude': (habit['filled_gratitude'] as int? ?? 0) == 1 ? 1 : 0,
          'today_self_care_count': habit['self_care_completed_count'] ?? 0,
          'today_grace_pieces': piecesEarned,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        };
        print('🔥 STREAK DEBUG: New streak data: $newStreakData');
        await db.insert('streaks', newStreakData);
        print('🔥 STREAK DEBUG: New streaks record created');
      } else {
        print('🔥 STREAK DEBUG: Updating existing streaks record');
        // Update existing record with today_* fields
        final updateData = {
          'grace_pieces_total': newTotalPieces,
          'freeze_credits': graceDays,
          'today_date': todayDateStr,
          'today_diary': (habit['wrote_entry'] as int? ?? 0) == 1 ? 1 : 0,
          'today_affirmations': (habit['filled_affirmations'] as int? ?? 0) == 1 ? 1 : 0,
          'today_gratitude': (habit['filled_gratitude'] as int? ?? 0) == 1 ? 1 : 0,
          'today_self_care_count': habit['self_care_completed_count'] ?? 0,
          'today_grace_pieces': piecesEarned,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        };
        print('🔥 STREAK DEBUG: Update data: $updateData');
        await db.update(
          'streaks',
          updateData,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print('🔥 STREAK DEBUG: Streaks record updated');
      }

      // Queue sync to Supabase via RPC (debounced, 3s)
      print('🔥 STREAK DEBUG: Scheduling sync to Supabase');
      _scheduleSync(userId, dateStr, dataFetchService: dataFetchService);

      // Invalidate cache after update
      if (dataFetchService != null) {
        dataFetchService.invalidateHabitsCache(userId, date);
        dataFetchService.invalidateStreaksCache(userId);
        dataFetchService.invalidateHomeSummaryCache(userId);
      }

      try {
        await NotificationService.instance.rescheduleBasedOnHabits(userId);
      } catch (e, stackTrace) {
        await ErrorLoggingService.logMediumError(
          errorCode: 'ERRSYS159',
          errorMessage: 'Reschedule notifications after habits update failed: $e',
          stackTrace: stackTrace.toString(),
          errorContext: {
            'user_id': userId,
            'task_type': taskType,
            'completed': completed,
            'operation': 'reschedule_after_habits_update',
          },
        );
      }

      print('🔥 STREAK DEBUG: GraceSystemService.trackTaskCompletion END - success');
      return true;
    } catch (e) {
      print('🔥 STREAK DEBUG: GraceSystemService.trackTaskCompletion ERROR: $e');
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA121',
        errorMessage: 'Failed to track task completion: $e',
        errorContext: {
          'userId': userId,
          'taskType': taskType,
          'completed': completed,
          'errorType': e.runtimeType.toString(),
        },
      );
      return false;
    }
  }

  // Use grace day when streak would break
  // Uses local-first approach: updates local SQLite, syncs to Supabase (debounced)
  static Future<bool> useGraceDay(
    String userId, {
    DataFetchService? dataFetchService,
  }) async {
    try {
      final db = await DatabaseManager().database;

      // Get grace status from local SQLite
      final graceStatus = await getGraceStatus(
        userId,
        dataFetchService: dataFetchService,
      );
      if (graceStatus == null) return false;

      final graceDays = graceStatus['grace_days_available'] as int;
      if (graceDays <= 0) return false;

      // Update streaks table in local SQLite (decrease grace days)
      await db.update(
        'streaks',
        {
          'freeze_credits': graceDays - 1,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Queue sync to Supabase via RPC (debounced, 3s)
      _scheduleSync(userId, null, dataFetchService: dataFetchService);

      // Invalidate cache after update
      if (dataFetchService != null) {
        dataFetchService.invalidateStreaksCache(userId);
        dataFetchService.invalidateHomeSummaryCache(userId);
      }

      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA122',
        errorMessage: 'Failed to use grace day: $e',
        errorContext: {'userId': userId},
      );
      return false;
    }
  }

  // Helper: Schedule debounced sync to Supabase via RPC
  static void _scheduleSync(
    String userId,
    String? dateStr, {
    DataFetchService? dataFetchService,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () async {
      try {
        final db = await DatabaseManager().database;

        // Get unsynced streaks
        final unsyncedStreaks = await db.query(
          'streaks',
          where: 'user_id = ? AND is_synced = 0',
          whereArgs: [userId],
          limit: 1,
        );

        if (unsyncedStreaks.isEmpty) return;

        final streak = unsyncedStreaks.first;

        // Get unsynced habits (specific date or all unsynced)
        List<Map<String, dynamic>> unsyncedHabits;
        if (dateStr != null) {
          unsyncedHabits = await db.query(
            'habits_daily',
            where: 'user_id = ? AND date = ? AND is_synced = 0',
            whereArgs: [userId, dateStr],
          );
        } else {
          // Get all unsynced habits (limit to last 7 days for performance)
          final sevenDaysAgo = DateTime.now()
              .subtract(Duration(days: 7))
              .toIso8601String()
              .split('T')[0];
          unsyncedHabits = await db.query(
            'habits_daily',
            where: 'user_id = ? AND date >= ? AND is_synced = 0',
            whereArgs: [userId, sevenDaysAgo],
          );
        }

        // Prepare data for RPC (include today_* fields)
        final streakData = {
          'current': streak['current'] ?? 0,
          'longest': streak['longest'] ?? 0,
          'last_entry_date': streak['last_entry_date'],
          'freeze_credits': streak['freeze_credits'] ?? 0,
          'grace_pieces_total': streak['grace_pieces_total'] ?? 0.0,
          'today_date': streak['today_date'],
          'today_diary': (streak['today_diary'] as int? ?? 0) == 1,
          'today_affirmations': (streak['today_affirmations'] as int? ?? 0) == 1,
          'today_gratitude': (streak['today_gratitude'] as int? ?? 0) == 1,
          'today_self_care_count': streak['today_self_care_count'] ?? 0,
          'today_grace_pieces': streak['today_grace_pieces'] ?? 0.0,
        };

        // Filter and fix habits with invalid UUID format (timestamp strings)
        final habitsData = <Map<String, dynamic>>[];
        for (final h in unsyncedHabits) {
          String habitId = h['id'] as String;

          // Check if ID is a timestamp (numeric string) instead of UUID
          // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (with hyphens)
          if (!habitId.contains('-') || habitId.length < 36) {
            // Invalid UUID format - generate new UUID and update local record
            final newId = _uuid.v4();
            await db.update(
              'habits_daily',
              {'id': newId},
              where: 'id = ?',
              whereArgs: [habitId],
            );
            habitId = newId;
          }

          habitsData.add({
            'id': habitId,
            'date': h['date'],
            'wrote_entry': (h['wrote_entry'] as int? ?? 0) == 1,
            'filled_affirmations': (h['filled_affirmations'] as int? ?? 0) == 1,
            'filled_gratitude': (h['filled_gratitude'] as int? ?? 0) == 1,
            'self_care_completed_count': h['self_care_completed_count'] ?? 0,
            'grace_pieces_earned': h['grace_pieces_earned'] ?? 0.0,
          });
        }

        // Single RPC call
        await _syncService.batchUpdateStreakData(
          userId: userId,
          streakData: streakData,
          habitsData: habitsData.isNotEmpty ? habitsData : null,
        );

        // Invalidate cache after sync
        if (dataFetchService != null) {
          dataFetchService.invalidateStreaksCache(userId);
          if (dateStr != null) {
            dataFetchService.invalidateHabitsCache(
              userId,
              DateTime.parse(dateStr),
            );
          }
          dataFetchService.invalidateHomeSummaryCache(userId);
        }
      } catch (e) {
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRDATA123',
          errorMessage: 'Failed to sync streak data via RPC: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {'userId': userId},
        );
      }
    });
  }

  // Helper: Get or create today's habits record in local SQLite
  static Future<Map<String, dynamic>> _getOrCreateTodayHabitsRecord(
    String userId,
    DateTime date, {
    DataFetchService? dataFetchService,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;

      // Ensure streaks record exists first
      await _ensureStreaksRecordExists(userId);

      // Try to get existing record from local SQLite
      final existing = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final habit = existing.first;
        return {
          'id': habit['id'],
          'user_id': habit['user_id'],
          'date': habit['date'],
          'wrote_entry': (habit['wrote_entry'] as int? ?? 0) == 1,
          'filled_affirmations':
              (habit['filled_affirmations'] as int? ?? 0) == 1,
          'filled_gratitude': (habit['filled_gratitude'] as int? ?? 0) == 1,
          'self_care_completed_count':
              habit['self_care_completed_count'] as int? ?? 0,
          'grace_pieces_earned': (habit['grace_pieces_earned'] as num? ?? 0.0)
              .toDouble(),
        };
      }

      // Create new record in local SQLite
      // Generate UUID for habits_daily.id (Supabase expects UUID, not timestamp)
      final id = _uuid.v4();
      await db.insert('habits_daily', {
        'id': id,
        'user_id': userId,
        'date': dateStr,
        'wrote_entry': 0,
        'filled_affirmations': 0,
        'filled_gratitude': 0,
        'self_care_completed_count': 0,
        'grace_pieces_earned': 0.0,
        'is_synced': 0,
      });

      // Invalidate cache after creating new record
      if (dataFetchService != null) {
        dataFetchService.invalidateHabitsCache(userId, date);
      }

      return {
        'id': id,
        'user_id': userId,
        'date': dateStr,
        'wrote_entry': false,
        'filled_affirmations': false,
        'filled_gratitude': false,
        'self_care_completed_count': 0,
        'grace_pieces_earned': 0.0,
      };
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA127',
        errorMessage: 'Failed to get/create today habits record: $e',
        errorContext: {'userId': userId, 'date': date.toIso8601String()},
      );
      rethrow;
    }
  }

  // Helper: Ensure streaks record exists for user in local SQLite
  static Future<void> _ensureStreaksRecordExists(String userId) async {
    try {
      final db = await DatabaseManager().database;

      // Check if streaks record exists in local SQLite
      final existing = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // Create streaks record in local SQLite
        await db.insert('streaks', {
          'user_id': userId,
          'current': 0,
          'longest': 0,
          'last_entry_date': null,
          'freeze_credits': 0,
          'grace_pieces_total': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        });
      }
    } catch (e) {
      // Silently fail - this is a helper method
    }
  }
}
