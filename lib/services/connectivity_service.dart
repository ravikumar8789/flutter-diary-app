import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync/sync_worker.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'connectivity_check_stub.dart'
    if (dart.library.io) 'connectivity_check_io.dart' as connectivity_check;

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
          _syncWorker.processSyncQueue();
        }
      } catch (e) {
        // Log connectivity monitoring error
        ErrorLoggingService.logMediumError(
          error: ErrorContext.fromException(
            errorCode: 'ERRNET001',
            severity: ErrorSeverity.medium,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'monitoring_start_time': DateTime.now().toIso8601String(),
              'connectivity_results': results.map((r) => r.toString()).toList(),
            },
          ),
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

  /// Check current connectivity status.
  /// Uses Connectivity + DNS lookup to catch "connected but no internet".
  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }
      return await connectivity_check.hasRealInternet();
    } catch (_) {
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
