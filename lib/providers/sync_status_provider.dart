import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/error_logging_service.dart';

enum SyncStatus { idle, syncing, saved, error }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSavedAt;

  SyncState({required this.status, this.errorMessage, this.lastSavedAt});

  SyncState copyWith({
    SyncStatus? status,
    String? errorMessage,
    DateTime? lastSavedAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncState &&
        other.status == status &&
        other.errorMessage == errorMessage &&
        other.lastSavedAt == lastSavedAt;
  }

  @override
  int get hashCode {
    return status.hashCode ^ errorMessage.hashCode ^ lastSavedAt.hashCode;
  }
}

class SyncStatusNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState(status: SyncStatus.idle);

  void setSyncing() {
    state = SyncState(status: SyncStatus.syncing);
  }

  void setSaved() {
    state = SyncState(status: SyncStatus.saved, lastSavedAt: DateTime.now());
  }

  void setError(String message) {
    // Log sync status error
    ErrorLoggingService.logMediumError(
      errorCode: 'ERRSYS021',
      errorMessage: 'Sync status error: $message',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'sync_status': state.status.name,
        'error_time': DateTime.now().toIso8601String(),
        'error_message': message,
      },
    );

    state = SyncState(status: SyncStatus.error, errorMessage: message);
  }

  void setIdle() {
    state = SyncState(status: SyncStatus.idle);
  }

  void clearError() {
    if (state.status == SyncStatus.error) {
      state = SyncState(status: SyncStatus.idle);
    }
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncState>(
  () => SyncStatusNotifier(),
);
