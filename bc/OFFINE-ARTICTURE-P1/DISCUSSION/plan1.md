# Offline Architecture — Pyramid Plan (Brief)

## Level 1 — Strategy (Top)
- **Source of truth:** SQLite
- **Supabase:** Sync, cloud backup, AI, history (later)
- **No in-memory cache** — read from SQLite
- **Writes:** Local first → sync queue → Supabase when online
- **Scope:** Home screen only (now)

---

## Level 2 — Components in Scope
| Component | Status |
|-----------|--------|
| Home screen | In scope (cards already local) |
| Streak | In scope (critical) |
| User profile/settings | In scope |
| Entries (7-day) | In scope |
| History, analysis | Later |

---

## Level 3 — Per-Component Logic

### Streak
- **Startup online:** Fetch → compare `Supabase.updated_at` vs `local.last_sync_at` → if Supabase newer, recalc & update local
- **Startup offline:** Read local only
- **Entry save:** Recalc → update local → add to sync queue

### User Profile
- **Startup online:** Fetch → store in local `users` table
- **Startup offline:** Read local

### Entries
- Already local-first; sync queue handles

---

## Level 4 — Streak Edge Cases (Critical)
1. Offline 2–3 days, save entries → recalc on save, sync when online
2. Grace day used offline → persist locally, add to sync queue
3. **Remove destructive** `last_sync_at = null` before fetch
4. Local unsynced + fetch → process sync queue first, then compare timestamps
5. New user, no streak → initialize 0

---

## Level 5 — Execution Order
1. Add `users` table locally
2. Remove destructive `last_sync_at = null` in `calculateStreakOnAppLaunch`
3. Add timestamp comparison for streak
4. Extend sync queue (streak, profile)
5. Startup: read local first when offline
6. Streak recalc on save → sync queue
