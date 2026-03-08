# Yesterday Insight — Local Store Plan

**Goal:** Store yesterday's AI insight locally so it works offline. Supabase is always source of truth (server-generated). No timestamp merge.

---

## 1. Design

| Rule | Detail |
|------|--------|
| **Table** | Single-purpose: holds only yesterday's insight (1 row per user) |
| **Merge** | None. Online fetch → overwrite local. Supabase always wins. |
| **Offline** | Read from local only. Show last stored insight or null. |
| **Prefetch** | Add to Splash `Future.wait` (Option A) when online |

---

## 2. Local Table Schema

**Table:** `yesterday_insight` (single row per user)

```sql
CREATE TABLE yesterday_insight (
  user_id TEXT PRIMARY KEY,
  id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  entry_date TEXT NOT NULL,
  summary TEXT,
  insight_text TEXT,
  insight_details TEXT,
  sentiment_label TEXT,
  processed_at TEXT NOT NULL
);
```

- One row per user. `user_id` as primary key → overwrite on each fetch.
- No `entry_insights` clone; minimal columns for `DailyInsight`.

---

## 3. Files to Modify

| File | Changes |
|------|---------|
| `lib/services/database/database_manager.dart` | Add `yesterday_insight` table, migration (v6→v7) |
| `lib/services/data_prefetch_service.dart` | Add `fetchAndStoreYesterdayInsight(userId, dataFetchService)` |
| `lib/services/ai_service.dart` | Add `getYesterdayInsightFromLocal(userId)`, `storeYesterdayInsight(userId, insight)` |
| `lib/providers/home_summary_provider.dart` | Make `yesterdayInsightProvider` local-first + connectivity |
| `lib/screens/splash_screen.dart` | Add `fetchAndStoreYesterdayInsight` to `Future.wait` |

---

## 4. Step-by-Step Plan

### Step 4.1 — Database

**File:** `database_manager.dart`

1. Bump version: `_version = 7`
2. In `_onUpgrade`: if `oldVersion < 7`, create `yesterday_insight` table
3. In `_createTables`: add `yesterday_insight` for fresh installs

---

### Step 4.2 — DataPrefetchService

**File:** `data_prefetch_service.dart`

Add:

```dart
/// Fetch yesterday's insight from Supabase and store locally (overwrite).
/// Only when online. No timestamp merge — Supabase is source of truth.
static Future<void> fetchAndStoreYesterdayInsight(
  String userId,
  DataFetchService dataFetchService,
) async {
  try {
    final insight = await dataFetchService.fetchYesterdayInsightFromSupabase(userId);
    if (insight != null) {
      await EntryInsightStorageHelper.storeYesterdayInsight(userId, insight);
    } else {
      await EntryInsightStorageHelper.clearYesterdayInsight(userId);
    }
  } catch (e) {
    ErrorLoggingService.logMediumError(...);
  }
}
```

---

### Step 4.3 — DataFetchService

**File:** `data_fetch_service.dart`

Add:

```dart
/// Fetch yesterday's insight from Supabase only (no local).
Future<Map<String, dynamic>?> fetchYesterdayInsightFromSupabase(String userId) async {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-...';
  final response = await _supabase
      .from('entry_insights')
      .select('id, entry_id, summary, insight_text, insight_details, sentiment_label, processed_at, status, entries!inner(entry_date, user_id)')
      .eq('entries.user_id', userId)
      .eq('entries.entry_date', yesterdayStr)
      .eq('status', 'success')
      .maybeSingle();
  return response as Map<String, dynamic>?;
}
```

---

### Step 4.4 — EntryInsightStorageHelper (new)

**File:** `lib/services/entry_insight_storage_helper.dart` (new)

- `storeYesterdayInsight(userId, Map<String, dynamic> insight)` — DELETE WHERE user_id, INSERT
- `clearYesterdayInsight(userId)` — DELETE WHERE user_id
- `getYesterdayInsightFromLocal(userId)` — SELECT, return `DailyInsight?` or null

---

### Step 4.5 — Splash Screen

**File:** `splash_screen.dart`

Add to `Future.wait` (online path only):

```dart
await Future.wait([
  DataPrefetchService.fetchAndMergeUserProfile(...),
  DataPrefetchService.fetchAndMergeUserSettings(...),
  ...,
  DataPrefetchService.fetchAndStoreYesterdayInsight(user.id, dataFetchService),
]);
```

---

### Step 4.6 — yesterdayInsightProvider

**File:** `home_summary_provider.dart`

Change logic:

1. Read from local first: `EntryInsightStorageHelper.getYesterdayInsightFromLocal(userId)`
2. If local has data → return it
3. If local empty and online → call `AIService.getYesterdayInsight(userId)`, store via helper, return
4. If offline → return local (may be null)

Requires `ConnectivityService.isOnline()` or equivalent.

---

### Step 4.7 — AIService

**File:** `ai_service.dart`

- Keep `getYesterdayInsight` as Supabase-only (used when provider fetches online)
- Add `storeYesterdayInsight` or rely on `EntryInsightStorageHelper` in provider

---

## 5. Execution Order

1. Add `yesterday_insight` table + migration in `database_manager.dart`
2. Create `EntryInsightStorageHelper` with store/clear/get
3. Add `fetchYesterdayInsightFromSupabase` in `DataFetchService`
4. Add `fetchAndStoreYesterdayInsight` in `DataPrefetchService`
5. Add prefetch to Splash `Future.wait`
6. Update `yesterdayInsightProvider` to local-first + connectivity

---

## 6. Verification

- [ ] Online: Splash prefetches → Home shows yesterday insight
- [ ] Offline: Home shows last stored insight (or empty state)
- [ ] No ERRAI005 when offline
- [ ] Table holds at most 1 row per user

---

## 7. Rollback

Revert code. Table can remain (no harm) or add migration to drop in next version.
