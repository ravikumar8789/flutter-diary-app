# Log Reduction Phase 2 - Complete Service Migration Plan

## Executive Summary

**Goal:** Migrate ALL services to use `DataFetchService` (caching layer) instead of direct Supabase calls.

**Current State:** 
- DataRepository + DataFetchService infrastructure exists ✅
- Only 2 providers use it (entriesProvider, habitsProvider) ❌
- 15+ services still make direct Supabase calls ❌
- Result: 300 calls in 2 minutes (should be ~30-40)

**Target State:**
- All read operations go through DataFetchService ✅
- All services use caching + deduplication ✅
- 80-85% reduction in DB calls ✅
- No breaking changes to existing functionality ✅

**Timeline:** 3-4 days implementation + 1 day testing

---

## Part 1: Services Audit & Classification

### Services Making Direct Supabase Calls (Need Migration)

#### **Category A: High-Frequency Services (Priority 1)**
These are called most frequently and cause the most duplicate calls:

1. **HomeSummaryService** ⚠️ CRITICAL
   - Calls: `streaks`, `habits_daily`, `entries`, `user_settings`
   - Frequency: Every home screen load
   - Impact: 4-5 calls per load, no caching

2. **UserDataService** ⚠️ CRITICAL
   - Calls: `users`, `user_settings`, `streaks`, `entries`
   - Frequency: App startup, profile screen
   - Impact: 3-4 calls per load, no caching

3. **GraceSystemService** ⚠️ CRITICAL
   - Calls: `habits_daily` (ALL records), `streaks`
   - Frequency: Every task completion, streak check
   - Impact: Fetches ALL habits_daily records every time (expensive!)

4. **HistoryService** ⚠️ HIGH
   - Calls: `entries` (with JOINs)
   - Frequency: History screen load, month navigation
   - Impact: Large queries, no caching

5. **AnalyticsService** ⚠️ HIGH
   - Calls: `entries`, `habits_daily`, `entry_meals`, `entry_insights`
   - Frequency: Analytics screen, weekly/monthly views
   - Impact: Multiple queries per screen load

#### **Category B: Medium-Frequency Services (Priority 2)**

6. **AIService**
   - Calls: `entries`, `entry_insights`
   - Frequency: Insight generation, insight display
   - Impact: Moderate

7. **EntryService** (read operations only)
   - Calls: `entries` (single entry fetch)
   - Frequency: Entry load, date navigation
   - Impact: Moderate

#### **Category C: Low-Frequency Services (Priority 3)**

8. **SupabaseSyncService** (read operations)
   - Calls: `entries` (fetch from cloud)
   - Frequency: Sync operations
   - Impact: Low (but should still use cache)

9. **UserPreferenceSyncService**
   - Calls: `user_settings` (upsert only, no read migration needed)
   - Impact: Low

---

## Part 2: DataFetchService Extensions Required

### Current Methods in DataFetchService:
- ✅ `fetchEntries()` - date range
- ✅ `fetchHabitsDaily()` - date range
- ✅ `fetchBatch()` - entries + habits
- ✅ `fetchMonthlyInsightsList()`
- ✅ `fetchMonthlyAnalytics()`

### New Methods Needed:

#### 2.1 User & Settings Methods
```dart
/// Fetch user profile from users table
Future<Map<String, dynamic>?> fetchUserProfile(String userId)

/// Fetch user settings
Future<Map<String, dynamic>?> fetchUserSettings(String userId)

/// Fetch streaks data
Future<Map<String, dynamic>?> fetchStreaks(String userId)
```

#### 2.2 Entry Methods (Extended)
```dart
/// Fetch single entry by date
Future<Entry?> fetchEntryByDate(String userId, DateTime date)

/// Fetch entries with JOINs (for HistoryService)
Future<List<Entry>> fetchEntriesWithJoins({
  required String userId,
  required DateTime startDate,
  required DateTime endDate,
})

/// Fetch entries with specific select columns
Future<List<Map<String, dynamic>>> fetchEntriesWithSelect({
  required String userId,
  required DateTime startDate,
  required DateTime endDate,
  required String select,
})
```

#### 2.3 Habits Methods (Extended)
```dart
/// Fetch ALL habits_daily for user (for GraceSystemService)
/// NOTE: This should be cached with longer TTL (15 minutes)
Future<List<HabitsDaily>> fetchAllHabitsDaily(String userId)

/// Fetch single day habits
Future<HabitsDaily?> fetchHabitsForDate(String userId, DateTime date)
```

#### 2.4 Analytics Methods
```dart
/// Fetch weekly analytics
Future<WeeklyAnalyticsData> fetchWeeklyAnalytics({
  required String userId,
  required DateTime weekStart,
})

/// Fetch entry insights
Future<List<EntryInsight>> fetchEntryInsights({
  required String userId,
  required DateTime? startDate,
  required DateTime? endDate,
  String? entryId,
})
```

#### 2.5 Cache Invalidation Methods (Extended)
```dart
/// Invalidate user settings cache
void invalidateUserSettingsCache(String userId)

/// Invalidate streaks cache
void invalidateStreaksCache(String userId)

/// Invalidate all user data cache
void invalidateAllUserCache(String userId)
```

---

## Part 3: Service Migration Strategy

### Migration Pattern (For Each Service)

**Step 1:** Add DataFetchService dependency
**Step 2:** Replace direct Supabase calls with DataFetchService methods
**Step 3:** Add cache invalidation on write operations
**Step 4:** Test thoroughly
**Step 5:** Remove old direct Supabase code

### Service-by-Service Migration Plan

---

#### **3.1 HomeSummaryService Migration**

**File:** `lib/services/home_summary_service.dart`

**Changes:**
1. Add `DataFetchService` as constructor parameter
2. Replace `_fetchStreak()` → use `dataFetchService.fetchStreaks()`
3. Replace `_fetchTodayProgress()` → use `dataFetchService.fetchHabitsForDate()` + `fetchEntryByDate()`
4. Replace `_fetchWeeklySnapshot()` → use `dataFetchService.fetchBatch()`
5. Replace `_fetchPromptMotivation()` → use `dataFetchService.fetchUserSettings()`

**Cache Invalidation:**
- On entry save → invalidate entries cache
- On habit update → invalidate habits cache
- On streak update → invalidate streaks cache

**Testing:**
- Home screen loads correctly
- All widgets show data
- No duplicate calls in logs

**Risk:** Medium (core service, used everywhere)
**Rollback:** Keep old methods as fallback initially

---

#### **3.2 UserDataService Migration**

**File:** `lib/services/user_data_service.dart`

**Changes:**
1. Add `DataFetchService` as static dependency (or inject via provider)
2. Replace `_fetchUserProfile()` → use `dataFetchService.fetchUserProfile()`
3. Replace `_fetchUserPreferences()` → use `dataFetchService.fetchUserSettings()`
4. Replace `_fetchUserStats()` → use `dataFetchService.fetchStreaks()` + `fetchEntries()`

**Cache Invalidation:**
- On user profile update → invalidate user profile cache
- On settings update → invalidate user settings cache

**Testing:**
- Profile screen loads
- Stats display correctly
- Settings sync works

**Risk:** Low (mostly read operations)
**Rollback:** Easy (static methods, can revert)

---

#### **3.3 GraceSystemService Migration** ⚠️ CRITICAL

**File:** `lib/services/grace_system_service.dart`

**Current Problem:**
- `getGraceStatus()` fetches ALL habits_daily records every time
- Called on every task completion
- No caching = expensive!

**Changes:**
1. Add `DataFetchService` as static dependency
2. Replace `getGraceStatus()` → use `dataFetchService.fetchAllHabitsDaily()` (cached 15 min)
3. Replace `_getOrCreateTodayHabitsRecord()` → use `dataFetchService.fetchHabitsForDate()`
4. Replace streak fetches → use `dataFetchService.fetchStreaks()`

**Cache Invalidation:**
- On task completion → invalidate habits cache for that date
- On streak update → invalidate streaks cache

**Testing:**
- Grace status displays correctly
- Task completion updates properly
- Streak calculation works
- No performance degradation

**Risk:** High (critical feature, complex logic)
**Rollback:** Keep old method as fallback

---

#### **3.4 HistoryService Migration**

**File:** `lib/services/history_service.dart`

**Changes:**
1. Add `DataFetchService` as constructor parameter
2. Replace `getEntriesForMonth()` → use `dataFetchService.fetchEntriesWithJoins()`
3. Replace `getEntryByDate()` → use `dataFetchService.fetchEntryByDate()`
4. Replace `getMoodMapForDateRange()` → use `dataFetchService.fetchEntriesWithSelect()`

**Cache Invalidation:**
- On entry save → invalidate entries cache for that date
- On entry delete → invalidate entries cache

**Testing:**
- History screen loads
- Month navigation works
- Entry details display
- Calendar mood data shows

**Risk:** Medium (used frequently)
**Rollback:** Keep old methods

---

#### **3.5 AnalyticsService Migration**

**File:** `lib/services/analytics_service.dart`

**Changes:**
1. Add `DataFetchService` as constructor parameter
2. Replace `getWeeklyAnalytics()` → use `dataFetchService.fetchWeeklyAnalytics()`
3. Replace `getMonthlyAnalytics()` → already uses DataFetchService (via provider)
4. Replace direct `entries` queries → use `dataFetchService.fetchEntriesWithSelect()`
5. Replace direct `habits_daily` queries → use `dataFetchService.fetchHabitsDaily()`

**Cache Invalidation:**
- On entry save → invalidate analytics cache
- On monthly insight generation → invalidate monthly cache

**Testing:**
- Weekly analytics display
- Monthly analytics display
- Charts render correctly
- No duplicate queries

**Risk:** Medium
**Rollback:** Keep old methods

---

#### **3.6 AIService Migration**

**File:** `lib/services/ai_service.dart`

**Changes:**
1. Add `DataFetchService` as constructor parameter
2. Replace `getRecentInsights()` → use `dataFetchService.fetchEntryInsights()`
3. Replace `getYesterdayInsight()` → use `dataFetchService.fetchEntryInsights()`
4. Replace entry fetches → use `dataFetchService.fetchEntries()`

**Cache Invalidation:**
- On insight generation → invalidate insights cache

**Testing:**
- Insights display correctly
- Recent insights load
- Yesterday insight shows

**Risk:** Low
**Rollback:** Easy

---

#### **3.7 EntryService Migration (Read Operations Only)**

**File:** `lib/services/entry_service.dart`

**Changes:**
1. Add `DataFetchService` as constructor parameter
2. Replace `loadEntryForDate()` read path → use `dataFetchService.fetchEntryByDate()`
3. Keep write operations as-is (they need to invalidate cache)

**Cache Invalidation:**
- On entry save → invalidate entries cache for that date
- On entry delete → invalidate entries cache

**Testing:**
- Entry loads correctly
- Entry save works
- Cache invalidation triggers

**Risk:** Low (only read path changes)
**Rollback:** Easy

---

## Part 4: Implementation Order (Phased Approach)

### Phase 1: Foundation (Day 1)
**Goal:** Extend DataFetchService with all required methods

**Tasks:**
1. Add user & settings methods to DataFetchService
2. Add extended entry methods (with JOINs, select)
3. Add extended habits methods (all records, single date)
4. Add analytics methods
5. Add extended cache invalidation methods
6. Unit tests for all new methods

**Files to Modify:**
- `lib/services/data_fetch_service.dart`

**Testing:**
- Unit tests for each new method
- Verify cache keys are correct
- Verify TTL values are appropriate

---

### Phase 2: High-Priority Services (Day 2)
**Goal:** Migrate services causing most duplicate calls

**Services:**
1. GraceSystemService (CRITICAL - fetches all records)
2. HomeSummaryService (CRITICAL - called on every home load)
3. UserDataService (CRITICAL - called on app startup)

**Approach:**
- Migrate one service at a time
- Test after each migration
- Keep old code commented for rollback

**Testing:**
- Manual testing of each service
- Check logs for duplicate calls reduction
- Verify functionality works

---

### Phase 3: Medium-Priority Services (Day 3)
**Goal:** Migrate remaining frequently-used services

**Services:**
1. HistoryService
2. AnalyticsService
3. AIService

**Approach:**
- Same as Phase 2
- Test thoroughly

**Testing:**
- Full screen testing
- Navigation testing
- Data accuracy verification

---

### Phase 4: Low-Priority & Cleanup (Day 4)
**Goal:** Migrate remaining services and cleanup

**Services:**
1. EntryService (read operations)
2. SupabaseSyncService (read operations)
3. Any other services found

**Tasks:**
1. Final migration
2. Remove commented old code
3. Code cleanup
4. Documentation update

**Testing:**
- End-to-end testing
- Performance testing
- Log analysis

---

## Part 5: Cache Invalidation Strategy

### When to Invalidate Cache

#### 5.1 Entry Operations
- **On Entry Save:** Invalidate entries cache for that date + home summary
- **On Entry Delete:** Invalidate entries cache for that date + home summary
- **On Entry Update:** Invalidate entries cache for that date

**Implementation:**
```dart
// In EntryService.saveEntry()
await dataFetchService.invalidateEntriesCache(userId, entryDate);
await dataFetchService.invalidateHomeSummaryCache(userId);
```

#### 5.2 Habits Operations
- **On Task Completion:** Invalidate habits cache for that date + home summary
- **On Habit Update:** Invalidate habits cache for that date

**Implementation:**
```dart
// In GraceSystemService.trackTaskCompletion()
await dataFetchService.invalidateHabitsCache(userId, date);
await dataFetchService.invalidateHomeSummaryCache(userId);
```

#### 5.3 Streak Operations
- **On Streak Update:** Invalidate streaks cache + home summary

**Implementation:**
```dart
// In UserDataService._persistStreak()
await dataFetchService.invalidateStreaksCache(userId);
await dataFetchService.invalidateHomeSummaryCache(userId);
```

#### 5.4 User Settings Operations
- **On Settings Update:** Invalidate user settings cache + home summary

**Implementation:**
```dart
// In UserPreferenceSyncService.syncPreferences()
await dataFetchService.invalidateUserSettingsCache(userId);
await dataFetchService.invalidateHomeSummaryCache(userId);
```

#### 5.5 Analytics Operations
- **On Monthly Insight Generation:** Invalidate monthly cache
- **On Weekly Insight Generation:** Invalidate weekly cache

**Implementation:**
```dart
// In AIService after insight generation
await dataFetchService.invalidateMonthlyCache(userId, monthStart);
```

---

## Part 6: Testing Strategy

### 6.1 Unit Testing
**For Each New DataFetchService Method:**
- Test cache hit (returns cached data)
- Test cache miss (fetches from DB)
- Test deduplication (same request in-flight)
- Test cache expiration (TTL)
- Test error handling

**Files:**
- `test/services/data_fetch_service_test.dart`

---

### 6.2 Integration Testing
**For Each Migrated Service:**
- Test service methods work correctly
- Test cache invalidation triggers
- Test no duplicate calls (check logs)
- Test error scenarios

**Files:**
- `test/services/home_summary_service_test.dart`
- `test/services/grace_system_service_test.dart`
- etc.

---

### 6.3 Manual Testing Checklist

#### Home Screen
- [ ] Home screen loads without errors
- [ ] Streak displays correctly
- [ ] Today progress shows
- [ ] Weekly snapshot displays
- [ ] Prompt motivation shows
- [ ] No duplicate API calls in logs

#### Profile Screen
- [ ] User profile loads
- [ ] Stats display correctly
- [ ] Settings sync works

#### History Screen
- [ ] History entries load
- [ ] Month navigation works
- [ ] Entry details display
- [ ] Calendar mood data shows
- [ ] No duplicate calls

#### Analytics Screen
- [ ] Weekly analytics display
- [ ] Monthly analytics display
- [ ] Charts render correctly
- [ ] No duplicate calls

#### Grace System
- [ ] Grace status displays
- [ ] Task completion updates
- [ ] Streak calculation works
- [ ] No performance issues

#### Entry Operations
- [ ] Entry loads correctly
- [ ] Entry save works
- [ ] Entry delete works
- [ ] Cache invalidates properly

---

### 6.4 Performance Testing

**Metrics to Track:**
1. **API Call Count:**
   - Before: ~300 calls in 2 minutes
   - Target: ~30-40 calls in 2 minutes
   - Reduction: 85-90%

2. **Cache Hit Rate:**
   - Target: >70% cache hits
   - Measure: Cache hits / total requests

3. **Response Time:**
   - Cached data: <50ms
   - Uncached data: <500ms (same as before)

4. **Memory Usage:**
   - Cache size: <50MB
   - Monitor for leaks

**Tools:**
- Supabase logs (API call count)
- Flutter DevTools (memory, performance)
- Custom logging (cache hit rate)

---

## Part 7: Rollback Plan

### 7.1 If Issues Found During Migration

**Immediate Rollback:**
1. Revert service changes (git revert)
2. Services fall back to direct Supabase calls
3. No data loss (cache is just optimization)

**Partial Rollback:**
- Keep DataFetchService extensions (they're safe)
- Revert specific service if it has issues
- Other services continue using cache

---

### 7.2 If Performance Degrades

**Check:**
1. Cache TTL too short? → Increase TTL
2. Cache not invalidating? → Fix invalidation
3. Memory issues? → Add cache size limits

**Fix:**
- Adjust cache TTL values
- Fix cache invalidation logic
- Add cache size limits if needed

---

### 7.3 If Functionality Breaks

**Debug Steps:**
1. Check error logs
2. Verify cache keys are correct
3. Check cache invalidation is working
4. Test with cache disabled (temporary)

**Fix:**
- Fix cache key generation
- Fix cache invalidation
- Add fallback to direct calls if cache fails

---

## Part 8: Code Quality & Standards

### 8.1 Code Patterns

**Service Constructor Pattern:**
```dart
class ServiceName {
  final DataFetchService _dataFetch;
  final SupabaseClient _supabase; // Keep for write operations
  
  ServiceName({
    DataFetchService? dataFetch,
    SupabaseClient? supabase,
  }) : _dataFetch = dataFetch ?? DataFetchService(...),
       _supabase = supabase ?? Supabase.instance.client;
}
```

**Cache Invalidation Pattern:**
```dart
// After write operation
await _dataFetch.invalidateEntriesCache(userId, date);
await _dataFetch.invalidateHomeSummaryCache(userId);
```

---

### 8.2 Error Handling

**All DataFetchService methods:**
- Log errors with context
- Rethrow errors (don't swallow)
- Include cache key in error context

**All Service migrations:**
- Handle errors gracefully
- Log errors with service context
- Don't break user experience

---

### 8.3 Documentation

**Update:**
- Service class documentation
- Method documentation
- Cache invalidation points
- Migration notes

---

## Part 9: Success Criteria

### 9.1 Quantitative Metrics

✅ **API Call Reduction:**
- Before: 300 calls in 2 minutes
- After: 30-40 calls in 2 minutes
- Target: 85-90% reduction

✅ **Cache Hit Rate:**
- Target: >70% cache hits
- Measure after 1 day of usage

✅ **Performance:**
- Cached responses: <50ms
- No degradation in app performance

---

### 9.2 Qualitative Metrics

✅ **Functionality:**
- All features work as before
- No user-facing bugs
- No data inconsistencies

✅ **Code Quality:**
- All services use DataFetchService
- No direct Supabase calls for reads
- Proper cache invalidation everywhere

✅ **Maintainability:**
- Code is cleaner
- Easier to debug
- Better error handling

---

## Part 10: Implementation Checklist

### Pre-Implementation
- [ ] Review plan with team
- [ ] Set up testing environment
- [ ] Prepare rollback strategy
- [ ] Create feature branch

### Phase 1: Foundation
- [ ] Extend DataFetchService with user methods
- [ ] Extend DataFetchService with entry methods
- [ ] Extend DataFetchService with habits methods
- [ ] Extend DataFetchService with analytics methods
- [ ] Add cache invalidation methods
- [ ] Write unit tests
- [ ] Test all new methods

### Phase 2: High-Priority Services
- [ ] Migrate GraceSystemService
- [ ] Test GraceSystemService
- [ ] Migrate HomeSummaryService
- [ ] Test HomeSummaryService
- [ ] Migrate UserDataService
- [ ] Test UserDataService
- [ ] Verify call reduction in logs

### Phase 3: Medium-Priority Services
- [ ] Migrate HistoryService
- [ ] Test HistoryService
- [ ] Migrate AnalyticsService
- [ ] Test AnalyticsService
- [ ] Migrate AIService
- [ ] Test AIService
- [ ] Verify call reduction in logs

### Phase 4: Low-Priority & Cleanup
- [ ] Migrate EntryService (read)
- [ ] Migrate SupabaseSyncService (read)
- [ ] Remove commented code
- [ ] Code cleanup
- [ ] Documentation update

### Final Testing
- [ ] Manual testing (all screens)
- [ ] Performance testing
- [ ] Log analysis (verify reduction)
- [ ] Memory leak check
- [ ] End-to-end testing

### Deployment
- [ ] Code review
- [ ] Merge to main
- [ ] Monitor logs for 24 hours
- [ ] Verify metrics meet targets

---

## Part 11: Risk Mitigation

### Risk 1: Breaking Existing Functionality
**Mitigation:**
- Migrate one service at a time
- Keep old code commented initially
- Thorough testing after each migration
- Easy rollback per service

### Risk 2: Cache Stale Data
**Mitigation:**
- Proper cache invalidation on all writes
- TTL values appropriate (5 min default, 15 min for expensive queries)
- Manual refresh option if needed

### Risk 3: Memory Issues
**Mitigation:**
- Cache cleanup every 1 minute (already implemented)
- Monitor cache size
- Add cache size limits if needed

### Risk 4: Performance Degradation
**Mitigation:**
- Cache hit should be faster than DB call
- Monitor response times
- Adjust TTL if needed

### Risk 5: Complex Service Logic
**Mitigation:**
- Start with simple services
- Migrate complex services carefully
- Keep old logic as reference
- Test extensively

---

## Part 12: Post-Implementation Monitoring

### Week 1: Intensive Monitoring
- Check logs daily
- Monitor API call count
- Check cache hit rate
- Monitor error rates
- Check memory usage

### Week 2-4: Regular Monitoring
- Weekly log analysis
- Performance metrics
- User feedback
- Bug reports

### Ongoing: Maintenance
- Monthly review
- Optimize cache TTL if needed
- Add new methods as services evolve
- Keep documentation updated

---

## Conclusion

This plan provides a comprehensive, phased approach to migrating all services to use the caching layer. By following this plan:

1. **All services will use DataFetchService** ✅
2. **80-90% reduction in API calls** ✅
3. **No breaking changes** ✅
4. **Easy rollback if needed** ✅
5. **Thoroughly tested** ✅

**Estimated Timeline:** 4-5 days
**Risk Level:** Medium (mitigated by phased approach)
**Expected Impact:** 85-90% reduction in DB calls

---

**Ready for implementation after approval!** 🚀

