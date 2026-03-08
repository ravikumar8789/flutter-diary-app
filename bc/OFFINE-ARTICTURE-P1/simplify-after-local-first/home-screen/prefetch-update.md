# Home Prefetch & Sync Update

## Goal

1. Splash: fetch/load only — no `processSyncQueue()`
2. Home: trigger sync on land; when from login, prefetch first (incl. streaks) then sync
3. Add `fetchAndMergeStreaks` to Home prefetch (align with Splash)

---

## Changes

### 1. Splash — remove processSyncQueue

| Path | Remove |
|------|--------|
| Offline | `syncWorker.processSyncQueue()` before navigate |
| Online | `syncWorker.processSyncQueue()` before navigate |

### 2. Home — add streaks to prefetch

Add `DataPrefetchService.fetchAndMergeStreaks(userId, dataFetchService)` to `_runPrefetchAndWait` (with profile, settings, entries, yesterday insight).

### 3. Home — trigger sync on land

| Scenario | Action |
|----------|--------|
| From Splash (lastFetchDate != null) | Trigger `processSyncQueue()` in initState/postFrameCallback |
| From login (lastFetchDate == null) | Prefetch runs → in finally, trigger `processSyncQueue()` |

### 4. Order (login path)

```
prefetch (profile, settings, streaks, entries, yesterday insight)
  → setLastFetchDate, invalidate providers
  → processSyncQueue() (fire-and-forget)
```

---

## Files

| File | Change |
|------|--------|
| `lib/screens/splash_screen.dart` | Remove 2× processSyncQueue calls |
| `lib/screens/home_screen.dart` | Add fetchAndMergeStreaks; add sync trigger (Splash path + login path finally) |

---

## Other triggers (unchanged)

- Entry save → processSyncQueue
- App resume → processSyncQueue
- Connectivity change → processSyncQueue

---

## Implemented

- Splash: removed processSyncQueue (offline + online); removed _getSyncWorker
- Home: added fetchAndMergeStreaks to prefetch; added _triggerSyncOnLand in finally; added _triggerSyncIfFromSplash for Splash path
