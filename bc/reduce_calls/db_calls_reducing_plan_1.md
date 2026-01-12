# DB Calls Reduction Plan - Comprehensive Implementation

## Executive Summary

**Current State:** 99 requests in 40 seconds (80% duplicates)  
**Target State:** 15-20 requests in 40 seconds  
**Reduction:** 80-85%  
**Severity:** 9/10 (Critical)

---

## Part 1: All Possible Reasons (Complete Analysis)

### A. Riverpod autoDispose Issues
1. **autoDispose refetches on every screen load**
   - `homeSummaryProvider` uses `autoDispose`
   - `recentEntriesProvider` uses `autoDispose`
   - `recentInsightsProvider` uses `autoDispose`
   - `yesterdayInsightProvider` uses `autoDispose`
   - **Impact:** 4-5 providers refetching on every navigation

2. **Widget rebuilds trigger refetches**
   - `autoDispose` + widget rebuild = new query
   - Navigation = dispose + recreate = new query
   - State changes = rebuild = new query
   - **Impact:** Excessive refetches

### B. Multiple Providers Fetching Same Data
3. **Overlapping data fetches**
   - `homeSummaryProvider` fetches entries for today
   - `recentEntriesProvider` fetches entries for current + previous month
   - `historyProvider` fetches entries for current + previous month
   - `HomeSummaryService._fetchWeeklySnapshot()` fetches entries for week
   - **Impact:** Same entries table queried 4+ times

4. **Date range overlap**
   - Multiple providers fetching overlapping date ranges
   - No data sharing between providers
   - **Impact:** Same entries fetched multiple times

### C. No Request Deduplication
5. **No in-flight query tracking**
   - Multiple widgets watching same provider = multiple queries
   - No check if query is already in-flight
   - No shared cache for in-flight requests
   - **Impact:** 9 identical `habits_daily` queries, 10 identical `entries` queries

### D. No Caching Strategy
6. **No memory cache**
   - Every provider fetch = fresh DB query
   - No "stale-while-revalidate" pattern
   - No TTL (Time To Live) for cached data
   - **Impact:** Same data fetched repeatedly

### E. Local Sync Causing Extra Queries
7. **Dual query system**
   - `EntryService.loadEntryForDate()` → checks local, then fetches cloud
   - `SyncWorker.processSyncQueue()` → fetches data during sync
   - Both can run simultaneously
   - **Impact:** Duplicate cloud queries

### F. Multiple Screens/Widgets Using Same Data
8. **Independent data fetching**
   - Home screen → fetches entries
   - Calendar widget → fetches entries
   - History screen → fetches entries
   - Insights screen → fetches entries
   - **Impact:** 4+ queries for same data

### G. No Query Batching
9. **Individual queries**
   - Each provider makes individual queries
   - No `Future.wait()` for parallel queries
   - No combining of similar queries
   - **Impact:** Many small queries instead of few batched queries

### H. No Provider Dependency Management
10. **Independent providers**
    - Providers don't depend on each other
    - No shared base provider for entries
    - Each provider independently fetches
    - **Impact:** No data sharing between providers

---

## Part 2: Plan for Each Reason

### Solution 1: Centralized Data Repository

**File:** `lib/repositories/data_repository.dart`

**Purpose:** Single source of truth for all app data

**Structure:**
```dart
class DataRepository {
  // In-memory cache
  final Map<String, CachedData> _cache = {};
  
  // In-flight requests tracking
  final Map<String, Future> _inFlightRequests = {};
  
  // Cache TTL: 5 minutes
  static const Duration cacheTTL = Duration(minutes: 5);
  
  // Fetch with deduplication and caching
  Future<T> fetch<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? ttl,
  }) async {
    // 1. Check cache first
    if (_cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (!cached.isExpired) {
        return cached.data as T;
      }
    }
    
    // 2. Check if request is in-flight
    if (_inFlightRequests.containsKey(key)) {
      return await _inFlightRequests[key] as T;
    }
    
    // 3. Make request and track it
    final future = fetcher().then((data) {
      _cache[key] = CachedData(data, ttl ?? cacheTTL);
      _inFlightRequests.remove(key);
      return data;
    }).catchError((e) {
      _inFlightRequests.remove(key);
      throw e;
    });
    
    _inFlightRequests[key] = future;
    return await future;
  }
  
  // Invalidate cache
  void invalidate(String key) {
    _cache.remove(key);
  }
  
  // Clear all cache
  void clearCache() {
    _cache.clear();
  }
}
```

**Impact:**
- Eliminates duplicate queries (deduplication)
- Reduces DB calls by 80-90%
- Provides single source of truth

---

### Solution 2: Centralized Fetching Service

**File:** `lib/services/data_fetch_service.dart`

**Purpose:** Centralized service for all data fetching operations

**Structure:**
```dart
class DataFetchService {
  final DataRepository _repository;
  final SupabaseClient _supabase;
  
  // Fetch entries with date range
  Future<List<Entry>> fetchEntries({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final key = 'entries_${userId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
    
    return await _repository.fetch(
      key: key,
      fetcher: () async {
        final response = await _supabase
          .from('entries')
          .select('*')
          .eq('user_id', userId)
          .gte('entry_date', startDate.toIso8601String().split('T')[0])
          .lte('entry_date', endDate.toIso8601String().split('T')[0]);
        
        return (response as List).map((e) => Entry.fromJson(e)).toList();
      },
    );
  }
  
  // Fetch habits_daily with date range
  Future<List<HabitsDaily>> fetchHabitsDaily({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final key = 'habits_${userId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
    
    return await _repository.fetch(
      key: key,
      fetcher: () async {
        final response = await _supabase
          .from('habits_daily')
          .select('*')
          .eq('user_id', userId)
          .gte('date', startDate.toIso8601String().split('T')[0])
          .lte('date', endDate.toIso8601String().split('T')[0]);
        
        return (response as List).map((e) => HabitsDaily.fromJson(e)).toList();
      },
    );
  }
  
  // Batch fetch multiple data types
  Future<BatchData> fetchBatch({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await Future.wait([
      fetchEntries(userId: userId, startDate: startDate, endDate: endDate),
      fetchHabitsDaily(userId: userId, startDate: startDate, endDate: endDate),
      // Add more as needed
    ]);
    
    return BatchData(
      entries: results[0] as List<Entry>,
      habits: results[1] as List<HabitsDaily>,
    );
  }
}
```

**Impact:**
- Centralizes all fetching logic
- Enables batching
- Reduces code duplication
- Makes error handling consistent

---

### Solution 3: Riverpod Providers (Non-autoDispose)

**File:** `lib/providers/data_providers.dart`

**Purpose:** Shared providers using centralized repository

**Structure:**
```dart
// Repository provider (singleton, never disposed)
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  final repo = DataRepository();
  
  // Dispose on app close
  ref.onDispose(() {
    repo.clearCache();
  });
  
  return repo;
});

// Fetch service provider (singleton)
final dataFetchServiceProvider = Provider<DataFetchService>((ref) {
  final repo = ref.watch(dataRepositoryProvider);
  return DataFetchService(repository: repo);
});

// Entries provider (NOT autoDispose, shared across app)
final entriesProvider = FutureProvider.family<List<Entry>, EntryQueryParams>((ref, params) async {
  final service = ref.watch(dataFetchServiceProvider);
  
  try {
    return await service.fetchEntries(
      userId: params.userId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA200',
      errorMessage: 'Failed to fetch entries: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'user_id': params.userId,
        'start_date': params.startDate.toIso8601String(),
        'end_date': params.endDate.toIso8601String(),
      },
    );
    rethrow;
  }
});

// Habits provider (NOT autoDispose, shared across app)
final habitsProvider = FutureProvider.family<List<HabitsDaily>, HabitsQueryParams>((ref, params) async {
  final service = ref.watch(dataFetchServiceProvider);
  
  try {
    return await service.fetchHabitsDaily(
      userId: params.userId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA201',
      errorMessage: 'Failed to fetch habits: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'user_id': params.userId,
        'start_date': params.startDate.toIso8601String(),
        'end_date': params.endDate.toIso8601String(),
      },
    );
    rethrow;
  }
});

// Home summary provider (uses entries + habits providers)
final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  final userId = ref.watch(currentUserProvider).value?.id;
  if (userId == null) return const HomeSummary();
  
  final now = DateTime.now();
  final thisWeekStart = now.subtract(Duration(days: now.weekday % 7));
  final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  
  // Use shared providers instead of fetching directly
  final entries = await ref.watch(entriesProvider(EntryQueryParams(
    userId: userId,
    startDate: thisWeekStart,
    endDate: now,
  )).future);
  
  final habits = await ref.watch(habitsProvider(HabitsQueryParams(
    userId: userId,
    startDate: thisWeekStart,
    endDate: now,
  )).future);
  
  // Build summary from cached data
  return HomeSummary.fromEntriesAndHabits(entries, habits);
});
```

**Impact:**
- Removes autoDispose refetches
- Enables data sharing between providers
- Reduces duplicate queries by 90%

---

### Solution 4: Cache Invalidation Strategy

**File:** `lib/repositories/data_repository.dart` (extension)

**Purpose:** Smart cache invalidation when data changes

**Structure:**
```dart
extension CacheInvalidation on DataRepository {
  // Invalidate entries cache when entry is saved
  void invalidateEntries(String userId, DateTime? date) {
    if (date != null) {
      // Invalidate specific date range
      final keys = _cache.keys.where((k) => 
        k.startsWith('entries_${userId}_') && 
        k.contains(date.toIso8601String().split('T')[0])
      );
      for (final key in keys) {
        invalidate(key);
      }
    } else {
      // Invalidate all entries for user
      final keys = _cache.keys.where((k) => k.startsWith('entries_${userId}_'));
      for (final key in keys) {
        invalidate(key);
      }
    }
  }
  
  // Invalidate habits cache when habit is updated
  void invalidateHabits(String userId, DateTime? date) {
    if (date != null) {
      final keys = _cache.keys.where((k) => 
        k.startsWith('habits_${userId}_') && 
        k.contains(date.toIso8601String().split('T')[0])
      );
      for (final key in keys) {
        invalidate(key);
      }
    } else {
      final keys = _cache.keys.where((k) => k.startsWith('habits_${userId}_'));
      for (final key in keys) {
        invalidate(key);
      }
    }
  }
}
```

**Impact:**
- Ensures fresh data after updates
- Prevents stale data issues
- Maintains cache efficiency

---

### Solution 5: Disposal Strategy

**File:** `lib/repositories/data_repository.dart` (disposal methods)

**Purpose:** Proper resource cleanup

**Structure:**
```dart
class DataRepository {
  // Timer for cache cleanup
  Timer? _cacheCleanupTimer;
  
  DataRepository() {
    // Clean up expired cache every 1 minute
    _cacheCleanupTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _cleanupExpiredCache();
    });
  }
  
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
      .where((e) => e.value.isExpired)
      .map((e) => e.key)
      .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }
  
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = null;
    _inFlightRequests.clear();
    _cache.clear();
  }
}
```

**Impact:**
- Prevents memory leaks
- Cleans up expired cache automatically
- Frees resources properly

---

### Solution 6: Error Logging Integration

**File:** All service files

**Purpose:** Comprehensive error logging throughout

**Structure:**
```dart
// In DataFetchService
Future<List<Entry>> fetchEntries({...}) async {
  try {
    return await _repository.fetch(
      key: key,
      fetcher: () async {
        try {
          final response = await _supabase.from('entries')...;
          return response;
        } catch (e) {
          await ErrorLoggingService.logHighError(
            errorCode: 'ERRDATA200',
            errorMessage: 'DB query failed: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            errorContext: {
              'user_id': userId,
              'start_date': startDate.toIso8601String(),
              'end_date': endDate.toIso8601String(),
              'table': 'entries',
            },
          );
          rethrow;
        }
      },
    );
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA201',
      errorMessage: 'Fetch entries failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'user_id': userId,
        'cache_key': key,
      },
    );
    rethrow;
  }
}
```

**Impact:**
- Tracks all errors
- Helps debug issues
- Provides context for failures

---

## Part 3: Impact Calculation for Each Reason

### Reason A: autoDispose Issues
- **Current Impact:** 40-50 duplicate queries per session
- **After Fix:** 0 duplicate queries
- **Reduction:** 100% of autoDispose duplicates
- **DB Calls Saved:** ~40-50 per user session

### Reason B: Multiple Providers Fetching Same Data
- **Current Impact:** 4-5 queries for same entries
- **After Fix:** 1 query shared across providers
- **Reduction:** 75-80%
- **DB Calls Saved:** ~3-4 per data fetch

### Reason C: No Request Deduplication
- **Current Impact:** 9 identical `habits_daily` queries, 10 identical `entries` queries
- **After Fix:** 1 query per unique request
- **Reduction:** 90-95%
- **DB Calls Saved:** ~18-19 per session

### Reason D: No Caching Strategy
- **Current Impact:** Same data fetched repeatedly
- **After Fix:** Cached data reused (5 min TTL)
- **Reduction:** 70-80% for repeated access
- **DB Calls Saved:** ~30-40 per session

### Reason E: Local Sync Causing Extra Queries
- **Current Impact:** 2-3 queries per entry load (local + cloud)
- **After Fix:** 1 query (cloud only, cached)
- **Reduction:** 50-66%
- **DB Calls Saved:** ~10-15 per session

### Reason F: Multiple Screens/Widgets Using Same Data
- **Current Impact:** 4+ queries for same data
- **After Fix:** 1 query shared via provider
- **Reduction:** 75%
- **DB Calls Saved:** ~3 per data type

### Reason G: No Query Batching
- **Current Impact:** Many small queries
- **After Fix:** Batched queries where possible
- **Reduction:** 20-30%
- **DB Calls Saved:** ~5-10 per session

### Reason H: No Provider Dependency Management
- **Current Impact:** Independent fetches
- **After Fix:** Shared providers
- **Reduction:** 60-70%
- **DB Calls Saved:** ~15-20 per session

---

## Part 4: Overall Impact Calculation

### Current State (Per User Per Session - 40 seconds)
- **Total Requests:** 99
- **Duplicate Requests:** ~79 (80%)
- **Unique Requests:** ~20

### After Implementation (Per User Per Session - 40 seconds)
- **Total Requests:** ~15-20
- **Duplicate Requests:** 0 (0%)
- **Unique Requests:** ~15-20

### Reduction Metrics
- **Absolute Reduction:** 79-84 requests (80-85%)
- **Percentage Reduction:** 80-85%
- **Cost Savings:** 80-85% reduction in Supabase costs

### Scaling Impact

**For 1 User:**
- **Current:** 216,000 requests/day
- **After:** 32,400-43,200 requests/day
- **Savings:** 172,800-183,600 requests/day

**For 1,000 Users:**
- **Current:** 216M requests/day
- **After:** 32.4M-43.2M requests/day
- **Savings:** 172.8M-183.6M requests/day

**For 10,000 Users:**
- **Current:** 2.16B requests/day
- **After:** 324M-432M requests/day
- **Savings:** 1.728B-1.836B requests/day

---

## Part 5: Implementation Plan

### Phase 1: Foundation (Day 1-2)
1. Create `DataRepository` class
   - Cache implementation
   - In-flight request tracking
   - Cache TTL management
   - Error logging integration

2. Create `DataFetchService` class
   - Centralized fetch methods
   - Batch fetch support
   - Error handling
   - Error logging

### Phase 2: Provider Migration (Day 3-4)
3. Create new providers in `data_providers.dart`
   - `entriesProvider` (non-autoDispose)
   - `habitsProvider` (non-autoDispose)
   - `homeSummaryProvider` (uses shared providers)

4. Migrate existing providers
   - Remove `autoDispose` from frequently used providers
   - Update to use `DataFetchService`
   - Add error logging

### Phase 3: Integration (Day 5-6)
5. Update screens to use new providers
   - Home screen
   - History screen
   - Calendar widget
   - Insights screen

6. Add cache invalidation
   - Invalidate on entry save
   - Invalidate on habit update
   - Invalidate on data sync

### Phase 4: Testing & Optimization (Day 7)
7. Test all scenarios
   - Navigation between screens
   - Data updates
   - Cache expiration
   - Error handling

8. Monitor and optimize
   - Check DB call reduction
   - Verify cache hit rates
   - Optimize TTL values

---

## Part 6: Files to Create/Modify

### New Files
1. `lib/repositories/data_repository.dart` - Centralized data repository
2. `lib/services/data_fetch_service.dart` - Centralized fetching service
3. `lib/providers/data_providers.dart` - New shared providers

### Files to Modify
1. `lib/providers/home_summary_provider.dart` - Remove autoDispose, use shared providers
2. `lib/providers/recent_entries_provider.dart` - Remove autoDispose, use shared providers
3. `lib/providers/history_provider.dart` - Use shared providers
4. `lib/providers/entry_provider.dart` - Add cache invalidation on save
5. `lib/services/entry_service.dart` - Add cache invalidation
6. `lib/services/grace_system_service.dart` - Add cache invalidation

---

## Part 7: Disposal Strategy Details

### When to Dispose

1. **App Lifecycle**
   - Dispose `DataRepository` on app close
   - Clear cache on app background (optional, for memory)

2. **User Logout**
   - Clear all cache for logged-out user
   - Dispose user-specific providers

3. **Cache Cleanup**
   - Auto-cleanup expired cache every 1 minute
   - Manual cleanup on memory pressure

4. **Provider Disposal**
   - Non-autoDispose providers: Dispose only on app close
   - AutoDispose providers: Keep for rarely used data only

### Disposal Implementation

```dart
// In main.dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dispose repository on app close
    ref.onDispose(() {
      ref.read(dataRepositoryProvider).dispose();
    });
    
    return MaterialApp(...);
  }
}

// In DataRepository
void dispose() {
  _cacheCleanupTimer?.cancel();
  _cacheCleanupTimer = null;
  _inFlightRequests.clear();
  _cache.clear();
}
```

---

## Part 8: Error Logging Strategy

### Error Codes
- `ERRDATA200` - DB query failed (entries)
- `ERRDATA201` - DB query failed (habits)
- `ERRDATA202` - Cache operation failed
- `ERRDATA203` - Fetch service failed
- `ERRDATA204` - Provider fetch failed

### Logging Points
1. **Repository Level**
   - Cache operations
   - In-flight request tracking
   - Cache cleanup errors

2. **Service Level**
   - DB query failures
   - Batch fetch failures
   - Data transformation errors

3. **Provider Level**
   - Provider fetch failures
   - State update errors
   - Cache invalidation errors

### Error Context
Always include:
- `user_id`
- `operation` (fetch, cache, invalidate)
- `cache_key` (if applicable)
- `date_range` (if applicable)
- `error_type`
- `timestamp`

---

## Part 9: Success Metrics

### Key Performance Indicators (KPIs)

1. **DB Call Reduction**
   - Target: 80-85% reduction
   - Measure: Requests per user session

2. **Cache Hit Rate**
   - Target: >70% cache hits
   - Measure: Cache hits / total requests

3. **Response Time**
   - Target: <100ms for cached data
   - Measure: Average response time

4. **Memory Usage**
   - Target: <50MB cache size
   - Measure: Cache memory footprint

5. **Error Rate**
   - Target: <1% error rate
   - Measure: Errors / total requests

---

## Part 10: Risk Mitigation

### Risks

1. **Stale Data**
   - **Mitigation:** Smart cache invalidation
   - **Fallback:** TTL expiration

2. **Memory Leaks**
   - **Mitigation:** Proper disposal
   - **Fallback:** Cache size limits

3. **Cache Invalidation Issues**
   - **Mitigation:** Comprehensive invalidation strategy
   - **Fallback:** Manual refresh option

4. **Provider State Issues**
   - **Mitigation:** Proper state management
   - **Fallback:** Error boundaries

---

## Conclusion

**Expected Outcome:**
- 80-85% reduction in DB calls
- Improved app performance
- Reduced Supabase costs
- Better user experience
- Scalable architecture

**Implementation Time:** 7 days  
**Priority:** Critical (9/10)  
**Complexity:** Medium-High

