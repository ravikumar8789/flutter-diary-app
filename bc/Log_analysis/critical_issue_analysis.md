# Critical Issue Analysis - 900 Calls in 3 Minutes (INCREASED from 300)

## Executive Summary

**Problem:** After implementing caching system, calls INCREASED from 300/2min to 900/3min (3x worse!)

**Root Cause:** Cache invalidation cascade + simultaneous refetches from multiple providers

---

## Log Analysis (100 sample lines)

### Key Patterns Found:

1. **habits_daily for 2026-01-08**: 10+ identical GET queries
   - Lines: 47, 50, 57, 61, 70, 73, 81, 85, 94, 97
   - All within seconds of each other

2. **streaks GET queries**: 20+ queries
   - Lines: 6, 12, 46, 58, 69, 74, 82, 87, 93, 98
   - Same query repeated constantly

3. **entries GET (wide range)**: 10+ queries
   - Lines: 7, 8, 9, 13, 38, 39, 40, 52, 63, 76, 88, 99
   - All fetching same date range `2016-01-01 to 2026-01-08`

4. **Write → Read Cascade Pattern**:
   ```
   PATCH habits_daily (line 45)
   → GET streaks (line 46)
   → GET habits_daily (line 47)
   → GET habits_daily (line 50)  [DUPLICATE!]
   → PATCH habits_daily (line 55)
   → GET habits_daily (line 57)  [DUPLICATE!]
   ```

---

## Root Causes Identified

### 1. **Cache Invalidation Cascade** ⚠️ CRITICAL

**Problem:** One write operation triggers multiple cache invalidations, each causing refetches.

**Example Flow:**
```
EntryProvider.saveDiaryText()
  → invalidateEntriesCache()
  → invalidateHomeSummaryCache()
  → invalidateMonthlyCache()
  → GraceSystemProvider.trackTaskCompletion()
    → PATCH habits_daily
    → invalidateHabitsCache()
    → invalidateStreaksCache()
    → _refreshGraceStatus() [refetches habits + streaks]
  → UserDataService.recalculateStreak()
    → invalidateStreaksCache()
    → refetches streaks
  → HomeSummaryProvider (watching cache)
    → refetches ALL data (streaks, habits, entries, settings)
```

**Result:** 1 write = 10+ reads

### 2. **No Request Deduplication for Cache Invalidation** ⚠️ CRITICAL

**Problem:** When cache is invalidated, multiple providers watching the same data ALL refetch simultaneously.

**Code Issue:**
```dart
// entry_provider.dart:150
fetchService.invalidateEntriesCache(userId, date);
fetchService.invalidateHomeSummaryCache(userId);

// grace_system_provider.dart:100
await _refreshGraceStatus(); // Refetches habits + streaks

// home_summary_provider.dart:162
final dataFetchService = ref.watch(dataFetchServiceProvider);
// This triggers refetch when cache invalidated
```

**Result:** Cache invalidation → 5 providers refetch same data → 5 duplicate queries

### 3. **Provider Rebuilds Trigger Refetches** ⚠️ HIGH

**Problem:** Riverpod providers using `ref.watch()` rebuild when cache invalidated, triggering new fetches.

**Issue:**
- `homeSummaryProvider` uses `ref.watch(dataFetchServiceProvider)`
- When cache invalidated, provider rebuilds
- Rebuild triggers new fetch
- Multiple widgets watching same provider = multiple refetches

### 4. **No Debouncing/Batching** ⚠️ HIGH

**Problem:** All refetches happen immediately after invalidation, no batching.

**Missing:**
- No debounce timer for cache invalidations
- No batch invalidation (invalidate all at once, refetch once)
- No "stale-while-revalidate" pattern

### 5. **Write Operations Triggering Reads** ⚠️ MEDIUM

**Problem:** After every PATCH/POST, services immediately refetch to verify.

**Example:**
```dart
// grace_system_service.dart:204
await _supabase.from('habits_daily').update(...);
dataFetchService.invalidateHabitsCache(userId, date);
// Then immediately:
final habits = await dataFetchService.fetchHabitsForDate(...); // NEW QUERY!
```

---

## Why It's WORSE Than Before

### Before (300 calls/2min):
- Direct queries, no caching
- Duplicates from multiple widgets
- **But:** No invalidation cascade

### After (900 calls/3min):
- Caching added ✅
- **But:** Cache invalidation triggers cascade of refetches ❌
- **But:** Multiple providers all refetch simultaneously ❌
- **But:** No deduplication for invalidation-triggered refetches ❌

**Net Result:** Caching helps, but invalidation cascade makes it WORSE overall.

---

## Solutions Required

### 1. **Batch Cache Invalidation** (Priority 1)
- Invalidate all related caches in one operation
- Debounce invalidation (wait 100-200ms before refetch)
- Single refetch after batch invalidation

### 2. **Request Deduplication for Invalidation** (Priority 1)
- Track in-flight refetches after invalidation
- If same query already in-flight, reuse it
- Don't allow multiple simultaneous refetches

### 3. **Stale-While-Revalidate Pattern** (Priority 2)
- Return stale cache immediately
- Refetch in background
- Update when ready

### 4. **Reduce Invalidation Scope** (Priority 2)
- Only invalidate what actually changed
- Don't invalidate entire home summary for single entry
- Use more granular cache keys

### 5. **Provider Optimization** (Priority 3)
- Use `ref.read()` instead of `ref.watch()` where possible
- Avoid provider rebuilds triggering refetches
- Use `keepAlive` for providers that shouldn't refetch

---

## Immediate Fixes Needed

1. **Add debouncing to cache invalidation**
2. **Add request deduplication for invalidation-triggered refetches**
3. **Reduce invalidation cascade** - only invalidate what changed
4. **Batch invalidations** - collect all invalidations, execute once

---

## Expected Impact After Fixes

- **Current:** 900 calls/3min = 300 calls/min
- **Target:** 50-80 calls/3min = 16-27 calls/min
- **Reduction:** 85-90%

