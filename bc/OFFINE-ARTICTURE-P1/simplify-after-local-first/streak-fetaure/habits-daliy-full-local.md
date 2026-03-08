# habits_daily — Full Local Plan

## Context

- **Supabase:** `habits_daily` table removed.
- **Local SQLite:** `habits_daily` kept for local-first (today's diary, affirmations, gratitude, self-care, grace).
- **Goal:** Make all habits_daily reads/writes local-only; remove any Supabase fetches.

---

## Flow (Target)

```
App → read/write habits_daily in local SQLite only
      (no Supabase fetch; table removed from cloud)
```

---

## Audit: Supabase habits_daily Usage

| File | Location | Status |
|------|----------|--------|
| `data_fetch_service.dart` | `fetchHabitsForDate` | **REMOVED** — was Supabase fallback when local empty |
| `analytics_service.dart` | `getWeeklyAnalytics` | **REMOVED** — commented block deleted |
| `analytics_service.dart` | `getMonthlyAnalytics` | **REMOVED** — commented block deleted |
| `supabase_sync_service.dart` | `syncHabitsDaily` | Already removed (note only) |

---

## Changes Made

### 1. data_fetch_service.dart — `fetchHabitsForDate`

**Before:** Local-first, then Supabase fallback when local empty.

**After:** Local-only. When local empty → return `null`. No Supabase call.

**Removed:** ~27 lines (Supabase fetch + local cache insert).

---

## Already Local-Only (No Change)

| File | Usage |
|------|-------|
| `user_data_service.dart` | `db.query('habits_daily', ...)` — local only |
| `grace_system_service.dart` | `db.query/update/insert('habits_daily', ...)` — local only |
| `home_summary_service.dart` | `db.query('habits_daily', ...)` — local fallback when no DataFetchService |
| `notification_service.dart` | `db.query('habits_daily', ...)` — local only |
| `database_manager.dart` | Table creation — local schema |
| `data_prefetch_service.dart` | `_fetchHabits` → `fetchHabitsDaily` — already local-only (deprecated method) |

---

## Total Removal Count

**3** Supabase habits_daily references removed:

1. `data_fetch_service.dart` — `fetchHabitsForDate` Supabase fallback (active code)
2. `analytics_service.dart` — `getWeeklyAnalytics` commented block (habits_daily fetch)
3. `analytics_service.dart` — `getMonthlyAnalytics` commented block (habits_daily fetch)

**1** misleading comment updated: `grace_system_service.dart` — "Supabase expects UUID" → "local-only"

---

## Verification

- [ ] Week card shows correct values offline (no fetchHabitsForDate Supabase failure).
- [ ] Home summary loads offline.
- [ ] Grace system, streak, today progress work offline.
