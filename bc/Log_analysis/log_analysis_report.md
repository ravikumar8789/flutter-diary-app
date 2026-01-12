# Supabase Log Analysis - High DB Calls for Single User

## Summary
**User ID:** `f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8`  
**IP:** `223.228.157.11` (single device)  
**Time Window:** ~40 seconds  
**Total Requests:** 99 requests (excluding system/health checks)

---

## Critical Issues Found

### 1. **Duplicate Queries - Same Data Fetched Multiple Times**

#### `habits_daily` for date range `2025-12-28 to 2026-01-03`:
- **9 identical queries** in 40 seconds
- Lines: 9, 10, 23, 35, 44, 46, 58, 61, 63
- **Waste:** 8 unnecessary queries (89% waste)

#### `entries` for date range `2025-12-28 to 2026-01-03`:
- **10 identical queries** in 40 seconds
- Lines: 11, 14, 26, 32, 38, 45, 48, 60, 62, 65
- **Waste:** 9 unnecessary queries (90% waste)

#### `entry_insights` for same date range:
- **4 identical queries**
- Lines: 13, 17, 50, 53
- **Waste:** 3 unnecessary queries (75% waste)

#### `weekly_insights`:
- **5 queries** (some duplicates)
- Lines: 22, 27, 34, 39, 57, 74, 78
- **Waste:** 2-3 unnecessary queries

---

## Root Causes

### 1. **No Request Deduplication**
- Multiple widgets/screens fetching same data independently
- No check if query is already in-flight
- Result: 10+ identical queries fired simultaneously

### 2. **No Caching Strategy**
- Every screen load = fresh DB query
- No memory cache for recent data
- No "stale-while-revalidate" pattern

### 3. **Multiple Components Fetching Same Data**
- Home screen fetches entries
- Calendar widget fetches entries
- Insights screen fetches entries
- Each makes separate query

### 4. **Rapid Navigation**
- User switching screens quickly
- Each navigation triggers fresh queries
- No debouncing/throttling

### 5. **No Query Batching**
- Each component makes individual query
- Could batch multiple queries into one

---

## Impact

### Current State:
- **99 requests in 40 seconds** = ~2.5 requests/second
- **~80% are duplicates** = ~79 wasted requests
- **Should be:** ~20 requests (80% reduction)

### For 1 User:
- **Per minute:** ~150 requests
- **Per hour:** ~9,000 requests
- **Per day:** ~216,000 requests

### For 1,000 Users:
- **Per day:** ~216M requests
- **Cost:** Massive (Supabase charges per request)

---

## Solutions

### 1. **Implement Request Deduplication**
```dart
// Check if same query is already in-flight
// Share result across all callers
```

### 2. **Add Caching Layer**
```dart
// Cache recent queries (5-10 minutes)
// Use cached data, refresh in background
```

### 3. **Centralize Data Fetching**
```dart
// Single provider for entries/habits
// All widgets use same cached data
```

### 4. **Debounce Navigation Queries**
```dart
// Wait 200-300ms before fetching
// Cancel if user navigates away
```

### 5. **Batch Queries**
```dart
// Combine multiple queries into one
// Use Future.wait() for parallel queries
```

---

## Expected Improvement

**After fixes:**
- **Current:** 99 requests in 40 seconds
- **Target:** ~15-20 requests in 40 seconds
- **Reduction:** 80-85%

**For 1,000 users:**
- **Current:** ~216M requests/day
- **Target:** ~32-43M requests/day
- **Savings:** ~173-184M requests/day

---

## Priority: **CRITICAL** 🔴

This is causing:
1. High Supabase costs
2. Slow app performance
3. Poor user experience
4. Unnecessary server load

**Fix immediately before scaling.**

