# Error Log — Sync Queue Plan

**Goal:** Route error_log writes through sync queue when offline so errors are not lost. No other sync features affected.

---

## 1. Design

| Rule | Detail |
|------|--------|
| **Online** | Direct Supabase insert (current behavior) |
| **Offline** | Add to sync_queue with `entity_type = 'error_log'` |
| **Direct insert fails** | Fallback: add to sync_queue (don't lose error) |
| **Call sites** | No changes — only ErrorLoggingService internals change |

**No local `error_logs` table.** Use existing `sync_queue.data` (JSON) to hold the error payload.

---

## 2. Files to Modify

| File | Change |
|------|--------|
| `lib/services/error_logging_service.dart` | Add connectivity check; on offline/failure → add to sync queue |
| `lib/services/sync/sync_worker.dart` | Include `error_log` in queue processing |
| `lib/services/sync/supabase_sync_service.dart` | Add `insertErrorLog(Map payload)` |

**No changes:** `local_entry_service.dart` (already supports any `entity_type`), `database_manager.dart`, call sites.

---

## 3. Step-by-Step Plan

### Step 3.1 — ErrorLoggingService

**File:** `lib/services/error_logging_service.dart`

1. Add imports: `ConnectivityService`, `LocalEntryService`, `DatabaseManager` (for DB access if needed).
2. In `logError()` (single entry point for all log methods):
   - Build `finalError` as today (no change).
   - Get payload: `final payload = finalError.toJson()`.
   - **If online:** `try { await _supabase.from('error_logs').insert(payload); } catch (_) { await _addErrorLogToSyncQueue(payload); }`
   - **If offline:** `await _addErrorLogToSyncQueue(payload)`.
3. Add `_addErrorLogToSyncQueue(Map<String, dynamic> payload)`:
   - Call `LocalEntryService().addToSyncQueue(entityType: 'error_log', entityId: '${DateTime.now().millisecondsSinceEpoch}', tableName: 'error_logs', operation: 'insert', data: payload)`.
   - Wrap in try/catch — on failure, do nothing (never throw).
4. Use `connectivity_plus` directly in ErrorLoggingService (e.g. `Connectivity().checkConnectivity() != none`) to avoid circular import with ConnectivityService. Lightweight check is enough.

**Edge case:** During app init, DB may not be open. `addToSyncQueue` uses `DatabaseManager().database` which opens DB. If that throws, we silently fail (no change from current behavior).

---

### Step 3.2 — SupabaseSyncService

**File:** `lib/services/sync/supabase_sync_service.dart`

Add:

```dart
/// Insert error log to Supabase (used by SyncWorker for queued error_logs).
Future<bool> insertErrorLog(Map<String, dynamic> payload) async {
  try {
    await _supabase.from('error_logs').insert(payload);
    return true;
  } catch (e) {
    return false;
  }
}
```

Do **not** call `ErrorLoggingService` from here (avoids recursion). Return false on failure; SyncWorker will increment retry.

---

### Step 3.3 — SyncWorker

**File:** `lib/services/sync/sync_worker.dart`

1. **hasSyncQueueItems:** Add `'error_log'` to the list:
   ```dart
   final hasQueueItems = await _localService.hasSyncQueueItems(
     ['streak', 'user_profile', 'user_settings', 'user_profiles', 'error_log'],
   );
   ```

2. **getSyncQueueByEntityTypes:** Add `'error_log'`:
   ```dart
   final queueItems = await _localService.getSyncQueueByEntityTypes(
     ['streak', 'user_profile', 'user_settings', 'user_profiles', 'error_log'],
   );
   ```

3. **Loop:** Add branch for `error_log`:
   ```dart
   } else if (item.entityType == 'error_log') {
     success = await _syncService.insertErrorLog(item.data);
   }
   ```

**Order:** Process `error_log` after streak/user_profile/user_settings/user_profiles (or in same loop — order doesn’t matter for error_log). No change to entry sync or other entity types.

---

## 4. Isolation — No Other Sync Features Affected

| Component | Impact |
|-----------|--------|
| Entry sync | Unchanged — still processes unsynced entries first |
| Streak sync | Unchanged — same logic |
| User profile/settings | Unchanged — same logic |
| sync_queue schema | Unchanged — `entity_type` is TEXT, `error_log` is a new value |
| hasSyncQueueItems | Extended with one more type — backward compatible |
| getSyncQueueByEntityTypes | Extended with one more type — backward compatible |
| addToSyncQueue | Unchanged — already generic |

---

## 5. Execution Order

1. Add `insertErrorLog` to SupabaseSyncService.
2. Update SyncWorker to process `error_log` queue items.
3. Update ErrorLoggingService with connectivity check and queue fallback.

---

## 6. Verification

- [ ] Online: errors go directly to Supabase (unchanged).
- [ ] Offline: errors added to sync_queue; no "Failed to log error to Supabase" prints.
- [ ] Back online: SyncWorker pushes queued error_logs to Supabase.
- [ ] Entry/streak/profile sync still works as before.

---

## 7. Rollback

Revert the three files. No migrations or schema changes.
