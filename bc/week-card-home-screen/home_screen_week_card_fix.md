# Home Screen Week Cards Fix - Implementation Plan

**Date:** December 2024  
**Feature:** Calculate Current Week Stats from Local Database  
**Issue:** 4 cards under "This Week" showing no data

---

## 🎯 OBJECTIVE

Fix the 4 metric cards on Home Screen ("This Week" section) to show current week statistics by calculating from local database instead of relying on `weekly_insights` table (which only stores past weeks).

---

## 📊 CURRENT SITUATION

### Problem
- `homeSummaryProvider` → `HomeSummaryService._fetchWeeklySnapshot()` 
- Currently fetches from `weekly_insights` table
- `weekly_insights` only stores **completed past weeks**
- Current week returns `null` → No data shown in cards

### Cards Affected
1. **Avg Mood** - Should show average mood for current week
2. **Water Intake** - Should show average water cups/day for current week
3. **Self-Care %** - Should show self-care completion percentage
4. **Consistency** - Should show entries count / days elapsed

---

## ✅ SOLUTION APPROACH

### Strategy
- **Skip `weekly_insights` table check** (only has past weeks)
- **Directly calculate from local SQLite database**
- Use `LocalEntryService.getEntriesInRange()` to fetch current week entries
- Calculate all 4 metrics on-the-fly

### Calculation Logic
**Divide by days elapsed (not days with data)** - Shows impact of missing days

1. **Avg Mood**: `sum(mood_scores) / daysElapsed`
2. **Water Intake**: `sum(water_cups) / daysElapsed`
3. **Self-Care %**: `sum(self_care_count) / (daysElapsed × 10)`
4. **Consistency**: `entriesCount / daysElapsed`

---

## 🔧 IMPLEMENTATION DETAILS

### Step 1: Modify `HomeSummaryService._fetchWeeklySnapshot()`

**File:** `lib/services/home_summary_service.dart`

**Changes:**
- Remove `weekly_insights` table query
- Call new method: `_calculateCurrentWeekFromLocal()`
- Return calculated `WeeklySnapshotSummary`

**Code Structure:**
```dart
Future<WeeklySnapshotSummary?> _fetchWeeklySnapshot(
  String userId,
  DateTime thisWeekStart,
  DateTime prevWeekStart,
) async {
  try {
    // Skip weekly_insights check - directly calculate from local
    return await _calculateCurrentWeekFromLocal(userId, thisWeekStart);
  } catch (e) {
    // Error logging
  }
}
```

---

### Step 2: Add New Method `_calculateCurrentWeekFromLocal()`

**File:** `lib/services/home_summary_service.dart`

**Add Import:**
```dart
import '../services/database/local_entry_service.dart';
import '../models/entry_models.dart';
```

**Method Signature:**
```dart
Future<WeeklySnapshotSummary?> _calculateCurrentWeekFromLocal(
  String userId,
  DateTime weekStart,
) async
```

**Implementation Steps:**

1. **Calculate days elapsed:**
   ```dart
   final today = DateTime.now();
   final todayOnly = DateTime(today.year, today.month, today.day);
   final weekStartOnly = DateTime(weekStart.year, weekStart.month, weekStart.day);
   final daysElapsed = todayOnly.difference(weekStartOnly).inDays + 1;
   ```

2. **Get current week entries from local DB:**
   ```dart
   final localService = LocalEntryService();
   final weekEnd = todayOnly; // Only up to today
   final entries = await localService.getEntriesInRange(
     userId,
     weekStartOnly,
     weekEnd,
   );
   ```

3. **Fetch related data for each entry:**
   - For each entry, get:
     - `mood_score` from `entries` table
     - `water_cups` from `entry_meals` table (via `LocalEntryService.getMeals()`)
     - `self_care_count` from `entry_self_care` table (via `LocalEntryService.getSelfCare()`)

4. **Calculate metrics:**
   ```dart
   // Avg Mood
   double? moodAvg;
   final moodScores = entries
       .where((e) => e.moodScore != null)
       .map((e) => e.moodScore!.toDouble())
       .toList();
   if (moodScores.isNotEmpty) {
     final sum = moodScores.reduce((a, b) => a + b);
     moodAvg = sum / daysElapsed; // Divide by days elapsed
   }
   
   // Water Intake
   double cupsAvg = 0.0;
   int totalCups = 0;
   int cupsDaysCount = 0;
   for (final entry in entries) {
     final meals = await localService.getMeals(entry.id);
     if (meals != null && meals.waterCups > 0) {
       totalCups += meals.waterCups;
       cupsDaysCount++;
     }
   }
   cupsAvg = daysElapsed > 0 ? totalCups / daysElapsed : 0.0;
   
   // Self-Care %
   double selfCareRate = 0.0;
   int totalSelfCareCount = 0;
   for (final entry in entries) {
     final selfCare = await localService.getSelfCare(entry.id);
     if (selfCare != null) {
       // Count completed self-care items (10 max)
       totalSelfCareCount += _countSelfCareItems(selfCare);
     }
   }
   selfCareRate = daysElapsed > 0 
       ? totalSelfCareCount / (daysElapsed * 10) 
       : 0.0;
   
   // Consistency
   final consistency = daysElapsed > 0 
       ? entries.length / daysElapsed 
       : 0.0;
   ```

6. **Return WeeklySnapshotSummary:**
   ```dart
   if (entries.isEmpty) return null; // No data
   
   return WeeklySnapshotSummary(
     moodAvg: moodAvg,
     cupsAvg: cupsAvg,
     selfCareRate: selfCareRate.clamp(0.0, 1.0),
     topTopics: null, // Not calculated from local
     highlights: null, // Not calculated from local
     moodDelta: null, // Not calculated (would need prev week)
     consistency: consistency.clamp(0.0, 1.0),
   );
   ```

5. **Handle edge cases:**
   - No entries: Return `null` (will show "—" in UI)
   - Day 1: Divide by 1
   - Partial week: Divide by days elapsed (not 7)

---

### Step 3: Add Helper Method `_countSelfCareItems()`

**File:** `lib/services/home_summary_service.dart`

**Purpose:** Count completed self-care items from `EntrySelfCare` model

**Implementation:**
```dart
int _countSelfCareItems(EntrySelfCare selfCare) {
  int count = 0;
  if (selfCare.sleep) count++;
  if (selfCare.getUpEarly) count++;
  if (selfCare.freshAir) count++;
  if (selfCare.learnNew) count++;
  if (selfCare.balancedDiet) count++;
  if (selfCare.podcast) count++;
  if (selfCare.meMoment) count++;
  if (selfCare.hydrated) count++;
  if (selfCare.readBook) count++;
  if (selfCare.exercise) count++;
  return count; // Returns 0-10
}
```

---

### Step 4: Add Error Logging

**File:** `lib/services/home_summary_service.dart`

**Error Handling:**
```dart
try {
  // Calculation logic
} catch (e, stackTrace) {
  await ErrorLoggingService.logError(
    errorCode: 'ERRSYS155',
    errorMessage: 'Current week calculation from local DB failed: ${e.toString()}',
    stackTrace: stackTrace.toString(),
    severity: 'MEDIUM',
    errorContext: {
      'operation': 'home_summary_calculateCurrentWeek',
      'user_id': userId,
      'week_start': weekStart.toIso8601String(),
      'days_elapsed': daysElapsed,
    },
  );
  return null; // Graceful degradation - show no data
}
```

---

### Step 5: Update `WeeklySnapshotSummary` Model

**File:** `lib/models/home_summary_models.dart`

**Add `consistency` field:**
- Currently missing from model
- Add: `final num? consistency;`
- Update constructor to include consistency

**Updated Model:**
```dart
class WeeklySnapshotSummary {
  final num? moodAvg;
  final num? cupsAvg;
  final num? selfCareRate;
  final List<dynamic>? topTopics;
  final String? highlights;
  final num? moodDelta;
  final num? consistency; // NEW - entries count / days elapsed
  const WeeklySnapshotSummary({
    this.moodAvg,
    this.cupsAvg,
    this.selfCareRate,
    this.topTopics,
    this.highlights,
    this.moodDelta,
    this.consistency, // NEW
  });
}
```

---

### Step 6: Update Home Screen to Use Calculated Consistency

**File:** `lib/screens/home_screen.dart`

**Current (hardcoded):**
```dart
_buildWeekMetricCard(
  context, 
  '100%',  // Hardcoded
  'Consistency', 
  'this week', 
  Icons.check_circle,
),
```

**Updated (use calculated value):**
```dart
_buildWeekMetricCard(
  context, 
  '${((weekly?.consistency ?? 0) * 100).toStringAsFixed(0)}%',  // From calculation
  'Consistency', 
  'this week', 
  Icons.check_circle,
),
```

---

## 🧪 TESTING SCENARIOS

### Scenario 1: Day 1 (Monday) - User filled entry
- **Expected:** All 4 cards show data based on 1 day / 1 = 100% or actual values

### Scenario 2: Day 3 (Wednesday) - User filled Mon, Tue, Wed
- **Expected:** Averages calculated from 3 days / 3 days elapsed

### Scenario 3: Day 5 (Friday) - User filled Mon, Tue, Wed, Fri (missed Thu)
- **Expected:** 
  - Averages: Sum of 4 days / 5 days elapsed (lower due to missing day)
  - Consistency: 4 / 5 = 80%

### Scenario 4: No data yet
- **Expected:** Returns `null`, UI shows "—" or empty state

### Scenario 5: Partial data (some entries missing mood/water)
- **Expected:** Calculate from available data, divide by days elapsed

---

## ⚠️ IMPACT ANALYSIS

### Files Modified
1. `lib/services/home_summary_service.dart`
   - Modify `_fetchWeeklySnapshot()` method
   - Add `_calculateCurrentWeekFromLocal()` method
   - Add `_countSelfCareItems()` helper method

2. `lib/models/home_summary_models.dart`
   - Add `consistency` field to `WeeklySnapshotSummary`

3. `lib/screens/home_screen.dart`
   - Update consistency card to use calculated value (currently hardcoded '100%')

### Dependencies Used
- ✅ `LocalEntryService` - Already available
- ✅ `ErrorLoggingService` - Already available
- ✅ `EntrySelfCare` model - Already available

### Breaking Changes
- ❌ **None** - Method signature remains same
- ✅ Backward compatible - Returns same `WeeklySnapshotSummary` type

### Other Functionalities Impact
- ✅ **No impact** - Only affects current week calculation
- ✅ Past weeks still work (if using `weekly_insights` elsewhere)
- ✅ Home screen other sections unaffected
- ✅ Analytics screen unaffected (uses different provider)

---

## 📝 IMPLEMENTATION CHECKLIST

- [ ] Step 1: Modify `_fetchWeeklySnapshot()` to skip `weekly_insights` check
- [ ] Step 2: Add `_calculateCurrentWeekFromLocal()` method
- [ ] Step 3: Implement days elapsed calculation
- [ ] Step 4: Implement local DB queries for entries
- [ ] Step 5: Implement mood average calculation
- [ ] Step 6: Implement water intake calculation
- [ ] Step 7: Implement self-care % calculation
- [ ] Step 8: Implement consistency calculation
- [ ] Step 9: Add `_countSelfCareItems()` helper method
- [ ] Step 10: Add error logging with proper context
- [ ] Step 11: Update `WeeklySnapshotSummary` model - add `consistency` field
- [ ] Step 12: Update home screen to use calculated consistency (replace hardcoded '100%')
- [ ] Step 13: Test all scenarios (Day 1, Day 3, Day 5, No data)
- [ ] Step 14: Verify no breaking changes to other features

---

## 🎯 SUCCESS CRITERIA

1. ✅ 4 cards show data for current week
2. ✅ Calculations divide by days elapsed (not days with data)
3. ✅ Missing days lower the averages
4. ✅ Consistency shows entries / days elapsed
5. ✅ Error handling with proper logging
6. ✅ No breaking changes to existing features
7. ✅ Works with rolling 7-day local storage

---

## 📌 NOTES

- **Rolling 7-day storage:** Local DB keeps last 7 days, which always includes current week data
- **Performance:** Local DB queries are fast (<50ms), no network calls
- **Offline support:** Works completely offline
- **Real-time:** Shows today's data immediately (even if not synced)

---

**Status:** ⏳ Awaiting Approval  
**Ready for Implementation:** Yes

