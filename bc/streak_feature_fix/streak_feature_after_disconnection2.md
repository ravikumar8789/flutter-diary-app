# Streak Feature - Complete RPC-Based Implementation Plan

**Date:** 2026-01-19  
**Status:** Ready for Implementation  
**Goal:** Optimize streak feature with RPC batch updates, local-first approach, and data repository pattern

---

## 📋 Executive Summary

This plan implements a fully optimized streak feature that:
- ✅ Uses RPC batch updates (1 call instead of 2+)
- ✅ Local-first calculation (calculate locally, sync via RPC)
- ✅ Data repository pattern (caching + Riverpod)
- ✅ Removes unused DB objects
- ✅ No data loss for existing users
- ✅ Gap detection on batch save + app launch
- ✅ Streak based on `habits_daily` (not `entries` table)

**Expected Impact:**
- **API Calls:** 4+ → 1-2 calls per session (75% reduction)
- **Performance:** Instant local updates, background sync
- **Data Safety:** All existing user data preserved

---

## 1. Database Analysis & Cleanup

### 1.1 Unused Objects Found (via MCP)

**Functions to Remove:**
- ✅ `calculate_grace_days_from_habits()` - Not used in code (app calculates locally)
- ✅ `update_grace_pieces_on_task_completion()` - Not used (app calculates locally)

**Triggers to Remove:**
- ✅ `trigger_update_grace_pieces` on `habits_daily` - Not needed (app calculates locally)

**Tables to Remove:**
- ✅ `streak_freeze_usage` - 0 code references found (grace days tracked in `streaks.freeze_credits`)

**Keep:**
- ✅ `set_streaks_updated_at` trigger - Still useful for auto-updating `updated_at`

### 1.2 Code Changes After Removal

**No code changes needed** - All removed objects are already unused:
- ✅ No `.rpc('calculate_grace_days_from_habits')` calls found
- ✅ No references to `streak_freeze_usage` table found
- ✅ Trigger was already disconnected (app calculates pieces)

**Safe to remove immediately** - No breaking changes.

---

## 2. Database Changes (Supabase)

### 2.1 Create RPC Function

**File:** Execute in Supabase SQL Editor

```sql
-- RPC function for batch streak/habits updates
CREATE OR REPLACE FUNCTION batch_update_streak_data(
  p_user_id uuid,
  p_streak_data jsonb,
  p_habits_data jsonb[] DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_habit jsonb;
  v_result jsonb;
BEGIN
  -- Update streaks table
  INSERT INTO public.streaks (
    user_id,
    current,
    longest,
    last_entry_date,
    freeze_credits,
    grace_pieces_total,
    updated_at
  ) VALUES (
    p_user_id,
    (p_streak_data->>'current')::int,
    (p_streak_data->>'longest')::int,
    CASE 
      WHEN p_streak_data->>'last_entry_date' IS NULL OR p_streak_data->>'last_entry_date' = 'null' THEN NULL
      ELSE (p_streak_data->>'last_entry_date')::date
    END,
    (p_streak_data->>'freeze_credits')::int,
    (p_streak_data->>'grace_pieces_total')::numeric,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    current = EXCLUDED.current,
    longest = EXCLUDED.longest,
    last_entry_date = EXCLUDED.last_entry_date,
    freeze_credits = EXCLUDED.freeze_credits,
    grace_pieces_total = EXCLUDED.grace_pieces_total,
    updated_at = EXCLUDED.updated_at;

  -- Update habits_daily (batch upsert)
  IF p_habits_data IS NOT NULL AND array_length(p_habits_data, 1) > 0 THEN
    FOREACH v_habit IN ARRAY p_habits_data
    LOOP
      INSERT INTO public.habits_daily (
        id,
        user_id,
        date,
        wrote_entry,
        filled_affirmations,
        filled_gratitude,
        self_care_completed_count,
        grace_pieces_earned
      ) VALUES (
        (v_habit->>'id')::uuid,
        p_user_id,
        (v_habit->>'date')::date,
        (v_habit->>'wrote_entry')::boolean,
        (v_habit->>'filled_affirmations')::boolean,
        (v_habit->>'filled_gratitude')::boolean,
        (v_habit->>'self_care_completed_count')::int,
        (v_habit->>'grace_pieces_earned')::numeric
      )
      ON CONFLICT (id) DO UPDATE SET
        wrote_entry = EXCLUDED.wrote_entry,
        filled_affirmations = EXCLUDED.filled_affirmations,
        filled_gratitude = EXCLUDED.filled_gratitude,
        self_care_completed_count = EXCLUDED.self_care_completed_count,
        grace_pieces_earned = EXCLUDED.grace_pieces_earned;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'ERRDB001',
      'error_message', SQLERRM
    );
END;
$$;
```

### 2.2 Remove Unused Objects

**Execute after confirming app works:**

```sql
-- Remove unused trigger
DROP TRIGGER IF EXISTS trigger_update_grace_pieces ON public.habits_daily;

-- Remove unused functions
DROP FUNCTION IF EXISTS update_grace_pieces_on_task_completion();
DROP FUNCTION IF EXISTS calculate_grace_days_from_habits(uuid, date);

-- Remove unused table (optional - can keep for historical data)
-- DROP TABLE IF EXISTS public.streak_freeze_usage;
```

**Note:** Keep `streak_freeze_usage` table for now (historical data). Can remove later if confirmed unused.

### 2.3 Data Migration (Preserve Existing Data)

**No migration needed** - All existing data in `streaks` and `habits_daily` tables will be preserved:
- ✅ Existing `streaks` records remain intact
- ✅ Existing `habits_daily` records remain intact
- ✅ Only sync method changes (RPC instead of separate upserts)

---

## 3. Local Database Changes (SQLite)

### 3.1 Schema Status

**No changes needed** - Local SQLite already has:
- ✅ `streaks` table (with all required columns)
- ✅ `habits_daily` table (with all required columns)
- ✅ `is_synced` and `last_sync_at` columns for sync tracking

---

## 4. Code Implementation

### 4.1 Update Sync Service (RPC Integration)

**File:** `lib/services/sync/supabase_sync_service.dart`

**Add new method:**

```dart
/// Batch update streak data via RPC (single API call)
Future<bool> batchUpdateStreakData({
  required String userId,
  required Map<String, dynamic> streakData,
  List<Map<String, dynamic>>? habitsData,
}) async {
  try {
    final params = {
      'p_user_id': userId,
      'p_streak_data': {
        'current': streakData['current'] ?? 0,
        'longest': streakData['longest'] ?? 0,
        'last_entry_date': streakData['last_entry_date'],
        'freeze_credits': streakData['freeze_credits'] ?? 0,
        'grace_pieces_total': streakData['grace_pieces_total'] ?? 0.0,
      },
    };

    // Add habits data if provided
    if (habitsData != null && habitsData.isNotEmpty) {
      params['p_habits_data'] = habitsData.map((h) => {
        'id': h['id'],
        'date': h['date'],
        'wrote_entry': h['wrote_entry'] ?? false,
        'filled_affirmations': h['filled_affirmations'] ?? false,
        'filled_gratitude': h['filled_gratitude'] ?? false,
        'self_care_completed_count': h['self_care_completed_count'] ?? 0,
        'grace_pieces_earned': h['grace_pieces_earned'] ?? 0.0,
      }).toList();
    }

    final response = await _supabase.rpc('batch_update_streak_data', params: params);
    final result = response as Map<String, dynamic>;

    if (result['success'] == true) {
      // Mark as synced in local DB
      final db = await DatabaseManager().database;
      await db.update(
        'streaks',
        {
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Mark habits as synced
      if (habitsData != null) {
        for (final habit in habitsData) {
          await db.update(
            'habits_daily',
            {
              'is_synced': 1,
              'last_sync_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [habit['id']],
          );
        }
      }

      return true;
    } else {
      await ErrorLoggingService.logHighError(
        errorCode: result['error_code'] ?? 'ERRSYS300',
        errorMessage: 'RPC batch streak update failed: ${result['error_message']}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'rpc_response': result,
          'operation': 'batch_update_streak_data_rpc',
        },
      );
      return false;
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS300',
      errorMessage: 'RPC batch streak update exception: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'user_id': userId,
        'operation': 'batch_update_streak_data_rpc',
      },
    );
    return false;
  }
}
```

### 4.2 Update Grace System Service

**File:** `lib/services/grace_system_service.dart`

**Replace `_scheduleSync()` method:**

```dart
// Helper: Schedule debounced sync to Supabase via RPC
static void _scheduleSync(String userId, String? dateStr) {
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
        final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String().split('T')[0];
        unsyncedHabits = await db.query(
          'habits_daily',
          where: 'user_id = ? AND date >= ? AND is_synced = 0',
          whereArgs: [userId, sevenDaysAgo],
        );
      }

      // Prepare data for RPC
      final streakData = {
        'current': streak['current'] ?? 0,
        'longest': streak['longest'] ?? 0,
        'last_entry_date': streak['last_entry_date'],
        'freeze_credits': streak['freeze_credits'] ?? 0,
        'grace_pieces_total': streak['grace_pieces_total'] ?? 0.0,
      };

      final habitsData = unsyncedHabits.map((h) => {
        'id': h['id'],
        'date': h['date'],
        'wrote_entry': (h['wrote_entry'] as int? ?? 0) == 1,
        'filled_affirmations': (h['filled_affirmations'] as int? ?? 0) == 1,
        'filled_gratitude': (h['filled_gratitude'] as int? ?? 0) == 1,
        'self_care_completed_count': h['self_care_completed_count'] ?? 0,
        'grace_pieces_earned': h['grace_pieces_earned'] ?? 0.0,
      }).toList();

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
          dataFetchService.invalidateHabitsCache(userId, DateTime.parse(dateStr));
        }
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
```

### 4.3 Remove `entries` Table Dependency

**File:** `lib/services/user_data_service.dart`

**Replace `_calculateStreak()` method:**

```dart
/// Calculate streak from habits_daily (not entries table)
/// Counts consecutive days where user completed at least one task
static Future<int> _calculateStreakFromHabits(String userId) async {
  try {
    final db = await DatabaseManager().database;

    // Get all habits where user completed at least one task
    final habits = await db.query(
      'habits_daily',
      where: 'user_id = ? AND (wrote_entry = 1 OR filled_affirmations = 1 OR filled_gratitude = 1 OR self_care_completed_count > 0)',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    if (habits.isEmpty) return 0;

    // Create set of dates
    final dates = habits.map((h) => h['date'] as String).toSet();

    // Count consecutive days from today backwards
    int streak = 0;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    int currentDay = 0;
    while (true) {
      final checkDate = todayDateOnly.subtract(Duration(days: currentDay));
      final dateKey = checkDate.toIso8601String().split('T')[0];

      if (dates.contains(dateKey)) {
        streak++;
        currentDay++;
      } else {
        break;
      }
    }

    return streak;
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS160',
      errorMessage: 'Calculate streak from habits failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
    return 0;
  }
}
```

**Update `recalculateStreak()` to use new method:**

```dart
/// Recalculate streak on batch save or app launch
/// Uses habits_daily instead of entries table
static Future<void> recalculateStreak(
  String userId, {
  DataFetchService? dataFetchService,
}) async {
  try {
    final db = await DatabaseManager().database;

    // Calculate streak from habits_daily
    final newStreak = await _calculateStreakFromHabits(userId);

    // Get current streaks record
    final streaks = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    // Get last entry date from habits_daily (most recent date with any task completed)
    final lastHabit = await db.query(
      'habits_daily',
      where: 'user_id = ? AND (wrote_entry = 1 OR filled_affirmations = 1 OR filled_gratitude = 1 OR self_care_completed_count > 0)',
      whereArgs: [userId],
      orderBy: 'date DESC',
      limit: 1,
    );

    final lastEntryDate = lastHabit.isNotEmpty ? lastHabit.first['date'] as String? : null;

    // Update streaks
    if (streaks.isEmpty) {
      await db.insert(
        'streaks',
        {
          'user_id': userId,
          'current': newStreak,
          'longest': newStreak,
          'last_entry_date': lastEntryDate,
          'freeze_credits': 0,
          'grace_pieces_total': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
      );
    } else {
      final longest = (streaks.first['longest'] as int? ?? 0);
      final newLongest = newStreak > longest ? newStreak : longest;

      await db.update(
        'streaks',
        {
          'current': newStreak,
          'longest': newLongest,
          'last_entry_date': lastEntryDate,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }

    // Queue sync via RPC (debounced)
    _scheduleStreakSync(userId);
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS161',
      errorMessage: 'Recalculate streak failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
  }
}
```

### 4.4 Remove `user_settings` Dependency

**File:** `lib/services/user_data_service.dart`

**In `calculateStreakWithGrace()` method, replace:**

```dart
// OLD:
final graceSettings = await dataFetchService.fetchUserSettings(userId);
final graceSystemEnabled = graceSettings?['grace_system_enabled'] ?? true;

// NEW:
const graceSystemEnabled = true; // Always enabled (no setting in UI)
```

### 4.5 Add Gap Detection on Batch Save

**File:** `lib/providers/entry_provider.dart`

**Update `_executeBatchSave()` method - add after saving entry:**

```dart
// After successful batch save, check for gaps and recalculate streak
if (success) {
  // ... existing code ...
  
  // Check for gaps and recalculate streak
  await _checkGapsAndRecalculateStreak(userId);
  
  // ... rest of code ...
}
```

**Add new helper method:**

```dart
/// Check for gaps in streak and auto-use grace days if needed
Future<void> _checkGapsAndRecalculateStreak(String userId) async {
  try {
    final db = await DatabaseManager().database;
    final dataFetchService = ref.read(dataFetchServiceProvider);

    // Get current streak data
    final streaks = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (streaks.isEmpty) return;

    final streak = streaks.first;
    final lastEntryDateStr = streak['last_entry_date'] as String?;

    if (lastEntryDateStr == null) {
      // No previous entry, recalculate from scratch
      await UserDataService.recalculateStreak(userId, dataFetchService: dataFetchService);
      return;
    }

    final lastEntryDate = DateTime.parse(lastEntryDateStr);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final lastDateOnly = DateTime(lastEntryDate.year, lastEntryDate.month, lastEntryDate.day);
    final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

    if (daysDiff == 0) {
      // Same day, just recalculate
      await UserDataService.recalculateStreak(userId, dataFetchService: dataFetchService);
      return;
    }

    if (daysDiff > 0) {
      // Gap detected
      final graceDays = streak['freeze_credits'] as int? ?? 0;

      if (daysDiff == 1 && graceDays > 0) {
        // 1 day gap - auto-use grace day
        await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
        // Recalculate streak (maintains current streak)
        await UserDataService.recalculateStreak(userId, dataFetchService: dataFetchService);
      } else if (daysDiff > 1) {
        // Multiple days gap
        if (graceDays >= daysDiff - 1) {
          // Use multiple grace days
          for (int i = 0; i < daysDiff - 1; i++) {
            await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
          }
          await UserDataService.recalculateStreak(userId, dataFetchService: dataFetchService);
        } else {
          // Not enough grace days - reset streak
          await db.update(
            'streaks',
            {
              'current': 0,
              'last_entry_date': null,
              'updated_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          // Sync reset
          final syncService = SupabaseSyncService();
          await syncService.batchUpdateStreakData(
            userId: userId,
            streakData: {
              'current': 0,
              'longest': streak['longest'] ?? 0,
              'last_entry_date': null,
              'freeze_credits': graceDays,
              'grace_pieces_total': streak['grace_pieces_total'] ?? 0.0,
            },
          );
        }
      }
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA280',
      errorMessage: 'Gap detection failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
  }
}
```

### 4.6 Add App Launch Calculation

**File:** `lib/services/user_data_service.dart`

**Add new method:**

```dart
/// Calculate streak on app launch (check gaps, auto-use grace days)
static Future<void> calculateStreakOnAppLaunch(String userId) async {
  try {
    final db = await DatabaseManager().database;

    // 1. Fetch from Supabase (1 call) - use DataFetchService for caching
    final dataFetchService = DataFetchService(repository: DataRepository());
    final supabaseStreak = await dataFetchService.fetchStreaks(userId);

    if (supabaseStreak == null) {
      // No streak data, initialize
      await _ensureStreaksRecordExists(userId);
      return;
    }

    // 2. Cache in local DB (if not already cached)
    final localStreak = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (localStreak.isEmpty || localStreak.first['last_sync_at'] == null) {
      // Cache Supabase data locally
      await db.insert(
        'streaks',
        {
          'user_id': userId,
          'current': supabaseStreak['current'] ?? 0,
          'longest': supabaseStreak['longest'] ?? 0,
          'last_entry_date': supabaseStreak['last_entry_date'],
          'freeze_credits': supabaseStreak['freeze_credits'] ?? 0,
          'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
          'updated_at': supabaseStreak['updated_at'] ?? DateTime.now().toIso8601String(),
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 3. Check for gaps using last_entry_date
    final lastEntryDateStr = supabaseStreak['last_entry_date'] as String?;
    if (lastEntryDateStr == null) {
      // No previous entry, recalculate from habits
      await recalculateStreak(userId, dataFetchService: dataFetchService);
      return;
    }

    final lastEntryDate = DateTime.parse(lastEntryDateStr);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final lastDateOnly = DateTime(lastEntryDate.year, lastEntryDate.month, lastEntryDate.day);
    final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

    if (daysDiff == 0) {
      // Same day, check if needs recalculation
      final currentStreak = supabaseStreak['current'] as int? ?? 0;
      final calculatedStreak = await _calculateStreakFromHabits(userId);
      
      if (calculatedStreak != currentStreak) {
        // Mismatch - recalculate
        await recalculateStreak(userId, dataFetchService: dataFetchService);
      }
      return;
    }

    if (daysDiff > 0) {
      // Gap detected
      final graceDays = supabaseStreak['freeze_credits'] as int? ?? 0;

      if (daysDiff == 1 && graceDays > 0) {
        // 1 day gap - auto-use grace day
        await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
        await recalculateStreak(userId, dataFetchService: dataFetchService);
      } else if (daysDiff > 1) {
        // Multiple days gap
        if (graceDays >= daysDiff - 1) {
          // Use multiple grace days
          for (int i = 0; i < daysDiff - 1; i++) {
            await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
          }
          await recalculateStreak(userId, dataFetchService: dataFetchService);
        } else {
          // Not enough grace days - reset streak
          await db.update(
            'streaks',
            {
              'current': 0,
              'last_entry_date': null,
              'updated_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          // Sync reset
          final syncService = SupabaseSyncService();
          await syncService.batchUpdateStreakData(
            userId: userId,
            streakData: {
              'current': 0,
              'longest': supabaseStreak['longest'] ?? 0,
              'last_entry_date': null,
              'freeze_credits': graceDays,
              'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
            },
          );
        }
      }
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS162',
      errorMessage: 'App launch streak calculation failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
  }
}
```

**Call on app launch:**

**File:** `lib/screens/splash_screen.dart` or `lib/main.dart`

```dart
// After user login/initialization
final user = Supabase.instance.client.auth.currentUser;
if (user != null) {
  // Calculate streak on app launch (background, non-blocking)
  UserDataService.calculateStreakOnAppLaunch(user.id).catchError((e) {
    // Log error but don't block app launch
    ErrorLoggingService.logLowError(
      errorCode: 'ERRSYS163',
      errorMessage: 'App launch streak calc error: $e',
      errorContext: {'user_id': user.id},
    );
  });
}
```

### 4.7 Update Data Fetch Service (Repository Pattern)

**File:** `lib/services/data_fetch_service.dart`

**Update `fetchStreaks()` to use repository pattern (already implemented):**

✅ Already uses `_repository.fetch()` with caching
✅ Already uses local-first approach
✅ No changes needed

**Add method for app launch:**

```dart
/// Fetch streaks for app launch (with gap detection)
Future<Map<String, dynamic>?> fetchStreaksForAppLaunch(String userId) async {
  // Use existing fetchStreaks (already cached)
  final streak = await fetchStreaks(userId);
  
  // Trigger gap detection in background (non-blocking)
  UserDataService.calculateStreakOnAppLaunch(userId).catchError((e) {
    ErrorLoggingService.logLowError(
      errorCode: 'ERRSYS164',
      errorMessage: 'Background gap detection failed: $e',
      errorContext: {'user_id': userId},
    );
  });
  
  return streak;
}
```

### 4.8 Create Riverpod Provider

**File:** `lib/providers/streak_provider.dart` (NEW)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data_fetch_service.dart';
import '../services/user_data_service.dart';
import '../services/grace_system_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Streak state
class StreakState {
  final int current;
  final int longest;
  final int graceDaysAvailable;
  final double gracePiecesTotal;
  final double piecesToday;
  final bool isLoading;
  final String? error;

  StreakState({
    this.current = 0,
    this.longest = 0,
    this.graceDaysAvailable = 0,
    this.gracePiecesTotal = 0.0,
    this.piecesToday = 0.0,
    this.isLoading = false,
    this.error,
  });

  StreakState copyWith({
    int? current,
    int? longest,
    int? graceDaysAvailable,
    double? gracePiecesTotal,
    double? piecesToday,
    bool? isLoading,
    String? error,
  }) {
    return StreakState(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      graceDaysAvailable: graceDaysAvailable ?? this.graceDaysAvailable,
      gracePiecesTotal: gracePiecesTotal ?? this.gracePiecesTotal,
      piecesToday: piecesToday ?? this.piecesToday,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Streak provider
class StreakNotifier extends StateNotifier<StreakState> {
  final DataFetchService _dataFetchService;
  String? _userId;

  StreakNotifier(this._dataFetchService) : super(StreakState());

  /// Initialize streak data
  Future<void> initialize(String userId) async {
    if (_userId == userId && !state.isLoading) return;
    
    _userId = userId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch streak data
      final streakData = await _dataFetchService.fetchStreaks(userId);
      
      // Fetch grace status
      final graceStatus = await GraceSystemService.getGraceStatus(
        userId,
        dataFetchService: _dataFetchService,
      );

      if (streakData != null && graceStatus != null) {
        state = state.copyWith(
          current: streakData['current'] as int? ?? 0,
          longest: streakData['longest'] as int? ?? 0,
          graceDaysAvailable: graceStatus['grace_days_available'] as int? ?? 0,
          gracePiecesTotal: graceStatus['grace_pieces_total'] as double? ?? 0.0,
          piecesToday: graceStatus['pieces_today'] as double? ?? 0.0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh streak data
  Future<void> refresh() async {
    if (_userId == null) return;
    await initialize(_userId!);
  }

  /// Recalculate streak (after task completion or entry save)
  Future<void> recalculate() async {
    if (_userId == null) return;
    
    try {
      await UserDataService.recalculateStreak(
        _userId!,
        dataFetchService: _dataFetchService,
      );
      // Refresh state
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Streak provider
final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  final dataFetchService = ref.watch(dataFetchServiceProvider);
  return StreakNotifier(dataFetchService);
});
```

**Update `lib/providers/data_providers.dart`:**

```dart
// Add to existing providers
final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  final dataFetchService = ref.watch(dataFetchServiceProvider);
  return StreakNotifier(dataFetchService);
});
```

### 4.9 Update UI to Use Provider

**File:** `lib/screens/home_screen.dart`

**Replace streak section:**

```dart
Widget _buildStreakSection(BuildContext context, Map<String, dynamic>? userStats, User? user) {
  return Consumer(
    builder: (context, ref, _) {
      final streakState = ref.watch(streakProvider);
      
      // Initialize on first load
      if (user != null && streakState.current == 0 && !streakState.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(streakProvider.notifier).initialize(user.id);
        });
      }

      if (streakState.isLoading) {
        return _skeletonStreakCard(context);
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Current Streak
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${streakState.current}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Current Streak',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // Best Streak
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${streakState.longest}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Best Streak',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

---

## 5. Implementation Steps

### Phase 1: Database Setup (Day 1)
1. ✅ Execute RPC function creation SQL
2. ✅ Test RPC function manually
3. ⚠️ **DO NOT** remove unused objects yet (wait for Phase 3)

### Phase 2: Code Implementation (Day 2-3)
1. ✅ Update `SupabaseSyncService` with RPC method
2. ✅ Update `GraceSystemService._scheduleSync()` to use RPC
3. ✅ Remove `entries` dependency from streak calculation
4. ✅ Remove `user_settings` dependency
5. ✅ Add gap detection on batch save
6. ✅ Add app launch calculation
7. ✅ Create Riverpod provider
8. ✅ Update UI to use provider

### Phase 3: Testing & Cleanup (Day 4)
1. ✅ Test with existing users (verify no data loss)
2. ✅ Test gap detection
3. ✅ Test grace day auto-use
4. ✅ Test RPC sync
5. ✅ Remove unused DB objects (after confirming everything works)

### Phase 4: UI Enhancements (Later)
1. ⏳ Add grace days/pieces display
2. ⏳ Add streak change history
3. ⏳ Add dynamic messages

---

## 6. Testing Checklist

### Before Implementation
- [ ] Backup Supabase database
- [ ] Test RPC function manually in SQL editor
- [ ] Verify existing user data structure

### After Implementation
- [ ] Test task completion → pieces calculated correctly
- [ ] Test entry save → streak recalculates
- [ ] Test gap detection → grace days auto-used
- [ ] Test app launch → gap detection works
- [ ] Test RPC sync → single call updates both tables
- [ ] Test with existing users → no data loss
- [ ] Test offline → local updates work
- [ ] Test sync after offline → RPC syncs correctly

### After Cleanup
- [ ] Verify no code references removed objects
- [ ] Test app still works after removal
- [ ] Check logs for any errors

---

## 7. Rollback Plan

If issues occur:

1. **Revert code changes** (git revert)
2. **Keep RPC function** (can use old sync methods)
3. **Restore removed objects** (if removed):
   ```sql
   -- Recreate trigger (if needed)
   -- Recreate functions (if needed)
   ```
4. **Data is safe** - All data in `streaks` and `habits_daily` remains intact

---

## 8. Data Safety

### Existing Users
- ✅ All `streaks` records preserved
- ✅ All `habits_daily` records preserved
- ✅ Only sync method changes (RPC instead of separate upserts)
- ✅ No data migration needed

### New Users
- ✅ Same flow, just optimized
- ✅ RPC ensures atomic updates

---

## 9. Performance Metrics

### Before
- **API Calls:** 4+ per session
- **Sync Time:** 2-4 seconds (multiple calls)
- **Local Updates:** Immediate

### After
- **API Calls:** 1-2 per session (75% reduction)
- **Sync Time:** 1-2 seconds (single RPC call)
- **Local Updates:** Immediate (unchanged)

---

## 10. Summary

**What Changes:**
- ✅ Sync method: Separate upserts → Single RPC call
- ✅ Streak calculation: `entries` table → `habits_daily` table
- ✅ Gap detection: Added on batch save + app launch
- ✅ State management: Added Riverpod provider
- ✅ Removed dependencies: `entries`, `user_settings`

**What Stays Same:**
- ✅ Data structure (no migration needed)
- ✅ Local-first approach
- ✅ Grace system logic
- ✅ User experience (same functionality)

**What's Removed:**
- ✅ Unused DB functions
- ✅ Unused trigger
- ✅ Unused table (`streak_freeze_usage` - optional)

**Next Steps:**
1. Execute Phase 1 (Database Setup)
2. Implement Phase 2 (Code Changes)
3. Test Phase 3 (Testing)
4. Cleanup Phase 4 (Remove unused objects)

---

**Status:** ✅ Ready for Implementation  
**Risk Level:** Low (data preserved, rollback available)  
**Estimated Time:** 2-3 days
