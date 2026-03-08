import 'package:uuid/uuid.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'database/database_manager.dart';
import 'database/local_entry_service.dart';
import 'notification_service.dart';

class GraceSystemService {
  static const _uuid = Uuid();

  // Constants
  static const double PIECES_PER_TASK = 0.5; // 0.5 pieces per task
  static const double PIECES_PER_DAY =
      2.0; // 4 tasks × 0.5 pieces = 2 pieces per day
  static const double PIECES_PER_GRACE_DAY = 10.0; // 10 pieces = 1 grace day
  static const int MAX_GRACE_DAYS = 5; // Cap at 5 grace days

  // Get user's grace status from local SQLite
  static Future<Map<String, dynamic>?> getGraceStatus(String userId) async {
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA120',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'userId': userId},
        ),
      );
      return null;
    }
  }

  // Track task completion by updating local habits_daily table
  static Future<bool> trackTaskCompletion({
    required String userId,
    required DateTime date,
    required String taskType,
    required bool completed,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;

      await _getOrCreateTodayHabitsRecord(userId, date);

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
      final piecesEarned =
          ((habit['filled_affirmations'] as int? ?? 0) == 1 ? 0.5 : 0) +
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

      // Check if day changed (edge case: day changes while app is open)
      final todayDateStr = DateTime.now().toIso8601String().split('T')[0];
      if (streaks.isNotEmpty) {
        final streakTodayDate = streaks.first['today_date'] as String?;
        if (streakTodayDate != null && streakTodayDate != todayDateStr) {
          // Day changed - clear today's habits_daily row (habits_daily is today-only)
          await db.delete(
            'habits_daily',
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, streakTodayDate],
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

      // Calculate new total: subtract old today's pieces, add new today's pieces
      double newTotalPieces = currentTotalPieces - oldTodayPieces + piecesEarned;

      // Calculate grace days (10 pieces = 1 grace day, max 5)
      final graceDays = (newTotalPieces / PIECES_PER_GRACE_DAY).floor().clamp(
        0,
        MAX_GRACE_DAYS,
      );

      // Update streaks table in local SQLite with today_* fields
      if (streaks.isEmpty) {
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
        await db.insert('streaks', newStreakData);
      } else {
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
        await db.update(
          'streaks',
          updateData,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }

      await LocalEntryService.addStreakToSyncQueue(userId);

      try {
        await NotificationService.instance.rescheduleBasedOnHabits(userId);
      } catch (e, stackTrace) {
        await ErrorLoggingService.logMediumError(
          error: ErrorContext.fromException(
            errorCode: 'ERRSYS159',
            severity: ErrorSeverity.medium,
            exception: e,
            stackTrace: stackTrace,
            errorContext: {
              'user_id': userId,
              'task_type': taskType,
              'completed': completed,
              'operation': 'reschedule_after_habits_update',
            },
          ),
        );
      }

      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA121',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'userId': userId,
            'taskType': taskType,
            'completed': completed,
            'errorType': e.runtimeType.toString(),
          },
        ),
      );
      return false;
    }
  }

  // Use grace day when streak would break
  static Future<bool> useGraceDay(String userId) async {
    try {
      final graceStatus = await getGraceStatus(userId);
      if (graceStatus == null) return false;

      final graceDays = graceStatus['grace_days_available'] as int;
      if (graceDays <= 0) return false;

      final db = await DatabaseManager().database;
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

      await LocalEntryService.addStreakToSyncQueue(userId);

      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA122',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'userId': userId},
        ),
      );
      return false;
    }
  }

  static Future<Map<String, dynamic>> _getOrCreateTodayHabitsRecord(
    String userId,
    DateTime date,
  ) async {
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
      // Generate UUID for habits_daily.id (local-only)
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA127',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'userId': userId, 'date': date.toIso8601String()},
        ),
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
