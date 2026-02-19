# Week Card Calculation After Login - Fix Plan

**Date:** February 2025  
**Issue:** After login, week cards show null/0; correct values appear only after app restart  
**Root Cause:** homeSummaryProvider fetches before prefetch completes; local DB empty when calculation runs

---

## 🎯 OBJECTIVE

Ensure week card calculation runs **after** week data is fetched and stored locally. Show shimmer during wait. Non-blocking on failure. No impact on normal startup or other flows.

---

## 📊 SCOPE

| Flow | Affected? |
|------|-----------|
| Login → Home | **Yes** – wait for prefetch, show shimmer |
| Splash → Home (normal startup) | **No** – prefetch already done in Splash |
| App resume from background | **No** |
| Other screens | **No** |

---

## 🔧 IMPLEMENTATION STEPS

### Step 1: Add State Variables

**File:** `lib/screens/home_screen.dart`

**Location:** `_HomeScreenState` class (around line 91)

**Add:**
```dart
bool _needsFetch = false;      // true when 7-day prefetch required
bool _prefetchComplete = false; // true when prefetch done (or not needed)
```

**Purpose:** Track prefetch state so we can keep loading until data is in local DB.

---

### Step 2: Update Loading Condition

**Current:** `if (isLoading && userData == null)`

**New:** `if ((isLoading && userData == null) || (_needsFetch && !_prefetchComplete))`

**Logic:**
- Show loading when user data is loading, OR
- When we need prefetch and it hasn't completed yet

---

### Step 3: Replace Prefetch Trigger Logic

**Current:** Fire-and-forget `_handlePrefetchAfterLogin(user.id)`

**New:** Async flow with state updates:

```dart
if (user != null && !_hasCheckedPrefetch) {
  _hasCheckedPrefetch = true;
  _runPrefetchAndWait(user.id);
}

void _runPrefetchAndWait(String userId) async {
  try {
    final needsFetch = await DataSyncFlagService.needsDataFetch();
    if (!mounted) return;
    setState(() => _needsFetch = needsFetch);

    if (needsFetch) {
      try {
        final dataFetchService = ref.read(dataFetchServiceProvider);
        await DataPrefetchService.prefetch7DaysData(userId, dataFetchService);
        await DataSyncFlagService.clearNeedsDataFetch();
        dataFetchService.invalidateHomeSummaryCache(userId);
        ref.invalidate(homeSummaryProvider);
      } catch (e) {
        await ErrorLoggingService.logHighError(...); // ERRSYS184
        // Non-blocking: allow user to proceed with possibly stale data
      } finally {
        if (mounted) setState(() => _prefetchComplete = true);
      }
    } else {
      if (mounted) setState(() => _prefetchComplete = true);
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(...); // ERRSYS185
    if (mounted) setState(() {
      _needsFetch = false;
      _prefetchComplete = true;
    });
  }
}
```

**Key:** `finally` ensures `_prefetchComplete = true` even on failure → non-blocking.

---

### Step 4: Add Shimmer Week Card Skeleton

**File:** `lib/screens/home_screen.dart`

**Location:** After `_skeletonTodayCard` (around line 508)

**Add:**
```dart
Widget _skeletonWeekCard(BuildContext context) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _skeletonBase(context, height: 20, width: 20, radius: 10),
          const SizedBox(height: 6),
          _skeletonBase(context, height: 18, width: 40, radius: 6),
          const SizedBox(height: 2),
          _skeletonBase(context, height: 12, width: 60, radius: 6),
          const SizedBox(height: 2),
          _skeletonBase(context, height: 10, width: 50, radius: 6),
        ],
      ),
    ),
  );
}
```

---

### Step 5: Update Loading UI with Shimmer

**Current:** Generic `CircularProgressIndicator` + "Loading your data..."

**New:** Layout with shimmer week cards (matches final layout):

```dart
return Scaffold(
  appBar: null,
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _skeletonBase(context, height: 24, width: 120, radius: 6),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final info = ResponsiveInfo.of(context);
            final columns = responsiveCardCrossAxisCount(info);
            final spacing = ResponsiveTokens.spacingM(info);
            final totalSpacing = spacing * (columns - 1);
            final cardWidth = (constraints.maxWidth - totalSpacing) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(4, (_) => SizedBox(
                width: cardWidth,
                child: _skeletonWeekCard(context),
              )),
            );
          },
        ),
      ],
    ),
  ),
);
```

**Note:** Requires `ResponsiveInfo.of(context)` and `responsiveCardCrossAxisCount` – already imported/used in home_screen.

---

### Step 6: Refactor _handlePrefetchAfterLogin

**Option A:** Keep `_handlePrefetchAfterLogin` but have it return `Future<void>` and be awaited by `_runPrefetchAndWait`. Caller handles setState.

**Option B:** Replace with `_runPrefetchAndWait` that encapsulates the full flow (as in Step 3).

**Recommendation:** Option B – single method, clearer flow.

---

## 📋 EDGE CASES

| Case | Handling |
|------|----------|
| Prefetch fails (network, timeout) | `finally` sets `_prefetchComplete = true` → user can proceed |
| needsDataFetch() throws | catch → set `_needsFetch = false`, `_prefetchComplete = true` |
| Widget unmounted during prefetch | Check `mounted` before every `setState` |
| needsFetch = false (daily user) | Set `_prefetchComplete = true` immediately → no wait |
| User navigates away | `mounted` check prevents setState on disposed widget |
| Normal startup (Splash → Home) | `_handlePrefetchAfterLogin` never runs (userData already loaded) |

---

## 🔒 FLOWS TO PRESERVE

| Flow | Verification |
|------|---------------|
| Splash → Home | userData loaded in Splash → no loading branch → no change |
| Login → Home, needsFetch = true | Wait for prefetch + shimmer → show content with correct data |
| Login → Home, needsFetch = false | Show content immediately (no wait) |
| Prefetch fails | Unblock after error, show content (may show 0s) |
| Restart after login | No change – flag already stored by clearNeedsDataFetch |

---

## 🚨 ERROR LOGGING

| Error Code | When | Operation |
|------------|------|-----------|
| ERRSYS184 | prefetch7DaysData throws | home_prefetch_after_login |
| ERRSYS185 | needsDataFetch() or outer catch | home_check_prefetch |

**Context:** user_id, operation, exception, stackTrace

**Non-blocking:** All errors log, then `_prefetchComplete = true` so user can proceed.

---

## 📁 FILES TO MODIFY

| File | Changes |
|------|---------|
| `lib/screens/home_screen.dart` | State vars, loading condition, prefetch flow, shimmer skeleton, loading UI |

**No changes:** splash_screen, login_screen, data_sync_flag_service, data_prefetch_service, home_summary_service, providers

---

## ✅ TESTING CHECKLIST

- [ ] Login → Home: week cards show correct data (no restart needed)
- [ ] Login → Home: shimmer visible during prefetch
- [ ] Prefetch fails: user can still use app (non-blocking)
- [ ] needsFetch = false: content shows immediately
- [ ] Normal startup (Splash → Home): unchanged
- [ ] Restart after login: normal flow, no regression
- [ ] Error logs captured for prefetch failure

---

## 📊 SUMMARY

- **Change:** Gate main content on prefetch completion when needsFetch; show shimmer while waiting
- **Non-blocking:** Prefetch failure → unblock user
- **Scope:** Login → Home path only
- **No impact:** Normal startup, other screens, related functionality
