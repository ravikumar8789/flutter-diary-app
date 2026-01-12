import 'dart:async';
import 'error_logging_service.dart';
import 'data_fetch_service.dart';
import 'database/database_manager.dart';
import 'sync/supabase_sync_service.dart';

class GraceSystemService {
  static final SupabaseSyncService _syncService = SupabaseSyncService();
  static Timer? _debounceTimer;

  // Constants
  static const double PIECES_PER_TASK = 0.5; // 0.5 pieces per task
  static const double PIECES_PER_DAY = 2.0; // 4 tasks × 0.5 pieces = 2 pieces per day
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
        totalPieces = (streaks.first['grace_pieces_total'] as num? ?? 0.0).toDouble();
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
      final graceDays = (totalPieces / PIECES_PER_GRACE_DAY).floor().clamp(0, MAX_GRACE_DAYS);

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
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;

      // Get or create today's habits record in local SQLite
      await _getOrCreateTodayHabitsRecord(userId, date, dataFetchService: dataFetchService);

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

      // Update local SQLite
      await db.update(
        'habits_daily',
        updateData,
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
      );

      // Get updated record to calculate pieces
      final updatedRecord = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );

      if (updatedRecord.isEmpty) {
        throw Exception('No habits record found after update');
      }

      final habit = updatedRecord.first;

      // Calculate pieces earned (0.5 per completed task, max 2.0/day)
      final piecesEarned = ((habit['filled_affirmations'] as int? ?? 0) == 1 ? 0.5 : 0) +
          ((habit['filled_gratitude'] as int? ?? 0) == 1 ? 0.5 : 0) +
          ((habit['wrote_entry'] as int? ?? 0) == 1 ? 0.5 : 0) +
          ((habit['self_care_completed_count'] as int? ?? 0) > 0 ? 0.5 : 0);

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

      // Recalculate total from all habits_daily records in local SQLite
      // This is still fast since it's just one local table query
      final allLocalHabits = await db.query(
        'habits_daily',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      double newTotalPieces = allLocalHabits.fold<double>(
        0.0,
        (sum, record) => sum + ((record['grace_pieces_earned'] as num? ?? 0.0).toDouble()),
      );

      // Calculate grace days (10 pieces = 1 grace day, max 5)
      final graceDays = (newTotalPieces / PIECES_PER_GRACE_DAY).floor().clamp(0, MAX_GRACE_DAYS);

      // Update streaks table in local SQLite (incremental update)
      if (streaks.isEmpty) {
        // Create streaks record
        await db.insert(
          'streaks',
          {
            'user_id': userId,
            'current': 0,
            'longest': 0,
            'last_entry_date': null,
            'freeze_credits': graceDays,
            'grace_pieces_total': newTotalPieces,
            'updated_at': DateTime.now().toIso8601String(),
            'is_synced': 0,
          },
        );
      } else {
        // Update existing record
        await db.update(
          'streaks',
          {
            'grace_pieces_total': newTotalPieces,
            'freeze_credits': graceDays,
            'updated_at': DateTime.now().toIso8601String(),
            'is_synced': 0,
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }

      // Queue sync to Supabase (debounced, 2s)
      _scheduleSync(userId, dateStr);

      // Invalidate cache after update
      if (dataFetchService != null) {
        dataFetchService.invalidateHabitsCache(userId, date);
        dataFetchService.invalidateStreaksCache(userId);
      }

      return true;
    } catch (e) {
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
      final graceStatus = await getGraceStatus(userId, dataFetchService: dataFetchService);
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

      // Queue sync to Supabase (debounced, 2s)
      _scheduleSync(userId, null);

      // Invalidate cache after update
      if (dataFetchService != null) {
        dataFetchService.invalidateStreaksCache(userId);
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

  // Helper: Schedule debounced sync to Supabase
  static void _scheduleSync(String userId, String? dateStr) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      try {
        await _syncService.syncAllStreaks(userId);
        if (dateStr != null) {
          final db = await DatabaseManager().database;
          final habits = await db.query(
            'habits_daily',
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, dateStr],
            limit: 1,
          );
          if (habits.isNotEmpty) {
            final habit = habits.first;
            await _syncService.syncHabitsDaily(
              userId,
              dateStr,
              {
                'id': habit['id'],
                'wrote_entry': (habit['wrote_entry'] as int? ?? 0) == 1,
                'filled_affirmations': (habit['filled_affirmations'] as int? ?? 0) == 1,
                'filled_gratitude': (habit['filled_gratitude'] as int? ?? 0) == 1,
                'self_care_completed_count': habit['self_care_completed_count'] as int? ?? 0,
                'grace_pieces_earned': habit['grace_pieces_earned'] as num? ?? 0.0,
              },
            );
          }
        } else {
          await _syncService.syncAllHabits(userId);
        }
      } catch (e) {
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRDATA123',
          errorMessage: 'Failed to sync grace data: $e',
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
          'filled_affirmations': (habit['filled_affirmations'] as int? ?? 0) == 1,
          'filled_gratitude': (habit['filled_gratitude'] as int? ?? 0) == 1,
          'self_care_completed_count': habit['self_care_completed_count'] as int? ?? 0,
          'grace_pieces_earned': (habit['grace_pieces_earned'] as num? ?? 0.0).toDouble(),
        };
      }

      // Create new record in local SQLite
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await db.insert(
        'habits_daily',
        {
          'id': id,
          'user_id': userId,
          'date': dateStr,
          'wrote_entry': 0,
          'filled_affirmations': 0,
          'filled_gratitude': 0,
          'self_care_completed_count': 0,
          'grace_pieces_earned': 0.0,
          'is_synced': 0,
        },
      );

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
        await db.insert(
          'streaks',
          {
            'user_id': userId,
            'current': 0,
            'longest': 0,
            'last_entry_date': null,
            'freeze_credits': 0,
            'grace_pieces_total': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
            'is_synced': 0,
          },
        );
      }
    } catch (e) {
      // Silently fail - this is a helper method
    }
  }


}
