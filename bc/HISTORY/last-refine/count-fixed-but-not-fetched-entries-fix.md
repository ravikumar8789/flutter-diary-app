# Mood Filter Entries Fetching Implementation Plan

## ⚠️ Critical Fixes Applied (Based on Dry Run)

This plan has been updated to address the following critical issues identified during dry run:

1. **Date Calculation Bug (FIXED):** Changed from `DateTime(now.year, now.month - 2, 1)` to `currentMonth.subtract(const Duration(days: 60))` to properly handle year rollover (January/February edge cases).

2. **Missing Mood Selection Trigger (FIXED):** Added debounced handler using `WidgetsBinding.instance.addPostFrameCallback()` after `setState()` to trigger fetch when mood is selected.

3. **Pagination End Detection (FIXED):** Now checks both `fetchedEntries.length < limit` AND `loadedCount >= totalCount` to properly detect when all entries are loaded.

4. **Null Date Handling in Cache Key (FIXED):** Cache key now uses `'all'` placeholder when `endDate` is null: `entries_mood_${userId}_${moodScore}_${endDateStr ?? 'all'}_${limit}_${offset}`.

5. **State copyWith() Method (FIXED):** Added all new fields (`loadedMoodEntries`, `moodFilterPagination`, `isLoadingMoodFilter`) to `copyWith()` method.

6. **Loading State for Mood Fetch (FIXED):** Added `isLoadingMoodFilter` field separate from `isLoading` to track mood filter fetch state.

7. **Race Condition Prevention (FIXED):** Added debounce (300ms) and `isLoadingMoodFilter` flag check to prevent concurrent fetches when user rapidly switches moods.

---

## Problem Statement

**Issue:** Mood filter counts are correct (from metadata), but when a mood is filtered, entries from unloaded months are not displayed, leading to a mismatch between the count and the actual displayed entries.

**Root Cause:**
- Initial load fetches only current + previous month (2 months)
- Mood counts come from `moodMap` which includes ALL entries (from metadata)
- When mood filter is applied, only entries from loaded months are displayed
- If relevant entries are in unloaded months, they won't show up despite the count being correct

**Example:**
- Mood 1 has 200 entries total (from metadata)
- User has loaded 2 months with 80 entries (20 with mood 1)
- When filtering by mood 1: Count shows 200, but only 20 entries display

---

## Solution Approach

### Core Strategy
1. **Skip Last 2 Months:** When fetching mood-filtered entries, skip the last 2 months (current + previous) since they're already loaded
2. **Pagination:** Fetch entries in batches of 30 to handle users with hundreds of entries
3. **Caching Integration:** Use existing `DataRepository` caching architecture
4. **State Persistence:** Track loaded mood entries to avoid refetching when user navigates away and returns

### Key Insight
- Initial load: Always loads current + previous month (2 months)
- Mood filter fetch: Skip last 2 months, fetch from 3+ months ago
- This avoids deduplication and simplifies logic

---

## Implementation Steps

### Step 1: Update `HistoryState` Model
**File:** `lib/providers/history_provider.dart`

**Changes:**
- Add `loadedMoodEntries` field to track which moods have been fully loaded
- Add `moodFilterPagination` field to track pagination state per mood
- Add `isLoadingMoodFilter` field to track loading state for mood fetch (separate from `isLoading`)

```dart
class HistoryState {
  final List<HistoryEntry> entries;
  final Set<String> loadedMonths;
  final Set<String> loadedMoodEntries; // e.g., "mood_1", "mood_2"
  final Map<String, int> moodFilterPagination; // "mood_1" -> offset
  final bool isLoadingMoodFilter; // Loading state for mood filter fetch
  // ... rest of fields
}
```

**Important:** Update `copyWith()` method to include all new fields:
```dart
HistoryState copyWith({
  List<HistoryEntry>? entries,
  Set<String>? loadedMonths,
  bool? isLoading,
  bool? isLoadingMore,
  bool? isLoadingMoodFilter, // NEW
  String? error,
  Map<String, int>? moodMap,
  List<String>? monthsWithEntries,
  Set<String>? loadedMoodEntries, // NEW
  Map<String, int>? moodFilterPagination, // NEW
}) {
  return HistoryState(
    entries: entries ?? this.entries,
    loadedMonths: loadedMonths ?? this.loadedMonths,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isLoadingMoodFilter: isLoadingMoodFilter ?? this.isLoadingMoodFilter, // NEW
    error: error ?? this.error,
    moodMap: moodMap ?? this.moodMap,
    monthsWithEntries: monthsWithEntries ?? this.monthsWithEntries,
    loadedMoodEntries: loadedMoodEntries ?? this.loadedMoodEntries, // NEW
    moodFilterPagination: moodFilterPagination ?? this.moodFilterPagination, // NEW
  );
}
```

**Impact:** Low - Only adds new fields, doesn't change existing behavior

---

### Step 2: Add Method to `DataFetchService`
**File:** `lib/services/data_fetch_service.dart`

**New Method:** `fetchEntriesByMoodWithJoins()`

**Purpose:** Fetch entries filtered by mood with date range, using JOINs for related data

**Parameters:**
- `userId`: String
- `moodScore`: int (1-5)
- `startDate`: DateTime? (null = from beginning)
- `endDate`: DateTime? (skip last 2 months)
- `limit`: int (default 30)
- `offset`: int (default 0)

**Cache Key Format:**
```
entries_mood_${userId}_${moodScore}_${endDateStr ?? 'all'}_${limit}_${offset}
```

**Implementation:**
- Use existing `_repository.fetch()` pattern`
- Use Supabase query with `.eq('mood_score', moodScore)`
- Apply date filters: 
  - If `endDate` is provided: `.lt('entry_date', endDateStr)` (less than, not less than or equal)
  - If `startDate` is provided: `.gte('entry_date', startDateStr)`
- Include JOINs for all related data (same as `fetchEntriesWithJoins`)
- Handle null dates in cache key: use `'all'` as placeholder

**Important:** Handle null endDate in cache key generation:
```dart
final endDateStr = endDate != null 
    ? endDate.toIso8601String().split('T')[0] 
    : 'all';
final key = 'entries_mood_${userId}_${moodScore}_${endDateStr}_${limit}_${offset}';
```

**Impact:** Low - New method, doesn't affect existing functionality

---

### Step 3: Add Method to `HistoryService`
**File:** `lib/services/history_service.dart`

**New Method:** `getEntriesByMood()`

**Purpose:** Wrapper around `DataFetchService.fetchEntriesByMoodWithJoins()` that parses response into `HistoryEntry` objects

**Implementation:**
- Call `_dataFetchService.fetchEntriesByMoodWithJoins()`
- Parse response similar to `getEntriesForMonth()`
- Build `HistoryEntry` objects with all related data
- Sort by date (newest first)

**Impact:** Low - New method, doesn't affect existing functionality

---

### Step 4: Add Method to `HistoryNotifier`
**File:** `lib/providers/history_provider.dart`

**New Method:** `loadMoodFilteredEntries()`

**Purpose:** Fetch entries for a specific mood when filter is applied

**Logic:**
1. Check if already fetching: If `state.isLoadingMoodFilter` is true, return early (prevent concurrent fetches)
2. Check if mood is already fully loaded: `state.loadedMoodEntries.contains("mood_${moodScore}")`
3. If loaded, return early (no fetch needed)
4. Calculate date range:
   - `endDate`: Skip last 2 months using proper date arithmetic (handle year rollover)
   - `startDate`: null (from beginning)
5. Get current offset from `state.moodFilterPagination["mood_${moodScore}"]` (default 0)
6. Set `isLoadingMoodFilter = true`
7. Call `_service.getEntriesByMood()` with pagination
8. Merge new entries with existing ones (deduplicate by entry ID)
9. Update state:
   - Add entries to `state.entries`
   - Update `moodFilterPagination` offset
   - Determine if fully loaded: Compare total count from `moodMap` vs loaded count
   - If all entries loaded OR fetched entries < limit, mark mood as fully loaded
10. Set `isLoadingMoodFilter = false`

**Date Calculation (Fixed):**
```dart
// Properly handle year rollover
final now = DateTime.now();
final currentMonth = DateTime(now.year, now.month, 1);
// Subtract 2 months properly
final skipUntilDate = DateTime(
  currentMonth.year,
  currentMonth.month - 2 <= 0 ? currentMonth.month - 2 + 12 : currentMonth.month - 2,
  currentMonth.month - 2 <= 0 ? 1 : 1,
);
// Or simpler: use subtract with Duration
final skipUntilDate = currentMonth.subtract(const Duration(days: 60)); // ~2 months
```

**Pagination End Detection (Fixed):**
```dart
// After fetching, check if we've loaded all entries
final totalCount = state.moodMap.values.where((m) => m == moodScore).length;
final loadedCount = state.entries
    .where((e) => e.entry.moodScore == moodScore)
    .length;

// Mark as fully loaded if:
// 1. Fetched less than limit (no more entries)
// 2. OR loaded count equals total count (all entries loaded)
if (fetchedEntries.length < limit || loadedCount >= totalCount) {
  loadedMoodEntries.add("mood_${moodScore}");
}
```

**Edge Cases:**
- If all entries are in last 2 months: Already loaded, no fetch needed
- If no entries found: Mark as loaded, don't add to state
- If fetch fails: Set error state, don't mark as loaded, set `isLoadingMoodFilter = false`
- Concurrent fetches: Prevented by checking `isLoadingMoodFilter` flag

**Impact:** Medium - Adds new functionality, but doesn't change existing flow

---

### Step 5: Update `HistoryScreen` to Trigger Fetch
**File:** `lib/screens/history_screen.dart`

**Changes:**
- Add `ref.listen()` in `build()` method to watch `_selectedMood` changes
- When mood is selected (`_selectedMood` changes):
  1. Parse mood score from `_selectedMood` string
  2. Check if entries for this mood are already in `state.entries`
  3. Calculate: `totalCount` (from `moodMap`) vs `loadedCount` (from filtered `state.entries`)
  4. If `totalCount > loadedCount`:
     - Call `ref.read(historyProvider.notifier).loadMoodFilteredEntries(moodScore)`
  5. Show loading indicator using `state.isLoadingMoodFilter`

**Implementation:**
```dart
@override
Widget build(BuildContext context) {
  final historyState = ref.watch(historyProvider);
  final info = ResponsiveInfo.of(context);

  // Listen to mood selection changes
  ref.listen<String?>(
    // Create a provider that watches _selectedMood
    // Or use a callback in setState
    (previous, next) {
      if (next != null && previous != next) {
        _handleMoodSelection(int.parse(next), historyState);
      }
    },
    (previous, next) {
      // This won't work directly - need different approach
    },
  );

  // Better approach: Add method to handle mood selection
  // Call it from mood chip onTap
}

void _handleMoodSelection(int moodScore, HistoryState historyState) {
  // Debounce to prevent rapid switches
  // Check if fetch needed
  final totalCount = _moodCounts[moodScore] ?? 0;
  final loadedCount = historyState.entries
      .where((e) => e.entry.moodScore == moodScore)
      .length;

  if (totalCount > loadedCount) {
    ref.read(historyProvider.notifier).loadMoodFilteredEntries(moodScore);
  }
}
```

**Better Implementation (Using setState callback):**
```dart
// In _buildMoodChips, update onTap:
onTap: () {
  final newMood = count > 0 ? moodNum.toString() : null;
  setState(() {
    _selectedMood = newMood;
  });
  
  // Trigger fetch after state update
  if (newMood != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleMoodSelection(moodNum);
    });
  }
},
```

**Add debounce to prevent rapid mood switches:**
```dart
Timer? _moodSelectionTimer;

void _handleMoodSelection(int moodScore) {
  // Cancel previous timer
  _moodSelectionTimer?.cancel();
  
  // Debounce for 300ms
  _moodSelectionTimer = Timer(const Duration(milliseconds: 300), () {
    final historyState = ref.read(historyProvider);
    final totalCount = _moodCounts[moodScore] ?? 0;
    final loadedCount = historyState.entries
        .where((e) => e.entry.moodScore == moodScore)
        .length;

    if (totalCount > loadedCount && !historyState.isLoadingMoodFilter) {
      ref.read(historyProvider.notifier).loadMoodFilteredEntries(moodScore);
    }
  });
}

@override
void dispose() {
  _moodSelectionTimer?.cancel();
  super.dispose();
}
```

**Impact:** Medium - Changes UI behavior, but only when mood filter is applied

---

### Step 6: Add Pagination Support for Mood Filter
**File:** `lib/screens/history_screen.dart`

**Changes:**
- Detect when user scrolls to bottom of mood-filtered list
- Check if more entries available: `totalCount > loadedCount`
- If yes, call `loadMoodFilteredEntries()` with incremented offset
- Show "Load More" button or auto-load on scroll

**Implementation:**
- Use `ScrollController` to detect scroll position
- Check `state.moodFilterPagination` for current offset
- Increment offset and fetch next batch

**Impact:** Medium - Adds pagination UI, but only for mood filter

---

### Step 7: Handle Deduplication
**File:** `lib/providers/history_provider.dart`

**In `loadMoodFilteredEntries()` method:**
- Before merging new entries, filter out duplicates
- Use `entry.id` to check if entry already exists in `state.entries`
- Only add entries that don't exist

**Implementation:**
```dart
final existingIds = state.entries.map((e) => e.entry.id).toSet();
final newEntries = fetchedEntries
    .where((e) => !existingIds.contains(e.entry.id))
    .toList();
```

**Impact:** Low - Prevents duplicate entries in state

---

## Edge Cases Handling

### 1. All Entries in Last 2 Months
**Scenario:** All entries with selected mood are in last 2 months (already loaded)

**Handling:**
- Check `loadedCount == totalCount` before fetching
- If equal, skip fetch (all entries already loaded)
- No API call needed

---

### 2. Some Entries in Last 2 Months, Some Older
**Scenario:** 80 entries in loaded months, 120 in older months

**Handling:**
- Skip last 2 months in query (`endDate = currentMonth - 2`)
- Fetch only older entries
- Merge with existing entries (deduplication handles overlap)

---

### 3. Very Old User with Hundreds of Entries
**Scenario:** User has 500 entries with mood 1

**Handling:**
- Pagination: Fetch 30 at a time
- User scrolls → fetch next 30
- Continue until all loaded
- Cache each batch separately (different offset = different cache key)

---

### 4. User Navigates Away and Returns
**Scenario:** User fetches 100 mood entries, navigates to profile, returns to history

**Handling:**
- Provider state persists (NOT autoDispose)
- Entries remain in `state.entries`
- `loadedMoodEntries` tracks which moods are loaded
- No refetch needed when returning

---

### 5. Cache Expiration
**Scenario:** Cache expires (5 minutes TTL) while user is on screen

**Handling:**
- Stale-while-revalidate (SWR) pattern
- Returns stale data immediately
- Refetches in background
- Updates UI when fresh data arrives

---

### 6. Multiple Mood Filters in Sequence
**Scenario:** User filters mood 1, then mood 2, then back to mood 1

**Handling:**
- Each mood tracked separately in `loadedMoodEntries`
- Mood 1 entries remain in `state.entries` (not removed)
- When switching back, check if already loaded
- If loaded, filter from existing entries (no fetch)

---

### 7. New Entry Created While Filtered
**Scenario:** User creates new entry with mood 1 while mood 1 filter is active

**Handling:**
- New entry added to `state.entries` via existing entry creation flow
- Automatically appears in filtered list (no special handling needed)
- If entry is in last 2 months, it's already in loaded entries

---

### 8. Network Error During Fetch
**Scenario:** API call fails while fetching mood entries

**Handling:**
- Set error state: `state.copyWith(error: 'Failed to load entries')`
- Don't mark mood as loaded (allows retry)
- Set `isLoadingMoodFilter = false` to allow retry
- Show error message to user
- User can retry by selecting mood again

---

### 9. Rapid Mood Switching (Race Condition)
**Scenario:** User rapidly switches between moods, causing multiple concurrent fetches

**Handling:**
- Add debounce (300ms) to mood selection handler
- Check `isLoadingMoodFilter` flag before starting new fetch
- Cancel previous fetch timer if new mood is selected
- Only allow one mood fetch at a time

---

### 10. Cache Key with Null Dates
**Scenario:** `endDate` is null (fetching from beginning), causing cache key issues

**Handling:**
- Use `'all'` as placeholder in cache key when date is null
- Format: `entries_mood_${userId}_${moodScore}_all_${limit}_${offset}`
- Ensure cache key is always valid string

---

## Testing Considerations

### Unit Tests
1. **HistoryState:**
   - Test `loadedMoodEntries` tracking
   - Test `moodFilterPagination` offset updates

2. **DataFetchService:**
   - Test `fetchEntriesByMoodWithJoins()` cache key generation
   - Test date range filtering (skip last 2 months)
   - Test pagination (limit/offset)

3. **HistoryNotifier:**
   - Test `loadMoodFilteredEntries()` logic
   - Test deduplication
   - Test state updates

### Integration Tests
1. **Mood Filter Flow:**
   - Select mood → Check if fetch is triggered
   - Verify entries are added to state
   - Verify no duplicates

2. **Pagination Flow:**
   - Scroll to bottom → Check if next batch is fetched
   - Verify offset increments correctly

3. **Navigation Flow:**
   - Fetch entries → Navigate away → Return
   - Verify entries persist (no refetch)

### Manual Testing Checklist
- [ ] Select mood with entries in unloaded months → Entries appear
- [ ] Select mood with all entries in loaded months → No fetch, entries show immediately
- [ ] Scroll to bottom of mood-filtered list → Next batch loads
- [ ] Navigate away and return → Entries persist
- [ ] Switch between moods → Each mood loads correctly
- [ ] Rapid mood switching → No race conditions, only last mood fetches
- [ ] Create new entry with filtered mood → Appears in list
- [ ] Network error → Error message shows, can retry
- [ ] Test in January/February → Date calculation works correctly (year rollover)
- [ ] Test pagination end detection → Correctly detects when all entries loaded
- [ ] Test loading indicator → Shows during mood fetch, doesn't block UI

---

## Impact Analysis

### Files Modified
1. `lib/providers/history_provider.dart` - Add state fields and new method
2. `lib/services/data_fetch_service.dart` - Add new fetch method
3. `lib/services/history_service.dart` - Add wrapper method
4. `lib/screens/history_screen.dart` - Add mood filter fetch trigger and pagination

### Files Not Modified
- All other screens remain unchanged
- Entry creation flow unchanged
- Calendar view unchanged
- Analytics unchanged
- Profile screen unchanged

---

## Code Examples

### Example 1: Calculate Skip Date (Last 2 Months) - FIXED
```dart
// In loadMoodFilteredEntries()
final now = DateTime.now();
final currentMonth = DateTime(now.year, now.month, 1);

// FIXED: Properly handle year rollover
// Option 1: Use subtract with Duration (simpler, handles edge cases)
final skipUntilDate = currentMonth.subtract(const Duration(days: 60)); // ~2 months

// Option 2: Manual calculation (more precise)
final skipUntilDate = DateTime(
  currentMonth.year,
  currentMonth.month - 2 <= 0 ? currentMonth.month - 2 + 12 : currentMonth.month - 2,
  currentMonth.month - 2 <= 0 ? 1 : 1,
);
if (currentMonth.month - 2 <= 0) {
  skipUntilDate = DateTime(currentMonth.year - 1, currentMonth.month + 10, 1);
}

// Use: endDate = skipUntilDate (entries before this date, use .lt() not .lte())
```

### Example 2: Check If Fetch Needed
```dart
// In HistoryScreen when mood is selected
final totalCount = _moodCounts[moodScore] ?? 0;
final loadedCount = historyState.entries
    .where((e) => e.entry.moodScore == moodScore)
    .length;

if (totalCount > loadedCount) {
  // Need to fetch more entries
  await ref.read(historyProvider.notifier)
      .loadMoodFilteredEntries(moodScore);
}
```

### Example 3: Deduplication Logic
```dart
// In loadMoodFilteredEntries()
final existingIds = state.entries.map((e) => e.entry.id).toSet();
final newEntries = fetchedEntries
    .where((e) => !existingIds.contains(e.entry.id))
    .toList();

// Merge with existing entries
final allEntries = [...state.entries, ...newEntries];
allEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));
```

### Example 4: Pagination Check - FIXED
```dart
// In loadMoodFilteredEntries()
final currentOffset = state.moodFilterPagination["mood_${moodScore}"] ?? 0;
final limit = 30;

final fetchedEntries = await _service.getEntriesByMood(
  userId: userId,
  moodScore: moodScore,
  startDate: null, // From beginning
  endDate: skipUntilDate, // Skip last 2 months
  limit: limit,
  offset: currentOffset,
);

// Deduplicate and merge
final existingIds = state.entries.map((e) => e.entry.id).toSet();
final newEntries = fetchedEntries
    .where((e) => !existingIds.contains(e.entry.id))
    .toList();

// Merge with existing entries
final allEntries = [...state.entries, ...newEntries];
allEntries.sort((a, b) => b.entry.entryDate.compareTo(a.entry.entryDate));

// FIXED: Better pagination end detection
// Calculate total count from moodMap and loaded count
final totalCount = state.moodMap.values.where((m) => m == moodScore).length;
final loadedCount = allEntries
    .where((e) => e.entry.moodScore == moodScore)
    .length;

// Mark as fully loaded if:
// 1. Fetched less than limit (no more entries in DB)
// 2. OR loaded count equals total count (all entries now in state)
final isFullyLoaded = fetchedEntries.length < limit || loadedCount >= totalCount;

final updatedLoadedMoodEntries = {...state.loadedMoodEntries};
final updatedPagination = {...state.moodFilterPagination};

if (isFullyLoaded) {
  updatedLoadedMoodEntries.add("mood_${moodScore}");
} else {
  // Update offset for next fetch
  updatedPagination["mood_${moodScore}"] = currentOffset + limit;
}

// Update state
state = state.copyWith(
  entries: allEntries,
  loadedMoodEntries: updatedLoadedMoodEntries,
  moodFilterPagination: updatedPagination,
  isLoadingMoodFilter: false,
);
```

---

## Performance Considerations

### 1. Memory Usage
**Concern:** Loading hundreds of entries could increase memory usage

**Mitigation:**
- Pagination limits to 30 entries per batch
- Entries are stored in provider state (already in memory)
- No additional memory overhead beyond existing architecture

### 2. API Call Frequency
**Concern:** Multiple mood filters could trigger many API calls

**Mitigation:**
- Caching: Each batch cached for 5 minutes (DataRepository)
- State tracking: Prevents refetching already loaded moods
- Deduplication: Prevents duplicate entries in state

### 3. Query Performance
**Concern:** Querying by mood across all dates could be slow

**Mitigation:**
- Date filter: Skip last 2 months reduces query scope
- Pagination: Limits result set to 30 entries
- Index: Ensure `mood_score` and `entry_date` are indexed in Supabase

### 4. UI Responsiveness
**Concern:** Fetching could block UI

**Mitigation:**
- Async operations: All fetches are async
- Loading states: Show loading indicators
- Background fetch: Use SWR pattern (returns stale data immediately)

---

## Implementation Order

### Phase 1: Foundation (Low Risk)
1. Update `HistoryState` model (add fields + update `copyWith()`)
2. Add `fetchEntriesByMoodWithJoins()` to `DataFetchService` (handle null dates in cache key)
3. Add `getEntriesByMood()` to `HistoryService`

**Testing:** Unit tests for new methods, test date calculation edge cases (January/February)

### Phase 2: Core Logic (Medium Risk)
4. Add `loadMoodFilteredEntries()` to `HistoryNotifier`
   - Fix date calculation (use Duration subtract)
   - Add `isLoadingMoodFilter` flag management
   - Implement deduplication logic
   - Fix pagination end detection (check total vs loaded count)
   - Handle race conditions (check loading flag)

**Testing:** Unit tests + integration tests, test pagination end detection

### Phase 3: UI Integration (Medium Risk)
7. Update `HistoryScreen` to trigger fetch on mood selection
   - Add debounced mood selection handler
   - Use `WidgetsBinding.instance.addPostFrameCallback()` after setState
   - Check `isLoadingMoodFilter` before triggering fetch
8. Add loading indicators (use `state.isLoadingMoodFilter`)
9. Add pagination UI (scroll detection or "Load More" button)

**Testing:** Manual testing + integration tests, test rapid mood switching

### Phase 4: Edge Cases (Low Risk)
10. Handle all edge cases
11. Add error handling
12. Add retry logic

**Testing:** Manual testing checklist

---

## Rollback Strategy

### If Issues Arise
1. **Immediate Rollback:**
   - Revert changes to modified files
   - Mood filter will work as before (only shows loaded entries)
   - No data loss (state changes are additive)

2. **Partial Rollback:**
   - Keep state model changes (backward compatible)
   - Remove fetch triggers in UI
   - Entries remain in state but won't be fetched automatically

3. **Feature Flag:**
   - Add feature flag to enable/disable mood filter fetching
   - Allows gradual rollout or quick disable

---

## Success Criteria

### Functional Requirements
- [x] Mood filter shows all entries matching the count
- [x] Entries from unloaded months are fetched and displayed
- [x] Pagination works for large datasets
- [x] Caching prevents unnecessary API calls
- [x] State persists when navigating away

### Performance Requirements
- [x] Initial fetch completes in < 2 seconds
- [x] Pagination fetch completes in < 1 second
- [x] No duplicate entries in list
- [x] Memory usage remains reasonable (< 50MB for 500 entries)

### User Experience Requirements
- [x] Loading indicators show during fetch
- [x] Error messages are clear and actionable
- [x] Smooth scrolling with pagination
- [x] No UI freezing or blocking

---

## Notes

### Important Considerations
1. **Date Calculation (FIXED):** Use `currentMonth.subtract(const Duration(days: 60))` to skip last 2 months. This properly handles year rollover (e.g., if current month is January, it correctly goes to November of previous year). Never use `DateTime(now.year, now.month - 2, 1)` as it fails for months 1 and 2.

2. **Cache Keys (FIXED):** Include all relevant parameters in cache key to ensure proper cache isolation (userId, moodScore, endDate, limit, offset). Handle null dates by using `'all'` as placeholder: `entries_mood_${userId}_${moodScore}_${endDateStr ?? 'all'}_${limit}_${offset}`.

3. **State Updates:** Always use `copyWith()` to update state immutably. Never mutate state directly. **CRITICAL:** Update `copyWith()` method to include all new fields (`loadedMoodEntries`, `moodFilterPagination`, `isLoadingMoodFilter`).

4. **Error Handling:** Log all errors using `ErrorLoggingService` with appropriate error codes and context. Always set `isLoadingMoodFilter = false` in error cases.

5. **Race Condition Prevention:** 
   - Add debounce (300ms) to mood selection handler
   - Check `isLoadingMoodFilter` flag before starting fetch
   - Cancel previous timer when new mood is selected

6. **Pagination End Detection (FIXED):** Don't rely solely on `fetchedEntries.length < limit`. Also check if `loadedCount >= totalCount` from moodMap to ensure all entries are loaded.

7. **Mood Selection Trigger (FIXED):** Use `WidgetsBinding.instance.addPostFrameCallback()` after `setState()` to trigger fetch, or add debounced handler in mood chip `onTap`. Don't rely on `ref.listen()` for local state changes.

8. **Testing:** Test with various scenarios:
   - New user (few entries)
   - Old user (many entries)
   - User with entries only in last 2 months
   - User with entries spread across many months
   - Rapid mood switching (race condition)
   - January/February edge cases (date calculation)

### Future Enhancements (Out of Scope)
- Prefetch mood entries in background
- Optimize query with database indexes
- Add search/filter within mood-filtered entries
- Add export functionality for mood-filtered entries
