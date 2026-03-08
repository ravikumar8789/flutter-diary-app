# Removal Plan 2 — Local-First Cleanup (Tracking)

> Track all work items for local-first optimization and dead code removal.

---

## 1. Direct Supabase (No Local-First)

| # | Item | File | Status |
|---|------|------|--------|
| 1.1 | SupportTicketService — submitTicket, getUserTickets | `lib/services/support_ticket_service.dart` | ⬜ |
| 1.2 | TimezoneService — updateUserTimezone | `lib/services/timezone_service.dart` | ⬜ |

---

## 2. Local Write, No Sync Queue (habits_daily deprecated — local only)

| # | Item | File | Status |
|---|------|------|--------|
| 2.1 | Remove habits_daily sync — syncHabitsDaily, habitsData in batchUpdateStreakData | `lib/services/sync/supabase_sync_service.dart` | ✅ |

---

## 3. Dead / Unused Code

| # | Item | File | Status |
|---|------|------|--------|
| 3.1 | AIService.triggerWeeklyAnalysis (never called) | `lib/services/ai_service.dart` | ✅ |
| 3.2 | SupabaseSyncService.syncHabitsDaily (never called) | `lib/services/sync/supabase_sync_service.dart` | ✅ (done in §2) |
| 3.3 | Legacy sync: syncAffirmations, syncPriorities, etc. | `lib/services/sync/supabase_sync_service.dart` | ✅ (not present) |
| 3.4 | syncEntry + retrySync (unused pair) | `supabase_sync_service.dart`, `sync_worker.dart` | ✅ (not present) |
| 3.5 | startPeriodicSync, stopPeriodicSync | `lib/services/sync/sync_worker.dart` | ✅ (not present) |
| 3.6 | DataFetchService.fetchHabitsDaily (deprecated) | `lib/services/data_fetch_service.dart` | ⏭️ skip (in use) |
| 3.7 | debug_check_habits.dart | `lib/debug_check_habits.dart` | ✅ |

---

## 4. Consolidation / Cleanup

| # | Item | File | Status |
|---|------|------|--------|
| 4.1 | EntryService — replace _isOnline with ConnectivityService().isOnline() | `lib/services/entry_service.dart` | ✅ (already uses ConnectivityService) |
| 4.2 | Remove debug prints (🔥 STREAK DEBUG) | `data_fetch_service.dart`, `grace_system_service.dart`, `user_data_service.dart` | ✅ |

---

## 5. Offline Fixes (From Audit)

| # | Item | File | Status |
|---|------|------|--------|
| 5.1 | HomeSummaryService — use useLocalOnly when offline (This Week card) | `lib/services/home_summary_service.dart` | ⬜ |
| 5.2 | DataFetchService.fetchHabitsForDate — use local when offline | `lib/services/data_fetch_service.dart` | ⬜ |
| 5.3 | HistoryService — getMonthsWithEntries, getMoodMapForDateRange local-first | `lib/services/history_service.dart` | ⬜ |

---

## Progress

| Category | Done | Total |
|----------|------|-------|
| 1. Direct Supabase | 0 | 2 |
| 2. Local Write No Sync | 1 | 1 |
| 3. Dead Code | 6 | 7 |
| 4. Consolidation | 2 | 2 |
| 5. Offline Fixes | 0 | 3 |
| **Total** | **9** | **15** |
