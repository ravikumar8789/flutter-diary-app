import 'database_manager.dart';
import '../error_logging_service.dart';

/// Service for clearing user-specific data from local database
/// 
/// Used during logout to ensure privacy - clears all user data from local SQLite
class UserDataCleanupService {
  /// Clear all user-specific data from local database
  /// 
  /// Clears data in order respecting foreign key constraints:
  /// 1. Related tables (sync_queue, entry_* tables)
  /// 2. Main tables (entries, habits_daily, streaks)
  /// 
  /// Throws exception if clearing fails (to handle in logout flow)
  static Future<void> clearUserData(String userId) async {
    try {
      final db = await DatabaseManager().database;
      
      // Clear in order (respecting foreign key constraints)
      // Start with related tables that reference entries
      
      // 1. Clear sync queue for this user's entries
      await db.delete(
        'sync_queue',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      // 2. Clear entry-related tables
      await db.delete(
        'entry_tomorrow_notes',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      await db.delete(
        'entry_shower_bath',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      await db.delete(
        'entry_self_care',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      await db.delete(
        'entry_gratitude',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      await db.delete(
        'entry_meals',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      await db.delete(
        'entry_priorities',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      await db.delete(
        'entry_affirmations',
        where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)',
        whereArgs: [userId],
      );
      
      // 3. Clear main entries table
      await db.delete(
        'entries',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      // 4. Clear habits_daily
      await db.delete(
        'habits_daily',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      // 5. Clear streaks
      await db.delete(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS163',
        errorMessage: 'Failed to clear user data from local database: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'clearUserData',
        },
      );
      // Re-throw to handle in logout flow
      rethrow;
    }
  }
}
