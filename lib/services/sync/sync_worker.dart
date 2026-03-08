import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/local_entry_service.dart';
import 'supabase_sync_service.dart';
import '../error_logging_service.dart';
import '../../models/error_models.dart';

class SyncWorker {
  final SupabaseSyncService _syncService = SupabaseSyncService();
  final LocalEntryService _localService = LocalEntryService();
  final Connectivity _connectivity = Connectivity();
  bool _isProcessing = false;

  // Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      // connectivity_plus 7.x returns List<ConnectivityResult>
      final results = List<ConnectivityResult>.from(connectivityResult);
      final isNone = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      if (isNone) return false;
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Smart sync processing - entries first, then sync_queue (streak, user_profile, user_settings)
  Future<void> processSyncQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Early exit: nothing to sync
      final hasUnsyncedEntries = await _localService.hasUnsyncedEntries();
      final hasQueueItems = await _localService.hasSyncQueueItems(
        ['streak', 'user_profile', 'user_settings', 'user_profiles', 'error_log'],
      );
      if (!hasUnsyncedEntries && !hasQueueItems) return;

      if (!await _isOnline()) return;

      // 1. Process unsynced entries (batchSaveEntry with full data)
      final unsyncedEntries = await _localService.getUnsyncedEntries();
      for (final entry in unsyncedEntries) {
        try {
          final full = await _localService.getFullEntryForSync(entry.id);
          if (full == null) continue;
          final success = await _syncService.batchSaveEntry(
            entry: full.entry,
            affirmations: full.affirmations,
            priorities: full.priorities,
            meals: full.meals,
            gratitude: full.gratitude,
            selfCare: full.selfCare,
            showerBath: full.showerBath,
            tomorrowNotes: full.tomorrowNotes,
          );
          if (success) await _localService.markAsSynced(entry.id);
        } catch (e) {
          await ErrorLoggingService.logHighError(
            error: ErrorContext.fromException(
              errorCode: 'ERRDATA021',
              severity: ErrorSeverity.high,
              exception: e,
              stackTrace: StackTrace.current,
              errorContext: {
                'entry_id': entry.id,
                'entry_date': entry.entryDate.toIso8601String(),
                'sync_attempt': 'background_sync',
              },
            ),
          );
        }
      }

      // 2. Process sync_queue for streak, user_profile, user_settings
      final queueItems = await _localService.getSyncQueueByEntityTypes(
        ['streak', 'user_profile', 'user_settings', 'user_profiles', 'error_log'],
      );
      for (final item in queueItems) {
        try {
          bool success = false;
          if (item.entityType == 'streak') {
            final streakData = {
              'current': item.data['current'] ?? 0,
              'longest': item.data['longest'] ?? 0,
              'last_entry_date': item.data['last_entry_date'],
              'freeze_credits': item.data['freeze_credits'] ?? 0,
              'grace_pieces_total': item.data['grace_pieces_total'] ?? 0.0,
              'today_date': item.data['today_date'],
              'today_diary': (item.data['today_diary'] as int? ?? 0) == 1,
              'today_affirmations':
                  (item.data['today_affirmations'] as int? ?? 0) == 1,
              'today_gratitude': (item.data['today_gratitude'] as int? ?? 0) == 1,
              'today_self_care_count': item.data['today_self_care_count'] ?? 0,
              'today_grace_pieces': item.data['today_grace_pieces'] ?? 0.0,
            };
            success = await _syncService.batchUpdateStreakData(
              userId: item.entityId,
              streakData: streakData,
            );
          } else if (item.entityType == 'user_profile') {
            success = await _syncService.syncUserProfile(
              item.entityId,
              item.data,
            );
          } else if (item.entityType == 'user_settings') {
            success = await _syncService.syncUserSettings(
              item.entityId,
              item.data,
            );
          } else if (item.entityType == 'user_profiles') {
            success = await _syncService.syncUserProfiles(
              item.entityId,
              item.data,
            );
          } else if (item.entityType == 'error_log') {
            success = await _syncService.insertErrorLog(item.data);
          }
          if (success) {
            await _localService.removeSyncQueueItem(item.id);
          } else {
            await _localService.incrementRetryCount(item.id);
          }
        } catch (e) {
          await ErrorLoggingService.logHighError(
            error: ErrorContext.fromException(
              errorCode: 'ERRDATA022',
              severity: ErrorSeverity.high,
              exception: e,
              stackTrace: StackTrace.current,
              errorContext: {
                'entity_type': item.entityType,
                'entity_id': item.entityId,
                'sync_attempt': 'sync_queue',
              },
            ),
          );
          await _localService.incrementRetryCount(item.id);
        }
      }
    } catch (e) {
      // Sync will retry on next trigger
    } finally {
      _isProcessing = false;
    }
  }

}
