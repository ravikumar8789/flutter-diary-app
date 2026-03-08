%% Sync Queue Flow - Birth to Death | Paste into mermaid.live or mermaid.ai
flowchart TB
    subgraph SCHEMA["sync_queue Schema: id, entry_id, entity_type, entity_id, table_name, operation, data, created_at, retry_count"]
        S1["entity_type: entry|streak|user_profile|user_settings|user_profiles|error_log"]
    end

    subgraph BIRTH["BIRTH — Rows Enter sync_queue"]
        subgraph ENTRY["Entry Path (entity_type=entry) — 1-8 rows per batch, NO dedup"]
            B1["User edits diary/affirmations/priorities/meals/gratitude/self_care/shower_bath/tomorrow_notes"]
            B1 --> B2["EntryProvider.updateDiaryText / updateAffirmations / updatePriorities / etc"]
            B2 --> B3["_scheduleBatchSave — 3s debounce"]
            B3 --> B4["_executeBatchSave"]
            B4 --> B5["_savePendingChangesToLocal"]
            B5 --> B6["upsertEntry + upsertAffirmations + upsertPriorities + upsertMeals + upsertGratitude + upsertSelfCare + upsertShowerBath + upsertTomorrowNotes"]
            B6 --> B7["Each upsert → _addToSyncQueue → addToSyncQueue INSERT"]
        end

        subgraph STREAK["Streak Path (entity_type=streak) — DEDUPES before insert"]
            B8["Streak updated: streaks.is_synced=0"]
            B8 --> B9["addStreakToSyncQueue — called from: entry_provider._checkGapsAndRecalculateStreak, grace_system_service.recordTaskCompletion, grace_system_service.useGraceDay, user_data_service.recalculateStreak"]
            B9 --> B10["DELETE sync_queue WHERE entity_type=streak AND entity_id=userId"]
            B10 --> B11["addToSyncQueue INSERT"]
        end

        subgraph OTHER["Other Paths"]
            B12["UserPreferenceSyncService.syncNotificationSettingsToCloud"] --> B13["addToSyncQueue — user_settings"]
            B14["UserPreferenceSyncService.syncAppearanceToCloud"] --> B15["addToSyncQueue — user_profiles"]
            B16["UserDataService.fetchOrCreateUser — first login"] --> B17["addToSyncQueue — user_profile"]
            B18["ErrorLoggingService — offline or Supabase insert fails"] --> B19["_addErrorLogToSyncQueue — error_log"]
        end
    end

    B7 --> SQ[(sync_queue)]
    B11 --> SQ
    B13 --> SQ
    B15 --> SQ
    B17 --> SQ
    B19 --> SQ

    subgraph TRIGGERS["processSyncQueue TRIGGERS"]
        T1["EntryProvider._executeBatchSave — after batch save"]
        T2["AppLifecycleService — AppLifecycleState.resumed"]
        T3["ConnectivityService — connectivity changes to online"]
        T4["HomeScreen._triggerSyncOnLand — when coming from Splash"]
    end

    subgraph PROCESS["PROCESSING — SyncWorker.processSyncQueue"]
        P[processSyncQueue]
        P --> P0{_isProcessing?}
        P0 -->|Yes| EXIT1[return]
        P0 -->|No| P1["hasUnsyncedEntries = COUNT entries WHERE is_synced=0"]
        P1 --> P2["hasQueueItems = COUNT sync_queue WHERE entity_type IN streak,user_profile,user_settings,user_profiles,error_log AND retry_count < 10"]
        P2 --> P3{hasUnsyncedEntries OR hasQueueItems?}
        P3 -->|No| EXIT1
        P3 -->|Yes| P4{_isOnline?}
        P4 -->|No| EXIT1
        P4 -->|Yes| P5["PHASE 1: Entries — NOT from sync_queue!"]
        P5 --> P5a["getUnsyncedEntries — entries WHERE is_synced=0"]
        P5a --> P5b["getFullEntryForSync — entry + affirmations, priorities, meals, gratitude, selfCare, showerBath, tomorrowNotes"]
        P5b --> P5c["batchSaveEntry RPC — Supabase batch_save_entry"]
        P5c --> P5d["markAsSynced — UPDATE entries is_synced=1; DELETE sync_queue WHERE entry_id=?"]
        P5d --> P6["PHASE 2: sync_queue for streak, user_*, error_log"]
        P6 --> P6a["getSyncQueueByEntityTypes — retry_count < 10"]
        P6a --> P6b{"For each item"}
        P6b --> P6c["streak → batchUpdateStreakData RPC"]
        P6b --> P6d["user_profile → syncUserProfile users.upsert"]
        P6b --> P6e["user_settings → syncUserSettings user_settings.upsert"]
        P6b --> P6f["user_profiles → syncUserProfiles user_profiles.upsert"]
        P6b --> P6g["error_log → insertErrorLog error_logs.insert"]
        P6c --> P6h{success?}
        P6d --> P6h
        P6e --> P6h
        P6f --> P6h
        P6g --> P6h
        P6h -->|Yes| P6i["removeSyncQueueItem — DELETE WHERE id=?"]
        P6h -->|No| P6j["incrementRetryCount — retry_count+1"]
    end

    T1 --> P
    T2 --> P
    T3 --> P
    T4 --> P

    subgraph DEATH["DEATH — Rows Leave sync_queue"]
        subgraph ENTRY_DEATH["Entry Rows (entity_type=entry)"]
            D1["markAsSynced — after batchSaveEntry success"] --> D1a["DELETE WHERE entry_id=?"]
            D2["EntryStorageHelper.storeEntryWithRelatedData — when storing fetched entry from Supabase"] --> D2a["DELETE WHERE entry_id=?"]
            D3["UserDataCleanupService.clearUserData — on logout"] --> D3a["DELETE WHERE entry_id IN user entries"]
            D4["DatabaseManager.cleanup_old_entries_after_insert trigger / clearOldEntries — 60-day retention"] --> D4a["DELETE WHERE entry_id IN old entries"]
        end

        subgraph NON_ENTRY_DEATH["Non-Entry Rows"]
            D5["removeSyncQueueItem — after successful SyncWorker sync of streak/user_profile/user_settings/user_profiles/error_log"] --> D5a["DELETE WHERE id=?"]
        end

        subgraph FULL_WIPE["Full Wipe"]
            D6["DatabaseManager.clearAllData — testing"] --> D6a["DELETE FROM sync_queue"]
        end

        subgraph RETRY["Retry Exhaustion — not deleted, just ignored"]
            D7["incrementRetryCount — retry_count >= 10"]
            D8["markSyncItemFailed — retry_count=999"]
        end
    end

    subgraph NOTE["KEY: Entry sync_queue rows are REDUNDANT — SyncWorker never reads entity_type=entry. Entries sync via entries.is_synced. Offline → markAsSynced never runs → rows accumulate"]
        N1["Overpopulation: 3 edits = 3 batch saves = 24+ rows for same entry"]
    end
