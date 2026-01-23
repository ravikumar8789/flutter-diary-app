# Streak Feature Startup Optimization Plan

## 🎯 Objective
Remove conditional fetching and always fetch both `streaks` and `habits_daily` tables on app startup, ensuring accurate streak calculation by having all required data in local DB before calculation.

---

## 📋 Current Problem

**Current Flow:**
1. `calculateStreakOnAppLaunch()` runs first
   - Fetches streaks (1 call)
   - Calls `_calculateStreakFromHabits()` → reads local DB (may be empty)
2. Then checks `needsFetch` flag
   - If `true`: prefetch 7 days (entries + habits + streaks = 3 calls)
   - If `false`: no fetch → local DB empty → wrong calculation

**Issue:** Calculating before fetching data → inaccurate results

---

## ✅ Optimized Flow

**New Flow:**
1. **Always fetch both tables first** (2 calls)
   - Fetch `streaks` (1 call)
   - Fetch `habits_daily` last 30 days (1 call)
2. **Cache in local DB**
3. **Then calculate** from local DB (accurate)
4. **Update locally**
5. **Push via RPC** (if changes)
6. **Show updated data** (already reading from local DB)

---

## 🔧 Implementation Changes

### 1. Update `calculateStreakOnAppLaunch()`

**File:** `lib/services/user_data_service.dart`

**Changes:**
- Remove all conditional logic
- Always fetch `streaks` (1 call)
- Always fetch `habits_daily` last 30 days (1 call)
- Cache both in local DB
- Then calculate from local DB
- Update locally if needed
- Push via RPC if changes

**New Flow:**
```dart
static Future<void> calculateStreakOnAppLaunch(String userId) async {
  try {
    final db = await DatabaseManager().database;
    final dataFetchService = DataFetchService(repository: DataRepository());

    // 1. ALWAYS fetch streaks (1 call)
    final supabaseStreak = await dataFetchService.fetchStreaks(userId);
    
    if (supabaseStreak == null) {
      await _ensureStreaksRecordExists(userId);
      return;
    }

    // 2. ALWAYS fetch habits_daily last 30 days (1 call)
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 30));
    await dataFetchService.fetchHabitsDaily(
      userId: userId,
      startDate: startDate,
      endDate: today,
    );

    // 3. Cache streaks in local DB (if not already cached)
    final localStreak = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (localStreak.isEmpty || localStreak.first['last_sync_at'] == null) {
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

    // 4. NOW calculate from local DB (has all data)
    final lastEntryDateStr = supabaseStreak['last_entry_date'] as String?;
    if (lastEntryDateStr == null) {
      await recalculateStreak(userId, dataFetchService: dataFetchService);
      return;
    }

    final lastEntryDate = DateTime.parse(lastEntryDateStr);
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final lastDateOnly = DateTime(lastEntryDate.year, lastEntryDate.month, lastEntryDate.day);
    final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

    if (daysDiff == 0) {
      // Same day - recalculate to ensure accuracy
      final currentStreak = supabaseStreak['current'] as int? ?? 0;
      final calculatedStreak = await _calculateStreakFromHabits(userId);

      if (calculatedStreak != currentStreak) {
        await recalculateStreak(userId, dataFetchService: dataFetchService);
      }
      return;
    }

    if (daysDiff > 0) {
      // Gap detected - handle with grace days
      final graceDays = supabaseStreak['freeze_credits'] as int? ?? 0;

      if (daysDiff == 1 && graceDays > 0) {
        await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
        await recalculateStreak(userId, dataFetchService: dataFetchService);
      } else if (daysDiff > 1) {
        if (graceDays >= daysDiff - 1) {
          for (int i = 0; i < daysDiff - 1; i++) {
            await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
          }
          await recalculateStreak(userId, dataFetchService: dataFetchService);
        } else {
          // Reset streak
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
          await _syncService.batchUpdateStreakData(
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

---

### 2. Remove Conditional Prefetch (Optional)

**File:** `lib/screens/splash_screen.dart`

**Note:** The `needsFetch` prefetch logic can remain for entries (7 days), but streak calculation now always has data.

**No changes needed** - streak calculation is independent and now always fetches its own data.

---

## 📊 API Calls Summary

### Before (Conditional):
- **Normal restart:** 1 call (streaks only) → wrong calculation
- **After logout:** 4 calls (streaks + prefetch 7 days)

### After (Always Fetch):
- **Every startup:** 2 calls (streaks + habits_daily last 30 days)
- **Consistent, accurate, simple**

---

## ✅ Benefits

1. **Accurate Calculation:** Local DB always has required data
2. **Simple Logic:** No conditions, always same flow
3. **Consistent:** Works for all scenarios (fresh install, normal restart, after logout)
4. **Low Cost:** Only 2 calls on startup (cheap for new users, returns minimal data)
5. **No Breaking Changes:** Existing flow remains, just ensures data is fetched first

---

## ⚠️ Impact Analysis

### ✅ No Breaking Changes:
- `_calculateStreakFromHabits()` still reads from local DB (now has data)
- `recalculateStreak()` still works (now has data)
- RPC sync still works (unchanged)
- UI still reads from local DB (unchanged)
- Grace system still works (unchanged)

### ✅ Other Functionalities Unaffected:
- Entry saving flow (unchanged)
- Batch save RPC (unchanged)
- Grace pieces tracking (unchanged)
- Home screen display (unchanged)
- Streak provider (unchanged)

---

## 🧪 Testing Checklist

- [ ] Fresh install: Streak initializes correctly
- [ ] Normal restart: Streak calculates accurately
- [ ] After logout/login: Streak syncs correctly
- [ ] Gap detection: Grace days used correctly
- [ ] No activity for 10 days: Streak resets correctly
- [ ] Active user: Streak increments correctly
- [ ] Local DB: Always has required data
- [ ] RPC sync: Pushes changes correctly
- [ ] UI: Shows updated data correctly

---

## 📝 Notes

- **30 days range:** Covers most streaks (can adjust if needed)
- **DataFetchService caching:** Already handles deduplication
- **Local-first:** Still updates local first, syncs via RPC
- **Error handling:** Existing error handling remains
- **Performance:** 2 calls is acceptable for startup (parallel if possible)

---

## 🚀 Implementation Order

1. Update `calculateStreakOnAppLaunch()` to always fetch both tables
2. Test fresh install scenario
3. Test normal restart scenario
4. Test gap detection scenarios
5. Verify RPC sync works
6. Verify UI shows correct data

---

**Status:** Ready for implementation
**Priority:** High (fixes inaccurate streak calculation)
**Risk:** Low (no breaking changes, just ensures data is fetched first)
