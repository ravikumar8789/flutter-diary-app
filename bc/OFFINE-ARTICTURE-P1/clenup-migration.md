# Cleanup Migration — FILO Trigger Plan

**Goal:** Remove Splash cleanup; handle 60-day retention via SQLite trigger (FILO). Faster Splash.

**Assumption:** Fresh install only — no one-time migration cleanup needed.

---

## 1. Desired Flow

| Scenario | Splash fetches | Cleanup |
|----------|----------------|---------|
| **Login** | User, streak, 60-day entries, yesterday insight | None |
| **Resume** | User, streak, entries (last_open → today), yesterday insight | None |
| **Offline** | Nothing (read local only) | None |

Cleanup happens automatically when user saves an entry (trigger fires on INSERT).

---

## 2. SQLite Trigger Design

**Trigger:** `AFTER INSERT ON entries`

On every insert into `entries`, delete rows older than 60 days. Order: related tables first, then `entries`.

**Cutoff:** `date('now', 'localtime', '-60 days')` — 60 days ago in local time.

**Tables to clean (in order):**
1. `entry_affirmations`
2. `entry_priorities`
3. `entry_meals`
4. `entry_gratitude`
5. `entry_self_care`
6. `entry_shower_bath`
7. `entry_tomorrow_notes`
8. `sync_queue`
9. `entry_insights_local` (by `entry_date`, not `entry_id`)
10. `entries`

---

## 3. Trigger SQL

```sql
CREATE TRIGGER cleanup_old_entries_after_insert
AFTER INSERT ON entries
BEGIN
  DELETE FROM entry_affirmations
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_priorities
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_meals
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_gratitude
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_self_care
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_shower_bath
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_tomorrow_notes
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM sync_queue
  WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
  DELETE FROM entry_insights_local
  WHERE entry_date < date('now', 'localtime', '-60 days');
  DELETE FROM entries
  WHERE entry_date < date('now', 'localtime', '-60 days');
END;
```

---

## 4. Migration (v9)

**File:** `lib/services/database/database_manager.dart`

1. Bump `_version` to 9.
2. In `_onUpgrade`: if `oldVersion < 9`, call `_createCleanupTrigger(db)`.
3. Add helper (drop first for idempotency):

```dart
Future<void> _createCleanupTrigger(Database db) async {
  await db.execute('DROP TRIGGER IF EXISTS cleanup_old_entries_after_insert');
  await db.execute('''
    CREATE TRIGGER cleanup_old_entries_after_insert
    AFTER INSERT ON entries
    BEGIN
      DELETE FROM entry_affirmations
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_priorities
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_meals
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_gratitude
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_self_care
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_shower_bath
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_tomorrow_notes
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM sync_queue
      WHERE entry_id IN (SELECT id FROM entries WHERE entry_date < date('now', 'localtime', '-60 days'));
      DELETE FROM entry_insights_local
      WHERE entry_date < date('now', 'localtime', '-60 days');
      DELETE FROM entries
      WHERE entry_date < date('now', 'localtime', '-60 days');
    END;
  ''');
}
```


---

## 5. Remove Splash Cleanup

**File:** `lib/screens/splash_screen.dart`

**Offline path (lines ~117–123):** Remove:
- `entryService.cleanupOldEntries(retentionDays: 60)`
- `EntryInsightStorageHelper.clearEntryInsightsOlderThan(retentionDays: 60)`

**Online path (lines ~179–193):** Remove:
- The "Cleaning up old data..." setState block
- `entryService.cleanupOldEntries(retentionDays: 60)`
- `EntryInsightStorageHelper.clearEntryInsightsOlderThan(retentionDays: 60)`

**Also remove:** `import '../services/entry_insight_storage_helper.dart'` if no longer used.

---

## 6. Execution Order

| Step | Action |
|------|--------|
| 1 | Add trigger in database_manager (migration v9) |
| 2 | Remove cleanup from Splash (offline + online) |
| 3 | Remove unused EntryInsightStorageHelper import from Splash if applicable |

---

## 7. Files to Modify

| File | Changes |
|------|---------|
| `lib/services/database/database_manager.dart` | Bump to v9; add `_createCleanupTrigger`; call in `_onUpgrade` |
| `lib/screens/splash_screen.dart` | Remove all cleanup calls; remove import if unused |

---

## 8. Verification

- [ ] Fresh install: trigger created on first run
- [ ] User saves entry → trigger runs → old entries (>60 days) deleted
- [ ] Splash: no "Cleaning up old data..." step; faster load
- [ ] History: 60-day data still available from local

---

## 9. Rollback

- Revert Splash changes (restore cleanup).
- Add migration to `DROP TRIGGER IF EXISTS cleanup_old_entries_after_insert`.
