import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_logging_service.dart';

class GraceSystemService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Constants
  static const double PIECES_PER_TASK = 0.5;
  static const double PIECES_PER_DAY = 2.0;
  static const double PIECES_PER_GRACE_DAY = 10.0;
  static const int MAX_GRACE_DAYS = 5; // Cap at 5 grace days

  // Get user's grace status from habits_daily table
  static Future<Map<String, dynamic>?> getGraceStatus(String userId) async {
    try {
      // First, let's check what's actually in the habits_daily table
      final habitsData = await _supabase
          .from('habits_daily')
          .select('*')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(5);

      // Check today's record specifically
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todayRecord = await _supabase
          .from('habits_daily')
          .select('*')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      final response = await _supabase
          .rpc(
            'calculate_grace_days_from_habits',
            params: {
              'p_user_id': userId,
              'p_date': today, // Pass app's current date
            },
          )
          .single();

      final result = {
        'grace_days_available': response['grace_days_available'] ?? 0,
        'grace_pieces_total': response['grace_pieces_total'] ?? 0.0,
        'pieces_today': response['pieces_today'] ?? 0.0,
        'tasks_completed_today': response['tasks_completed_today'] ?? 0,
        'progress_percentage': ((response['pieces_today'] ?? 0.0) / 2.0 * 100)
            .round(),
      };

      // If the database function returns all zeros, try manual calculation
      if (result['grace_pieces_total'] == 0.0 &&
          result['pieces_today'] == 0.0) {
        return await _calculateGraceStatusManually(userId);
      }

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

  // Track task completion by updating habits_daily table
  static Future<bool> trackTaskCompletion({
    required String userId,
    required DateTime date,
    required String
    taskType, // 'affirmations', 'gratitude', 'diary', 'self_care'
    required bool completed,
  }) async {
    try {
      // Get or create today's habits record
      await _getOrCreateTodayHabitsRecord(userId, date);

      // Update the specific task completion
      Map<String, dynamic> updateData = {};

      switch (taskType) {
        case 'affirmations':
          updateData['filled_affirmations'] = completed;
          break;
        case 'gratitude':
          updateData['filled_gratitude'] = completed;
          break;
        case 'diary':
          updateData['wrote_entry'] = completed;
          break;
        case 'self_care':
          // For self-care, we track count, so we need to handle this differently
          if (completed) {
            updateData['self_care_completed_count'] = 1;
          } else {
            updateData['self_care_completed_count'] = 0;
          }
          break;
      }

      // Update the record (trigger will automatically calculate grace pieces)
      final updateResult = await _supabase
          .from('habits_daily')
          .update(updateData)
          .eq('user_id', userId)
          .eq('date', date.toIso8601String().split('T')[0])
          .select();

      // Check if update actually worked
      if (updateResult.isEmpty) {
        throw Exception('No rows were updated in habits_daily');
      }

      // Verify the trigger worked by checking the updated record
      final verifyResult = await _supabase
          .from('habits_daily')
          .select(
            'grace_pieces_earned, filled_gratitude, filled_affirmations, wrote_entry, self_care_completed_count',
          )
          .eq('user_id', userId)
          .eq('date', date.toIso8601String().split('T')[0])
          .single();

      // If trigger didn't work, manually calculate and update
      if (verifyResult['grace_pieces_earned'] == 0.0) {
        final manualPieces =
            ((verifyResult['filled_affirmations'] == true ? 0.5 : 0) +
            (verifyResult['filled_gratitude'] == true ? 0.5 : 0) +
            (verifyResult['wrote_entry'] == true ? 0.5 : 0) +
            (verifyResult['self_care_completed_count'] > 0 ? 0.5 : 0));

        await _supabase
            .from('habits_daily')
            .update({'grace_pieces_earned': manualPieces})
            .eq('user_id', userId)
            .eq('date', date.toIso8601String().split('T')[0]);

        // Also update the streaks table manually
        final totalPieces = await _supabase
            .from('habits_daily')
            .select('grace_pieces_earned')
            .eq('user_id', userId);

        final totalPiecesSum = totalPieces.fold<double>(
          0.0,
          (sum, record) => sum + (record['grace_pieces_earned'] ?? 0.0),
        );

        final graceDays = (totalPiecesSum / 10).floor().clamp(0, 5);

        await _supabase
            .from('streaks')
            .update({
              'grace_pieces_total': totalPiecesSum,
              'freeze_credits': graceDays,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId);
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
  static Future<bool> useGraceDay(String userId) async {
    try {
      final graceStatus = await getGraceStatus(userId);
      if (graceStatus == null) return false;

      final graceDays = graceStatus['grace_days_available'] as int;
      if (graceDays <= 0) return false;

      // Record grace day usage
      await _supabase.from('streak_freeze_usage').insert({
        'user_id': userId,
        'reason': 'grace_day_used',
        'streak_maintained': await _getCurrentStreak(userId),
        'grace_day_used': true,
        'grace_period_days': 1,
      });

      // Update streaks table (decrease grace days)
      await _supabase
          .from('streaks')
          .update({
            'freeze_credits': graceDays - 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

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

  // Helper: Get or create today's habits record
  static Future<Map<String, dynamic>> _getOrCreateTodayHabitsRecord(
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      // Ensure streaks record exists first
      await _ensureStreaksRecordExists(userId);

      // Try to get existing record
      final existing = await _supabase
          .from('habits_daily')
          .select('*')
          .eq('user_id', userId)
          .eq('date', dateStr);

      if (existing.isNotEmpty) {
        return existing.first;
      }

      // Create new record
      final newRecord = {
        'user_id': userId,
        'date': dateStr,
        'wrote_entry': false,
        'filled_affirmations': false,
        'filled_gratitude': false,
        'self_care_completed_count': 0,
        'grace_pieces_earned': 0.0,
      };

      final response = await _supabase
          .from('habits_daily')
          .insert(newRecord)
          .select()
          .single();

      return response;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA127',
        errorMessage: 'Failed to get/create today habits record: $e',
        errorContext: {'userId': userId, 'date': date.toIso8601String()},
      );
      rethrow;
    }
  }

  // Helper: Ensure streaks record exists for user
  static Future<void> _ensureStreaksRecordExists(String userId) async {
    try {
      // Check if streaks record exists
      final existing = await _supabase
          .from('streaks')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Create streaks record
        await _supabase.from('streaks').insert({
          'user_id': userId,
          'current': 0,
          'longest': 0,
          'last_entry_date': null,
          'freeze_credits': 0,
          'grace_pieces_total': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {}
  }

  // Helper: Get current streak
  static Future<int> _getCurrentStreak(String userId) async {
    try {
      final response = await _supabase
          .from('streaks')
          .select('current')
          .eq('user_id', userId)
          .single();
      return response['current'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Manual calculation of grace status when database function fails
  static Future<Map<String, dynamic>?> _calculateGraceStatusManually(
    String userId,
  ) async {
    try {
      // Get all habits_daily records for this user
      final habitsData = await _supabase
          .from('habits_daily')
          .select('*')
          .eq('user_id', userId);

      // Calculate total pieces from all records
      double totalPieces = 0.0;
      double todayPieces = 0.0;
      int todayTasks = 0;

      final today = DateTime.now().toIso8601String().split('T')[0];

      for (var record in habitsData) {
        final recordDate = record['date'] as String;
        final gracePiecesEarned =
            (record['grace_pieces_earned'] ?? 0.0) as double;

        totalPieces += gracePiecesEarned;

        // Check if this is today's record
        if (recordDate == today) {
          todayPieces = gracePiecesEarned;

          // Count completed tasks for today
          if (record['filled_affirmations'] == true) todayTasks++;
          if (record['filled_gratitude'] == true) todayTasks++;
          if (record['wrote_entry'] == true) todayTasks++;
          if ((record['self_care_completed_count'] ?? 0) > 0) todayTasks++;
        }
      }

      // Calculate grace days (10 pieces = 1 grace day, max 5)
      final graceDays = (totalPieces / 10).floor().clamp(0, 5);

      final result = {
        'grace_days_available': graceDays,
        'grace_pieces_total': totalPieces,
        'pieces_today': todayPieces,
        'tasks_completed_today': todayTasks,
        'progress_percentage': ((todayPieces / 2.0) * 100).round(),
      };

      // Update the streaks table with our calculation
      await _supabase
          .from('streaks')
          .update({
            'grace_pieces_total': totalPieces,
            'freeze_credits': graceDays,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return result;
    } catch (e) {
      return null;
    }
  }
}
