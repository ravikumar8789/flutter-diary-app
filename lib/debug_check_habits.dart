// Temporary debug file - check local habits_daily
// Run this after saving an entry to see if habits_daily record exists locally

import 'package:sqflite/sqflite.dart';
import 'services/database/database_manager.dart';

Future<void> checkLocalHabits(String userId, String date) async {
  try {
    final db = await DatabaseManager().database;
    
    // Check local habits_daily
    final habits = await db.query(
      'habits_daily',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
    
    print('=== LOCAL HABITS_DAILY CHECK ===');
    print('User: $userId');
    print('Date: $date');
    print('Records found: ${habits.length}');
    
    if (habits.isNotEmpty) {
      final habit = habits.first;
      print('Record:');
      print('  - id: ${habit['id']}');
      print('  - wrote_entry: ${habit['wrote_entry']}');
      print('  - filled_affirmations: ${habit['filled_affirmations']}');
      print('  - filled_gratitude: ${habit['filled_gratitude']}');
      print('  - self_care_completed_count: ${habit['self_care_completed_count']}');
      print('  - grace_pieces_earned: ${habit['grace_pieces_earned']}');
      print('  - is_synced: ${habit['is_synced']}');
      print('  - last_sync_at: ${habit['last_sync_at']}');
    } else {
      print('❌ NO RECORD FOUND IN LOCAL DB');
    }
    
    // Check local streaks
    final streaks = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    print('\n=== LOCAL STREAKS CHECK ===');
    if (streaks.isNotEmpty) {
      final streak = streaks.first;
      print('  - current: ${streak['current']}');
      print('  - longest: ${streak['longest']}');
      print('  - last_entry_date: ${streak['last_entry_date']}');
      print('  - is_synced: ${streak['is_synced']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
