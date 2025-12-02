# History Screen Optimization Report - Lightweight Implementation

## 📊 Current Scenario Analysis

### **Current Implementation Issues:**

1. **Initial Load Behavior:**
   - `loadCurrentMonth()` searches up to 6 months until entries found, then stops
   - Only loads 1 month when entries are found
   - If current month has entries, previous month is not loaded
   - User sees limited data on initial load

2. **Calendar Mood Data:**
   - Calendar only shows mood indicators for loaded entries
   - If user has entries 12 months ago, calendar won't show them
   - `moodMap` only populated from loaded `HistoryEntry` objects
   - Calendar view incomplete without full mood data

3. **Load More Button Logic:**
   - `_availableMonths` only checks loaded entries in memory
   - Doesn't query database for months with entries
   - Button may not appear even if older entries exist
   - Logic: `allMonths.difference(loadedMonths)` - only works for loaded data

4. **Performance Concerns:**
   - Loading full `HistoryEntry` objects (with all related data) for calendar mood indicators
   - Calendar needs mood data for ALL entries, but we only load 1-6 months
   - No separation between list view data and calendar data
   - RAM usage: Full entry objects stored even when only mood needed

---

## 🎯 Requirements

1. **List View:**
   - Load 2 months initially (current + previous)
   - Show "Load More" button for older months
   - Button should detect months with entries from database

2. **Calendar View:**
   - Show mood indicators for ALL entries (not just loaded)
   - Lightweight query (only `entry_date` + `mood_score`)
   - Query wider range (e.g., last 12-24 months) for calendar
   - No full entry data needed for calendar

3. **Performance:**
   - Minimize database queries
   - Reduce RAM usage
   - Optimize for both list and calendar views

---

## 💡 Proposed Solution: Dual-Layer Data Loading

### **Architecture:**

```
┌─────────────────────────────────────────┐
│         History Screen Init             │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
   ┌───▼───┐      ┌─────▼─────┐
   │ List  │      │ Calendar  │
   │ Data  │      │ Mood Data │
   └───┬───┘      └─────┬─────┘
       │                │
   ┌───▼───────────────▼───┐
   │  HistoryProvider      │
   │  - entries (full)     │
   │  - moodMap (light)    │
   └───────────────────────┘
```

### **Key Changes:**

1. **Separate Lightweight Query for Calendar:**
   - New method: `getMoodMapForDateRange()` in `HistoryService`
   - Queries only `entry_date` and `mood_score` from local DB
   - Returns `Map<String, int>` (date string -> mood score)
   - Query range: Last 12-24 months (configurable)

2. **Initial Load Strategy:**
   - Load 2 months initially (current + previous) with full data
   - Load calendar mood data separately (lightweight, wider range)
   - Both queries run in parallel for faster load

3. **Load More Button:**
   - Query database for months with entries (not just loaded)
   - New method: `getMonthsWithEntries()` in `HistoryService`
   - Returns list of month keys (e.g., "2024-01") that have entries
   - Button shows if unloaded months exist

4. **Mood Map Management:**
   - Calendar mood data loaded separately on init
   - List view mood data merged when loading months
   - Default mood to 3 if `mood_score` is NULL (for consistency)

---

## 🔧 Implementation Plan

### **Phase 1: Add Lightweight Methods to HistoryService**

**File: `lib/services/history_service.dart`**

```dart
/// Get mood map for date range (lightweight - only date + mood)
/// Used for calendar view
Future<Map<String, int>> getMoodMapForDateRange(
  String userId,
  DateTime startDate,
  DateTime endDate,
) async {
  // Query only entry_date and mood_score from local DB
  // Return Map<dateString, moodScore>
  // Default mood to 3 if NULL
}

/// Get list of months that have entries (for Load More button)
Future<List<String>> getMonthsWithEntries(String userId) async {
  // Query distinct months from entries table
  // Return list of month keys (e.g., ["2024-01", "2024-02"])
  // Sorted oldest first
}
```

**Benefits:**
- Calendar gets mood data without loading full entries
- Load More button knows which months exist
- Minimal RAM usage (just date strings + integers)

---

### **Phase 2: Update HistoryProvider**

**File: `lib/providers/history_provider.dart`**

**Changes to `loadCurrentMonth()`:**
```dart
Future<void> loadCurrentMonth() async {
  // 1. Load 2 months initially (current + previous)
  // 2. Load calendar mood data in parallel (last 12 months)
  // 3. Merge mood maps
  // 4. Update state
}
```

**New Method:**
```dart
/// Load calendar mood data (lightweight)
Future<void> loadCalendarMoodData() async {
  // Query mood data for last 12 months
  // Update moodMap in state
}
```

**New State Field (optional):**
```dart
final Set<String> monthsWithEntries; // All months that have entries
```

---

### **Phase 3: Update HistoryScreen**

**File: `lib/screens/history_screen.dart`**

**Changes to `_availableMonths`:**
```dart
List<String> get _availableMonths {
  // Option 1: Query from provider state (if we add monthsWithEntries)
  // Option 2: Query database directly (if needed)
  // Return months that have entries but aren't loaded
}
```

**Changes to `initState`:**
```dart
@override
void initState() {
  super.initState();
  // Load list data (2 months)
  ref.read(historyProvider.notifier).loadCurrentMonth();
  // Load calendar mood data (lightweight)
  ref.read(historyProvider.notifier).loadCalendarMoodData();
}
```

---

### **Phase 4: Add Lightweight Query to LocalEntryService**

**File: `lib/services/database/local_entry_service.dart`**

```dart
/// Get mood map for date range (lightweight query)
Future<Map<String, int>> getMoodMapForDateRange(
  String userId,
  DateTime start,
  DateTime end,
) async {
  final db = await _dbManager.database;
  final startStr = DateFormat('yyyy-MM-dd').format(start);
  final endStr = DateFormat('yyyy-MM-dd').format(end);

  // Query only entry_date and mood_score
  final results = await db.query(
    'entries',
    columns: ['entry_date', 'mood_score'], // Only these columns
    where: 'user_id = ? AND entry_date BETWEEN ? AND ?',
    whereArgs: [userId, startStr, endStr],
  );

  final moodMap = <String, int>{};
  for (var row in results) {
    final dateStr = row['entry_date'] as String;
    final moodScore = row['mood_score'] as int? ?? 3; // Default to 3
    moodMap[dateStr] = moodScore;
  }

  return moodMap;
}

/// Get distinct months that have entries
Future<List<String>> getMonthsWithEntries(String userId) async {
  final db = await _dbManager.database;
  
  // Query distinct months using SQLite date functions
  final results = await db.rawQuery('''
    SELECT DISTINCT 
      strftime('%Y-%m', entry_date) as month_key
    FROM entries
    WHERE user_id = ?
    ORDER BY month_key ASC
  ''', [userId]);

  return results.map((row) => row['month_key'] as String).toList();
}
```

---

## 📈 Performance Optimization

### **Query Optimization:**

1. **Calendar Mood Query:**
   - **Before:** Loading full `HistoryEntry` objects (entry + insights + self-care + meals + affirmations + gratitude + priorities + tomorrow notes)
   - **After:** Only `entry_date` and `mood_score` columns
   - **Reduction:** ~95% less data transferred
   - **RAM:** ~90% less memory usage

2. **Load More Detection:**
   - **Before:** Checking loaded entries in memory (incomplete)
   - **After:** Single lightweight query for distinct months
   - **Query:** `SELECT DISTINCT strftime('%Y-%m', entry_date) FROM entries`
   - **Result:** Small list of month strings

3. **Parallel Loading:**
   - List data and calendar mood data load in parallel
   - Faster initial screen render
   - User sees calendar indicators immediately

### **RAM Usage:**

**Before:**
- Full `HistoryEntry` objects for calendar: ~2-5 KB per entry
- 12 months × 30 entries = 360 entries = ~720 KB - 1.8 MB

**After:**
- Lightweight mood map: ~20 bytes per entry (date string + int)
- 360 entries = ~7.2 KB
- **Reduction: 99% less RAM for calendar data**

### **Query Count:**

**Before:**
- Load 1 month: 1 query for entries + 1 query for insights + 6 queries for related data = 8 queries
- Calendar: Uses loaded entries only (incomplete)

**After:**
- Load 2 months: 2 × 8 = 16 queries (but parallelized)
- Calendar mood: 1 lightweight query (date + mood only)
- Load More detection: 1 lightweight query (distinct months)
- **Total: 18 queries (but optimized and parallelized)**

---

## 🛡️ Impact Analysis on Other Features

### **✅ No Impact Areas:**

1. **Entry Creation/Editing:**
   - No changes to entry creation flow
   - No changes to entry editing flow
   - Local DB operations unchanged

2. **Home Screen:**
   - No changes to home screen logic
   - No changes to entry service
   - No changes to AI service

3. **Analytics Screen:**
   - No changes to analytics queries
   - No changes to analytics models
   - No changes to analytics service

4. **Other Screens:**
   - No changes to wellness tracker
   - No changes to morning rituals
   - No changes to gratitude reflection

### **⚠️ Areas Requiring Attention:**

1. **HistoryProvider State:**
   - Adding `monthsWithEntries` field (optional, can be computed)
   - `moodMap` now populated from two sources (list + calendar)
   - Need to ensure proper merging logic

2. **HistoryService:**
   - Adding new methods (no breaking changes)
   - Existing methods unchanged
   - Backward compatible

3. **LocalEntryService:**
   - Adding new lightweight query methods
   - Existing methods unchanged
   - No breaking changes

4. **HistoryScreen UI:**
   - `_availableMonths` logic updated (but same interface)
   - Calendar view uses same `moodMap` (just populated differently)
   - No UI changes required

### **🔒 Safety Measures:**

1. **Error Handling:**
   - All new methods have try-catch blocks
   - Fallback to empty map/list on error
   - Error logging maintained

2. **Null Safety:**
   - Default mood to 3 if NULL (consistent with card display)
   - Handle empty results gracefully
   - No null pointer exceptions

3. **Backward Compatibility:**
   - Existing methods unchanged
   - New methods are additions
   - Can rollback easily if needed

---

## 📋 Implementation Checklist

### **Step 1: Add Lightweight Query Methods**
- [ ] Add `getMoodMapForDateRange()` to `LocalEntryService`
- [ ] Add `getMonthsWithEntries()` to `LocalEntryService`
- [ ] Test queries with sample data

### **Step 2: Update HistoryService**
- [ ] Add `getMoodMapForDateRange()` wrapper method
- [ ] Add `getMonthsWithEntries()` wrapper method
- [ ] Add error handling and logging

### **Step 3: Update HistoryProvider**
- [ ] Modify `loadCurrentMonth()` to load 2 months
- [ ] Add `loadCalendarMoodData()` method
- [ ] Update `_buildMoodMap()` to default mood to 3
- [ ] Merge calendar mood data with list mood data

### **Step 4: Update HistoryScreen**
- [ ] Update `_availableMonths` to use database query
- [ ] Update `initState` to load calendar mood data
- [ ] Test Load More button logic

### **Step 5: Testing**
- [ ] Test with entries in current month only
- [ ] Test with entries in previous months
- [ ] Test with entries 12+ months ago
- [ ] Test calendar mood indicators
- [ ] Test Load More button
- [ ] Test with no entries
- [ ] Test with NULL mood scores

---

## 🎯 Expected Outcomes

### **User Experience:**
- ✅ See 2 months of entries on initial load
- ✅ Calendar shows mood indicators for all entries
- ✅ Load More button always appears when older entries exist
- ✅ Faster initial load (parallel queries)
- ✅ Smooth scrolling in calendar view

### **Performance:**
- ✅ 99% less RAM for calendar data
- ✅ 95% less data transferred for calendar
- ✅ Optimized queries (only needed columns)
- ✅ Parallel loading for faster render

### **Code Quality:**
- ✅ Separation of concerns (list vs calendar data)
- ✅ Reusable lightweight query methods
- ✅ Backward compatible changes
- ✅ Comprehensive error handling

---

## 🔄 Migration Path

### **If Issues Arise:**

1. **Rollback Plan:**
   - Revert `loadCurrentMonth()` to original logic
   - Remove calendar mood data loading
   - Keep Load More button using loaded entries only

2. **Gradual Rollout:**
   - Phase 1: Add lightweight methods (no UI changes)
   - Phase 2: Update provider (test thoroughly)
   - Phase 3: Update UI (final integration)

3. **Monitoring:**
   - Track query performance
   - Monitor RAM usage
   - Check error logs for new methods

---

## 📝 Summary

**Problem:** Calendar needs mood data for all entries, but we only load 1-6 months. Load More button doesn't detect all months with entries.

**Solution:** Separate lightweight queries for calendar mood data (date + mood only) and month detection. Load 2 months initially for list view.

**Benefits:**
- 99% less RAM for calendar
- 95% less data transferred
- Complete calendar mood indicators
- Accurate Load More button
- No impact on other features

**Risk Level:** Low (backward compatible, isolated changes)

**Implementation Time:** ~2-3 hours

---

**Status:** Ready for Implementation ✅

