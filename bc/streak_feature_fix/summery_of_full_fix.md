# Streak Feature Fix - Complete Summary Report

## 📋 Session Overview
This document summarizes all fixes and improvements made to the streak feature during this session. The main focus was fixing streak reset issues on app restart and ensuring proper synchronization between local DB and Supabase.

---

## 🐛 Problems Identified & Fixed

### 1. **Streak Resetting to 1 on App Restart**
**Problem:**
- User manually set streak to 5, but on app restart it reset to 1
- Root cause: `_fetchUserStats()` was calling `_persistStreak()` which wrote to DB during read-only stats fetch
- This happened on splash screen before `calculateStreakOnAppLaunch()` could run

**Fix:**
- Removed `_persistStreak()` call from `_fetchUserStats()` method
- `_fetchUserStats()` is now READ-ONLY (only reads data, never writes)
- Added comment clarifying this method should not persist data

**Files Changed:**
- `lib/services/user_data_service.dart` (line ~335-339)

---

### 2. **App Showing Wrong Streak Value (1) While DB Had Correct Value (5)**
**Problem:**
- Supabase DB had correct value (5), but app displayed 1
- Root cause: `loadUserData()` was called BEFORE `calculateStreakOnAppLaunch()`
- This caused old cached value to be loaded into provider state

**Fix:**
- Reordered operations in `splash_screen.dart`:
  1. `calculateStreakOnAppLaunch()` runs FIRST
  2. Invalidate streaks and home summary caches
  3. Then `loadUserData()` runs (reads updated value)

**Files Changed:**
- `lib/screens/splash_screen.dart` (lines ~109-115)

---

### 3. **Manual Supabase Updates Not Reflecting in App**
**Problem:**
- User manually set streak to 6 in Supabase, but app showed 5
- Root cause: `fetchStreaks()` was returning cached local data (within 15 min) instead of fetching from Supabase
- Local DB had old value (5) with recent `last_sync_at` timestamp

**Fix:**
- Added cache invalidation before fetching in `calculateStreakOnAppLaunch()`
- Set `last_sync_at` to `null` in local DB to force fresh Supabase fetch
- This ensures app always gets latest data from Supabase on launch

**Files Changed:**
- `lib/services/user_data_service.dart` (lines ~876-884)

---

### 4. **Longest Streak Not Updating When Current > Longest**
**Problem:**
- User manually set `current: 9` but `longest` remained at 6
- Root cause: When `daysDiff == 0` (same day), code trusted Supabase and skipped all updates
- No logic to check if `current > longest` and update accordingly

**Fix:**
- Added check in `calculateStreakOnAppLaunch()`:
  - If `current > longest`, update `longest` to match `current`
  - Update local DB
  - Sync updated `longest` back to Supabase via RPC

**Files Changed:**
- `lib/services/user_data_service.dart` (lines ~1123-1165)

---

## 🔧 Code Changes Summary

### File: `lib/services/user_data_service.dart`

#### Change 1: Removed Write Operation from Read-Only Method
**Location:** `_fetchUserStats()` method (~line 335-339)

**Before:**
```dart
// Persist streak counters to DB so Home can read from streaks table
await _persistStreak(
  userId,
  streak,
  lastEntryIso: lastEntryDate,
);
```

**After:**
```dart
// Note: This method is READ-ONLY for stats display
// Do NOT persist/write streak data here - writing should only happen when:
// 1. User completes tasks (trackTaskCompletion)
// 2. Gap detected and handled (calculateStreakOnAppLaunch)
// 3. Streak recalculation needed (recalculateStreak after entry save)
```

**Impact:** Prevents streak from being overwritten during stats fetch on app launch

---

#### Change 2: Force Fresh Fetch from Supabase on App Launch
**Location:** `calculateStreakOnAppLaunch()` method (~line 876-884)

**Added:**
```dart
// 2. Fetch streaks from Supabase (1 call)
// Invalidate cache first to ensure we get fresh data from Supabase (not cached local)
dataFetchService.invalidateStreaksCache(userId);
// Also invalidate local DB's last_sync_at to force fresh fetch
await db.update(
  'streaks',
  {'last_sync_at': null},
  where: 'user_id = ?',
  whereArgs: [userId],
);
print('🔥 STREAK DEBUG: Fetching streaks from Supabase...');
final supabaseStreak = await dataFetchService.fetchStreaks(userId);
```

**Impact:** Ensures app always fetches latest data from Supabase, not stale cached local data

---

#### Change 3: Auto-Update Longest When Current > Longest
**Location:** `calculateStreakOnAppLaunch()` method (~line 1123-1165)

**Added:**
```dart
if (daysDiff == 0) {
  // Same day - trust current streak from Supabase (don't recalculate)
  // BUT: If current > longest, update longest to match current (handles manual updates)
  final currentStreak = supabaseStreak['current'] as int? ?? 0;
  final longestStreak = supabaseStreak['longest'] as int? ?? 0;
  
  if (currentStreak > longestStreak) {
    // Update longest to match current
    await db.update('streaks', {...});
    // Sync updated longest to Supabase
    await _syncService.batchUpdateStreakData(...);
  }
}
```

**Impact:** Automatically updates `longest` when `current` exceeds it (handles manual DB updates)

---

### File: `lib/screens/splash_screen.dart`

#### Change: Reordered Operations for Correct Data Flow
**Location:** `_initializeApp()` method (~line 109-115)

**Before:**
```dart
await ref.read(userDataProvider.notifier).loadUserData();
await UserDataService.calculateStreakOnAppLaunch(user.id);
```

**After:**
```dart
// Calculate streak on app launch FIRST (check gaps, auto-use grace days)
// This must run before loadUserData() so the updated streak value is available
await UserDataService.calculateStreakOnAppLaunch(user.id);

// Invalidate caches to ensure fresh data is read
final dataFetchService = ref.read(dataFetchServiceProvider);
dataFetchService.invalidateStreaksCache(user.id);
dataFetchService.invalidateHomeSummaryCache(user.id);

// Use the global provider to load user data (will now read updated streak value)
await ref.read(userDataProvider.notifier).loadUserData();
```

**Impact:** Ensures streak calculation completes before loading user data, so correct values are displayed

---

## 📊 Data Flow After Fixes

### App Launch Flow (Splash Screen)
1. **Calculate Streak First**
   - Invalidate streaks cache
   - Set `last_sync_at = null` in local DB
   - Fetch fresh data from Supabase
   - Check for gaps, handle grace days
   - Update `longest` if `current > longest`
   - Sync any changes to Supabase

2. **Invalidate Caches**
   - Invalidate streaks cache
   - Invalidate home summary cache

3. **Load User Data**
   - Fetch user data (reads updated streak from local DB)
   - Display correct streak value in UI

### Streak Update Flow (When User Completes Tasks)
1. **Track Task Completion**
   - `trackTaskCompletion()` called
   - Updates local `habits_daily` table
   - Calculates new streak via `calculateStreakWithGrace()`

2. **Persist Streak**
   - `_persistStreak()` updates local DB
   - Compares `current` with `longest`, updates if needed
   - Marks as unsynced

3. **Sync to Supabase**
   - Debounced sync (via `_scheduleStreakSync()`)
   - RPC call to `batch_update_streak_data`
   - Marks as synced after success

---

## ✅ Best Streak (Longest) Calculation Logic

### How It Works
1. **When Streak Increases:**
   - `_persistStreak()` compares `computedStreak` with existing `longest`
   - If `computedStreak > longest`, updates `longest` to `computedStreak`
   - Syncs to Supabase

2. **When Streak Resets:**
   - `longest` is preserved (not overwritten)
   - Only `current` is reset to 0
   - `longest` remains at its highest value

3. **When Manual Update:**
   - On app launch, checks if `current > longest`
   - If yes, updates `longest` to match `current`
   - Syncs back to Supabase

### Code Location
- `_persistStreak()` method: Lines ~580-605
- `calculateStreakOnAppLaunch()` method: Lines ~1123-1165

---

## 🔍 Key Methods & Their Roles

### `_fetchUserStats()`
- **Purpose:** READ-ONLY method to fetch user statistics
- **Role:** Only reads data, never writes
- **Called from:** `fetchUserData()` → `loadUserData()`
- **Important:** Must NOT call `_persistStreak()` (was causing reset bug)

### `calculateStreakOnAppLaunch()`
- **Purpose:** Calculate and sync streak on app startup
- **Role:** 
  - Fetches fresh data from Supabase
  - Checks for gaps, handles grace days
  - Updates `longest` if `current > longest`
  - Syncs changes to Supabase
- **Called from:** `splash_screen.dart` (BEFORE `loadUserData()`)

### `_persistStreak()`
- **Purpose:** Persist computed streak to local DB
- **Role:**
  - Updates `current` and `longest` in local DB
  - Compares and updates `longest` if needed
  - Schedules sync to Supabase
- **Called from:** `calculateStreakWithGrace()` (when user completes tasks)

### `fetchStreaks()`
- **Purpose:** Fetch streak data (local-first with Supabase fallback)
- **Role:**
  - Returns cached local data if fresh (< 15 min, same day)
  - Otherwise fetches from Supabase
  - Caches Supabase response locally
- **Called from:** `calculateStreakOnAppLaunch()`, `_getCurrentStreak()`

---

## 🎯 Testing Scenarios Covered

### ✅ Scenario 1: Normal App Restart
- **Test:** User has streak 5, restarts app
- **Expected:** Streak remains 5
- **Status:** ✅ Fixed

### ✅ Scenario 2: Manual Supabase Update
- **Test:** User manually sets streak to 6 in Supabase, restarts app
- **Expected:** App shows 6
- **Status:** ✅ Fixed

### ✅ Scenario 3: Current > Longest
- **Test:** User manually sets `current: 9` when `longest: 6`, restarts app
- **Expected:** `longest` updates to 9
- **Status:** ✅ Fixed

### ✅ Scenario 4: Best Streak Preservation
- **Test:** User has `current: 3, longest: 10`, streak resets to 0
- **Expected:** `longest` remains 10
- **Status:** ✅ Working (already implemented)

---

## 📝 Important Notes

### Cache Invalidation Strategy
- **On App Launch:** Always invalidate streaks cache to force fresh fetch
- **After Updates:** Cache is automatically updated with new data
- **Time-based Staleness:** Local cache is considered fresh if synced within 15 minutes

### Data Synchronization
- **Local-First Approach:** All operations write to local DB first
- **Debounced Sync:** Changes are batched and synced to Supabase after 2 seconds
- **RPC Method:** Uses `batch_update_streak_data` RPC for atomic updates

### Manual Database Updates
- **Supported:** Manual updates to Supabase are now properly handled
- **Auto-Correction:** App automatically fixes inconsistencies (e.g., `current > longest`)
- **Sync Back:** Manual updates are synced back to local DB on app launch

---

## 🚨 Remaining Considerations

### Future Improvements
1. **Cache Strategy:** Consider reducing 15-minute cache window for more real-time updates
2. **Conflict Resolution:** Add logic to handle conflicts when both local and Supabase have unsynced changes
3. **Offline Support:** Ensure streak calculations work correctly when offline

### Known Limitations
1. **Manual Updates:** Manual Supabase updates require app restart to reflect (by design)
2. **Cache Window:** 15-minute cache window means updates might not be immediate
3. **Same-Day Logic:** Same-day updates skip recalculation (trusts Supabase value)

---

## 📚 Related Files

### Core Files Modified
- `lib/services/user_data_service.dart` - Main streak calculation logic
- `lib/screens/splash_screen.dart` - App launch flow

### Supporting Files (Not Modified in This Session)
- `lib/services/grace_system_service.dart` - Grace system logic
- `lib/services/data_fetch_service.dart` - Data fetching and caching
- `lib/services/sync/supabase_sync_service.dart` - Supabase synchronization
- `lib/models/analytics_models.dart` - Streak data models

---

## ✨ Summary

This session fixed critical bugs in the streak feature:
1. ✅ Fixed streak resetting to 1 on app restart
2. ✅ Fixed app showing wrong value when DB had correct value
3. ✅ Fixed manual Supabase updates not reflecting in app
4. ✅ Fixed longest streak not updating when current > longest

All fixes maintain the local-first architecture while ensuring proper synchronization with Supabase. The streak feature now correctly handles:
- Normal app restarts
- Manual database updates
- Best streak calculation and preservation
- Proper cache invalidation and data flow

---

**Last Updated:** 2026-01-20
**Session Status:** ✅ All fixes implemented and tested
