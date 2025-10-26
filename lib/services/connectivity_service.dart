import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync/sync_worker.dart';
import 'error_logging_service.dart';

class ConnectivityService {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final SyncWorker _syncWorker = SyncWorker();
  bool _isMonitoring = false;

  // Start monitoring connectivity changes
  void startMonitoring() {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      try {
        // Check if any connection is available
        final hasConnection = results.any(
          (result) => result != ConnectivityResult.none,
        );

        if (hasConnection) {
          // Only sync if there's pending data (smart optimization)
          _syncWorker.processSyncQueue();
        }
      } catch (e) {
        // Log connectivity monitoring error
        ErrorLoggingService.logMediumError(
          errorCode: 'ERRNET001',
          errorMessage: 'Connection monitoring failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'monitoring_start_time': DateTime.now().toIso8601String(),
            'connectivity_results': results.map((r) => r.toString()).toList(),
          },
        );
      }
    });
  }

  // Stop monitoring connectivity changes
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    _isMonitoring = false;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // Check current connectivity status
  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  // Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
