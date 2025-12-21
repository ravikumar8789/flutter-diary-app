# History Screen: Local DB → Supabase Migration Plan

## Current State Analysis

### Current Data Flow

**History Screen Initial Load:**
1. `loadCurrentMonth()` in `HistoryProvider`:
   - Calls `getEntriesForMonth()` for current month (local DB)
   - Calls `getEntriesForMonth()` for previous month (local DB)
   - Calls `getMonthsWithEntries()` (local DB)
   - Calls `loadCalendarMoodData()` → `getMoodMapForDateRange()` (local DB, last 12 months)

2. `getEntriesForMonth()` in `HistoryService`:
   - Fetches entries from **local DB** (`LocalEntryService.getEntriesInRange()`)
   - Fetches insights from **Supabase** (`entry_insights` table)
   - For each entry, calls `_buildHistoryEntry()` which fetches related data from **local DB**:
     - `entry_self_care`
     - `entry_meals`
     - `entry_affirmations`
     - `entry_gratitude`
     - `entry_priorities`
     - `entry_tomorrow_notes`

3. `getEntryByDate()` (for calendar tap):
   - Fetches entry from **local DB**
   - Fetches insight from **Supabase**
   - Builds history entry with related data from **local DB**

4. `getMoodMapForDateRange()` (for calendar):
   - Fetches only `entry_date` and `mood_score` from **local DB**

5. `getMonthsWithEntries()`:
   - Fetches distinct months from **local DB**

### Problem
- **7-day retention policy** in `DatabaseManager.clearOldEntries()` deletes entries older than 7 days from local DB
- History screen only shows last 6 days because older entries are deleted
- Calendar only shows mood data for last 6 days

---

## Target State

### Desired Flow

**History Screen Initial Load:**
1. Fetch **2 months** of entries from **Supabase** (current + previous month)
2. Fetch **all mood data** for calendar view from **Supabase** (no date limit)
3. Fetch insights **on-demand** when user clicks on an entry (not during initial load)
4. Minimize API calls by using efficient queries

---

## Changes Required

### 1. `HistoryService` - Replace Local DB with Supabase

#### 1.1 `getEntriesForMonth()` - Fetch entries with related data using JOIN
**Current:**
- `_localService.getEntriesInRange()` → local DB
- Then fetches related data separately

**New:**
- Use Supabase nested queries (JOIN) to fetch entries + all related data in **ONE call**
- Use `Entry.fromSupabaseJson()` to parse results
- **No insights fetching** during this call (move to on-demand)

**Optimized Query with JOIN:**
```dart
final response = await _supabase
  .from('entries')
  .select('''
    *,
    entry_self_care(*),
    entry_meals(*),
    entry_affirmations(*),
    entry_gratitude(*),
    entry_priorities(*),
    entry_tomorrow_notes(*)
  ''')
  .eq('user_id', userId)
  .gte('entry_date', startDateStr)
  .lte('entry_date', endDateStr)
  .order('entry_date', ascending: false);
```

**Response Structure:**
```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "entry_date": "2024-01-15",
    "diary_text": "...",
    "mood_score": 4,
    "entry_self_care": { "entry_id": "uuid", "sleep": true, ... },
    "entry_meals": { "entry_id": "uuid", "breakfast": "...", ... },
    "entry_affirmations": { "entry_id": "uuid", "affirmations": [...] },
    "entry_gratitude": { "entry_id": "uuid", "grateful_items": [...] },
    "entry_priorities": { "entry_id": "uuid", "priorities": [...] },
    "entry_tomorrow_notes": { "entry_id": "uuid", "tomorrow_notes": [...] }
  }
]
```

**Note:** 
- Related data tables return as nested objects (one-to-one relationship)
- If an entry doesn't have related data, the nested object will be `null`
- Handle null checks when parsing: `row['entry_self_care'] != null ? EntrySelfCare.fromSupabaseJson(...) : null`

#### 1.2 `_buildHistoryEntry()` - Parse nested data from JOIN query
**Current:**
- Fetches from local DB: `getSelfCare()`, `getMeals()`, `getAffirmations()`, etc.

**New:**
- **No separate fetch needed!** Data comes from the JOIN query in `getEntriesForMonth()`
- Parse nested objects from the response:
  - `entry_self_care` → `EntrySelfCare.fromSupabaseJson()`
  - `entry_meals` → `EntryMeals.fromJson()` (or add `fromSupabaseJson()`)
  - `entry_affirmations` → `EntryAffirmations.fromSupabaseJson()`
  - `entry_gratitude` → `EntryGratitude.fromSupabaseJson()`
  - `entry_priorities` → `EntryPriorities.fromSupabaseJson()`
  - `entry_tomorrow_notes` → `EntryTomorrowNotes.fromSupabaseJson()`

**Parsing Logic:**
```dart
// In getEntriesForMonth(), after fetching with JOIN
for (var row in response) {
  final entry = Entry.fromSupabaseJson(row);
  
  // Parse nested related data
  final selfCare = row['entry_self_care'] != null
      ? EntrySelfCare.fromSupabaseJson(row['entry_self_care'])
      : null;
  final meals = row['entry_meals'] != null
      ? EntryMeals.fromJson(row['entry_meals']) // or fromSupabaseJson
      : null;
  // ... etc
}
```

#### 1.3 `getEntryByDate()` - Fetch with JOIN (single call)
**Current:**
- `_localService.getEntryByDate()` → local DB
- Then fetches related data separately

**New:**
- Use JOIN to fetch entry + all related data in **ONE call**
- Fetch insight from Supabase (on-demand, when user clicks)

**Optimized Query:**
```dart
final response = await _supabase
  .from('entries')
  .select('''
    *,
    entry_self_care(*),
    entry_meals(*),
    entry_affirmations(*),
    entry_gratitude(*),
    entry_priorities(*),
    entry_tomorrow_notes(*)
  ''')
  .eq('user_id', userId)
  .eq('entry_date', dateStr)
  .maybeSingle();
```

**Note:** Same nested structure as `getEntriesForMonth()`, parse accordingly

#### 1.4 `getMoodMapForDateRange()` - Fetch from Supabase
**Current:**
- `_localService.getMoodMapForDateRange()` → local DB

**New:**
- Query only `entry_date` and `mood_score` from Supabase `entries` table
- **No date limit** - fetch all mood data for calendar view

**Query:**
```dart
final response = await _supabase
  .from('entries')
  .select('entry_date, mood_score')
  .eq('user_id', userId)
  .gte('entry_date', startDateStr)
  .lte('entry_date', endDateStr);
```

#### 1.5 `getMonthsWithEntries()` - Fetch from Supabase
**Current:**
- `_localService.getMonthsWithEntries()` → local DB

**New:**
- Query distinct months from Supabase `entries` table
- Use PostgreSQL `DATE_TRUNC` or `TO_CHAR` to extract month

**Query:**
```dart
// Option 1: Fetch all entries and group in Dart
final response = await _supabase
  .from('entries')
  .select('entry_date')
  .eq('user_id', userId)
  .order('entry_date', ascending: true);

// Extract unique months
final months = <String>{};
for (var row in response) {
  final date = DateTime.parse(row['entry_date']);
  months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
}
return months.toList()..sort();

// Option 2: Use RPC function (if we create one)
```

#### 1.6 `_fetchInsightsForMonth()` - Keep as is (already Supabase)
**Current:**
- Already fetches from Supabase `entry_insights` table
- **Change:** Remove this from `getEntriesForMonth()` - fetch insights on-demand only

#### 1.7 `_getEntryIdsInRange()` - Remove (no longer needed)
**Current:**
- Helper to get entry IDs from local DB for insights query

**New:**
- Remove this method
- Insights will be fetched on-demand per entry

---

### 2. `HistoryProvider` - Update Loading Logic

#### 2.1 `loadCurrentMonth()` - Optimize Initial Load with JOINs
**Current:**
- Loads 2 months with insights (3 parallel calls)
- Each entry triggers 6 separate calls for related data

**New:**
- Load 2 months **with JOIN** (entries + related data in single call per month)
- Load calendar mood data (1 call, all dates)
- Load months list (1 call)
- **Total: 4 parallel calls** (instead of 3, but insights removed from initial load)

**Optimization:**
- Use JOIN queries to fetch entries + all related data in **ONE call per month**
- No separate batch queries needed - everything comes in the JOIN response
- Use `Future.wait()` for parallel month queries

#### 2.2 `loadCalendarMoodData()` - Fetch All Mood Data
**Current:**
- Fetches last 12 months from local DB

**New:**
- Fetch **all mood data** from Supabase (no date limit)
- Calendar will show mood indicators for all dates with entries

**Query:**
```dart
// No date filter - fetch all mood data
final response = await _supabase
  .from('entries')
  .select('entry_date, mood_score')
  .eq('user_id', userId);
```

#### 2.3 `getEntryByDate()` - Fetch Insight On-Demand
**Current:**
- Fetches entry + insight together

**New:**
- Fetch entry + related data from Supabase
- Fetch insight from Supabase **only when user clicks** (not during initial load)

---

### 3. Model Updates

#### 3.1 Check Related Models for Supabase Parsing
- `EntrySelfCare` - Check if has `fromSupabaseJson()`
- `EntryMeals` - Check if has `fromSupabaseJson()`
- `EntryAffirmations` - Check if has `fromSupabaseJson()`
- `EntryGratitude` - Check if has `fromSupabaseJson()`
- `EntryPriorities` - Check if has `fromSupabaseJson()`
- `EntryTomorrowNotes` - Check if has `fromSupabaseJson()`

**Action:** Add `fromSupabaseJson()` methods if missing

---

### 4. API Call Optimization (Using JOINs)

#### 4.1 Initial Load (History Screen Open)
**Current:**
- 3 calls: 2 months entries + months list
- Each entry triggers 6 calls for related data (sequential)
- Insights fetched for all entries

**New (With JOINs):**
- **4 calls total** (all parallel):
  1. Current month entries + related data (JOIN query) - **1 call**
  2. Previous month entries + related data (JOIN query) - **1 call**
  3. All mood data for calendar - **1 call**
  4. Months list - **1 call**
- **No insights** during initial load
- **No separate batch queries** - everything comes in JOIN response

**Total API Calls:**
- Initial load: **4 calls** (all parallel)
- Calendar mood: Included in call #3
- Months list: Call #4
- **Grand Total: 4 calls** (vs 12+ in original plan, vs 100+ in current implementation)

**Performance Improvement:**
- Current: ~100+ calls (sequential related data fetches)
- Original plan: 12 calls (batch queries)
- **New plan: 4 calls** (JOIN queries) ✅ **75% reduction from original plan**

#### 4.2 On-Demand (User Clicks Entry)
**Current:**
- Entry already loaded, just fetch insight

**New:**
- Entry + related data already loaded from JOIN query
- Fetch insight from Supabase: **1 call** (only if not already loaded)

#### 4.3 Load More Month (Pagination)
**Current:**
- Fetch month entries + insights

**New:**
- Fetch month entries + related data using JOIN: **1 call** (not 7!)
- **No insights** (fetch on-demand when user clicks)

---

## Implementation Steps

### Step 1: Update `HistoryService`
1. Replace `getEntriesForMonth()` to fetch from Supabase
2. Remove insights fetching from `getEntriesForMonth()`
3. Update `_buildHistoryEntry()` to fetch related data from Supabase
4. Update `getEntryByDate()` to fetch from Supabase
5. Update `getMoodMapForDateRange()` to fetch from Supabase (no date limit)
6. Update `getMonthsWithEntries()` to fetch from Supabase
7. Remove `_getEntryIdsInRange()` helper

### Step 2: Update `HistoryProvider`
1. Update `loadCurrentMonth()` to handle new flow (no insights)
2. Update `loadCalendarMoodData()` to fetch all mood data
3. Update `getEntryByDate()` to fetch insight on-demand

### Step 3: Update Models
**Status Check:**
- ✅ `Entry` - Has `fromSupabaseJson()`
- ✅ `EntryAffirmations` - Has `fromSupabaseJson()`
- ✅ `EntryPriorities` - Has `fromSupabaseJson()`
- ✅ `EntryGratitude` - Has `fromSupabaseJson()`
- ✅ `EntryTomorrowNotes` - Has `fromSupabaseJson()`
- ⚠️ `EntryMeals` - No `fromSupabaseJson()`, but `fromJson()` should work (snake_case matches)
- ⚠️ `EntrySelfCare` - No `fromSupabaseJson()`, **needs update** (Supabase returns boolean, local DB uses int 0/1)
- ⚠️ `EntryShowerBath` - No `fromSupabaseJson()`, **needs update** (Supabase returns boolean, local DB uses int 0/1)

**Action Required:**
1. Add `fromSupabaseJson()` to `EntrySelfCare` (handle boolean values)
2. Add `fromSupabaseJson()` to `EntryShowerBath` (handle boolean values)
3. Test parsing of Supabase JSON responses

### Step 4: Testing
1. Test initial load (2 months)
2. Test calendar mood data (all dates)
3. Test entry click (on-demand insight fetch)
4. Test pagination (load more months)
5. Test with no entries
6. Test with entries older than 7 days

---

## Key Benefits

1. **No Data Loss:** All entries visible, not limited by 7-day retention
2. **Better Performance:** Batch queries for related data
3. **On-Demand Insights:** Faster initial load, fetch insights only when needed
4. **Complete Calendar:** Shows mood for all dates, not just last 6 days
5. **Consistent Data:** Single source of truth (Supabase)

---

## Potential Issues & Solutions

### Issue 1: Network Dependency
**Problem:** History screen requires internet connection
**Solution:** 
- Keep local DB as cache (optional, future enhancement)
- Show error message if offline

### Issue 2: Large Data Sets
**Problem:** Fetching all mood data might be slow
**Solution:**
- Use pagination for calendar mood data (fetch last 12 months initially, load more on scroll)
- Or: Fetch all at once (mood data is lightweight - just date + score)

### Issue 3: Related Data Batch Queries
**Problem:** Need to batch fetch related data for multiple entries
**Solution:**
- Use `inFilter` to fetch all related data for all entry IDs in one query per table
- Example: Fetch all `entry_self_care` for 20 entries in 1 call instead of 20 calls

---

## Files to Modify

1. `lib/services/history_service.dart` - Main service changes
2. `lib/providers/history_provider.dart` - Provider updates
3. `lib/models/entry_models.dart` - Add `fromSupabaseJson()` if missing for related models
4. `lib/services/database/local_entry_service.dart` - **No changes** (keep for other features)

---

## Summary

**Current:** History screen uses local DB (limited by 7-day retention) + Supabase for insights
**Target:** History screen uses Supabase for everything (entries, related data, mood, insights on-demand)

**Key Changes:**
- Replace all local DB queries with Supabase queries
- Use **JOIN queries** to fetch entries + related data in single calls
- Remove insights from initial load (fetch on-demand)
- Fetch all mood data for calendar (no date limit)

**API Calls (Optimized with JOINs):**
- Initial load: **4 calls** (parallel) - 75% reduction!
- Entry click: 1 call (insight, if not already loaded)
- Load more: **1 call** (entry + related data via JOIN)

**Performance:**
- Current: ~100+ sequential calls
- New: **4 parallel calls** for initial load
- **96% reduction in API calls!** 🚀

