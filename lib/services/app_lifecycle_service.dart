import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync/sync_worker.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import '../providers/privacy_lock_provider.dart';
import '../providers/entry_provider.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  final SyncWorker _syncWorker = SyncWorker();
  bool _isObserving = false;
  ProviderContainer? _container;

  // Start observing app lifecycle changes
  void startObserving({ProviderContainer? container}) {
    if (_isObserving) {
      return;
    }

    _isObserving = true;
    _container = container;
    WidgetsBinding.instance.addObserver(this);
  }

  // Stop observing app lifecycle changes
  void stopObserving() {
    if (!_isObserving) {
      return;
    }

    _isObserving = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    try {
      switch (state) {
        case AppLifecycleState.resumed:
          _syncWorker.processSyncQueue();

          // Check privacy lock auto-lock
          _checkPrivacyLockAutoLock();
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
          // Force immediate save before app closes
          if (_container != null) {
            try {
              final entryNotifier = _container!.read(entryProvider.notifier);
              entryNotifier.forceImmediateSave();
            } catch (e) {
              ErrorLoggingService.logMediumError(
                error: ErrorContext.fromException(
                  errorCode: 'ERRSYS022',
                  severity: ErrorSeverity.medium,
                  exception: e,
                  stackTrace: StackTrace.current,
                  errorContext: {
                    'lifecycle_state': state.toString(),
                    'operation': 'force_save_on_close',
                  },
                ),
              );
            }
          }
          // App is going to background - start auto-lock timer
          _startAutoLockTimer();
          break;
        case AppLifecycleState.inactive:
          break;
        case AppLifecycleState.hidden:
          break;
      }
    } catch (e) {
      // Log app lifecycle error
      ErrorLoggingService.logMediumError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS021',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'lifecycle_state': state.toString(),
            'state_change_time': DateTime.now().toIso8601String(),
          },
        ),
      );
    }
  }

  /// Check if app should be locked due to auto-lock timeout
  void _checkPrivacyLockAutoLock() {
    if (_container == null) return;

    try {
      final privacyLockNotifier = _container!.read(
        privacyLockProvider.notifier,
      );
      privacyLockNotifier.checkAutoLock();
    } catch (e) {

    }
  }

  /// Start auto-lock timer when app goes to background
  void _startAutoLockTimer() {
    if (_container == null) return;

    try {
      final privacyLockData = _container!.read(privacyLockProvider);
      if (privacyLockData.isEnabled && privacyLockData.isUnlocked) {
        // Auto-lock timer is handled by the privacy lock provider
        // This is just a placeholder for future timer implementation

      }
    } catch (e) {

    }
  }

  // Dispose resources
  void dispose() {
    stopObserving();
  }
}
