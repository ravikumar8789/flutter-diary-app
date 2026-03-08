# Offline Architecture — Base Plan (Rough)

## Core Principle
- **Local-first**: Everything stored on Supabase → store locally too
- **Write locally first** → sync to Supabase when online
- **7-day rolling window** for entries (keep data size constant)

---

## Startup Flow

### Auth Check (unchanged)
- Not logged in → Login screen
- Logged in → proceed

### If Online
1. **3 calls only** (run in parallel):
   - User profile + settings (1 call — RPC/view or 2 calls if needed)
   - Entries for week + today
   - Streak detail
2. Store all in local SQLite
3. **No sync on startup** — add any pending updates to sync queue instead
4. Process sync queue (push pending from last session)

### If Offline
- Use last local data
- Proceed with full app
- All writes go to local + sync queue

---

## Sync Queue
- **Everything** goes through sync queue: entries, user profile, user settings, streak
- Extend sync queue schema for entity types: `user_profile`, `user_settings`, `streaks`, `entries`
- Sync order: entries → streak → profile/settings
- Process when online (connectivity restore + periodic)

---

## Local Storage (SQLite)
- Add: `users`, `user_settings` tables (currently missing)
- Already have: `entries`, `streaks`, `habits_daily`, `sync_queue`
- 7-day retention for entries

---

## Streak
- **No** streak calc/sync on startup
- Calculate on entry save → store locally → add to sync queue
- Startup: just fetch (or read local if offline)

---

## Edge Cases
- **First login / no local data + offline**: Show "Connect to load" or block
- **Destructive cache wipe**: Remove — don't invalidate before fetch when offline
- **Auth token expiry**: Long offline may require re-login (acceptable)

---

## UI
- App bar: offline/online indicator
- Optional: "Last synced: X ago"

---

## Benefits
- Reduce startup calls (3 vs many)
- Faster splash (currently 3–4 sec)
- User never blocked offline
- Consistent local-first model
