# Sync Fix After Offline Migration

**Problem:** Entries (diary, affirmations, priorities, meals, etc.) are not syncing to Supabase after the Phase 3.8/4.12 queue-only migration.

**Root cause:** SyncWorker syncs entries via `entries.is_synced=0`, but `EntryProvider._savePendingChangesToLocal` never sets `isSynced: false` when saving. The entry is passed as-is (often `isSynced: true` from cloud load), so SyncWorker never finds unsynced entries.

**Scope:** Entries only. Streak, error_log, user_profile, user_settings, user_profiles sync correctly (they use sync_queue entity types that SyncWorker processes).

---

## 1. Primary Fix: Mark Entry Unsynced on Save

**File:** `lib/providers/entry_provider.dart`

**Change:** In `_savePendingChangesToLocal`, when calling `upsertEntry`, pass an entry with `isSynced: false` so SyncWorker will pick it up.

**Current:**
```dart
await localService.upsertEntry(entry);
```

**New:**
```dart
await localService.upsertEntry(
  entry.copyWith(isSynced: false, updatedAt: DateTime.now()),
);
```

**Rationale:** Any save (diary, affirmations, priorities, etc.) modifies data that must sync. Marking the entry unsynced ensures `hasUnsyncedEntries()` returns true and SyncWorker processes it via `batchSaveEntry` (which includes all sub-data).

---

## 2. Optional: Clean Up sync_queue on Entry Sync

**File:** `lib/services/database/local_entry_service.dart`

**Change:** When `markAsSynced(entryId)` is called, optionally remove sync_queue rows for that entry_id (entity_type='entry'). These rows are redundant—SyncWorker uses `entries.is_synced` for entries, not sync_queue. Cleaning up prevents unbounded growth.

**Location:** In `markAsSynced`, after updating the entry:
```dart
await db.delete('sync_queue', where: 'entry_id = ?', whereArgs: [entryId]);
```

**Note:** Only remove rows where `entry_id` matches. The sync_queue uses `entry_id` for entry-related items (affirmations, priorities, etc. all have the same entry_id).

---

## 3. Optional: Remove Debug Print Statements

**Files:** Added for debugging; remove when fix is verified:
- `lib/services/sync/sync_worker.dart` — `[SyncWorker]` prints
- `lib/services/database/local_entry_service.dart` — `[LocalEntryService]` prints in `hasUnsyncedEntries`, `hasSyncQueueItems`
- `lib/services/connectivity_service.dart` — `[ConnectivityService]` print
- `lib/services/app_lifecycle_service.dart` — `[AppLifecycleService]` print
- `lib/providers/entry_provider.dart` — `[EntryProvider]` prints
- `lib/screens/splash_screen.dart` — `[SplashScreen]` prints

---

## 4. Verification

- [ ] Add affirmation → wait for debounce → check console: `hasUnsyncedEntries=true`, entry synced
- [ ] Add diary text → same
- [ ] Offline: add data → go online → sync should run (connectivity or app resume)
- [ ] Debug UI: sync_queue `entity_type='entry'` count should drop (or stay low) after sync; entries table `is_synced` should flip to 1 after sync

---

## 5. Execution Order

1. Apply primary fix (section 1).
2. Test. If sync works, optionally apply section 2 (cleanup) and section 3 (remove prints).
