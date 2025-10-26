import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/local_entry_service.dart';
import 'supabase_sync_service.dart';
import '../../models/entry_models.dart';
import '../error_logging_service.dart';

class SyncWorker {
  final SupabaseSyncService _syncService = SupabaseSyncService();
  final LocalEntryService _localService = LocalEntryService();
  final Connectivity _connectivity = Connectivity();
  bool _isProcessing = false;

  // Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;

      // Additional check with actual internet connection
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // Log network error with code ERRNET011
      return false;
    }
  }

  // Smart sync processing - only sync if there's pending data
  Future<void> processSyncQueue() async {
    // Prevent multiple simultaneous syncs
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      // Check if there are unsynced entries first (smart optimization)
      final hasUnsyncedData = await _localService.hasUnsyncedEntries();
      if (!hasUnsyncedData) {
        return;
      }

      // Get all unsynced entries
      final unsyncedEntries = await _localService.getUnsyncedEntries();

      if (unsyncedEntries.isEmpty) {
        return;
      }

      // Check if online before processing
      if (!await _isOnline()) {
        return;
      }

      // Process each unsynced entry
      for (final entry in unsyncedEntries) {
        try {
          final success = await _syncService.syncEntry(entry);

          if (success) {
            await _localService.markAsSynced(entry.id);
          }
        } catch (e) {
          // Log sync error to Supabase
          await ErrorLoggingService.logHighError(
            errorCode: 'ERRDATA021',
            errorMessage: 'Sync queue processing failed: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            errorContext: {
              'entry_id': entry.id,
              'entry_date': entry.entryDate.toIso8601String(),
              'sync_attempt': 'background_sync',
            },
          );
        }
      }
    } catch (e) {
      // Error handling - sync will retry later
    } finally {
      _isProcessing = false;
    }
  }

  // Retry sync with exponential backoff (for future use)
  Future<void> retrySync(Entry entry, {int attempt = 1}) async {
    final delays = [Duration.zero, Duration(minutes: 5), Duration(minutes: 15)];

    if (attempt <= delays.length) {
      await Future.delayed(delays[attempt - 1]);

      if (await _isOnline()) {
        try {
          final success = await _syncService.syncEntry(entry);
          if (success) {
            await _localService.markAsSynced(entry.id);
          } else if (attempt < delays.length) {
            await retrySync(entry, attempt: attempt + 1);
          }
        } catch (e) {
          if (attempt < delays.length) {
            await retrySync(entry, attempt: attempt + 1);
          }
        }
      }
    }
  }

  // Start periodic sync (every 15 minutes)
  void startPeriodicSync() {
    Timer.periodic(Duration(minutes: 15), (timer) {
      processSyncQueue();
    });
  }

  // Stop periodic sync
  void stopPeriodicSync() {
    // Timer will be automatically cancelled when the app is disposed
  }
}
