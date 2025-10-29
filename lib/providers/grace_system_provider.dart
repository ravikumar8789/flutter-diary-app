import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/grace_system_service.dart';
import '../services/error_logging_service.dart';

class GraceSystemState {
  final bool isLoading;
  final int graceDaysAvailable;
  final double piecesToday;
  final double piecesNeeded;
  final int progressPercentage;
  final int tasksCompletedToday;
  final double gracePiecesTotal;
  final String? error;

  GraceSystemState({
    this.isLoading = false,
    this.graceDaysAvailable = 0,
    this.piecesToday = 0.0,
    this.piecesNeeded = 2.0,
    this.progressPercentage = 0,
    this.tasksCompletedToday = 0,
    this.gracePiecesTotal = 0.0,
    this.error,
  });

  GraceSystemState copyWith({
    bool? isLoading,
    int? graceDaysAvailable,
    double? piecesToday,
    double? piecesNeeded,
    int? progressPercentage,
    int? tasksCompletedToday,
    double? gracePiecesTotal,
    String? error,
  }) {
    return GraceSystemState(
      isLoading: isLoading ?? this.isLoading,
      graceDaysAvailable: graceDaysAvailable ?? this.graceDaysAvailable,
      piecesToday: piecesToday ?? this.piecesToday,
      piecesNeeded: piecesNeeded ?? this.piecesNeeded,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      tasksCompletedToday: tasksCompletedToday ?? this.tasksCompletedToday,
      gracePiecesTotal: gracePiecesTotal ?? this.gracePiecesTotal,
      error: error,
    );
  }
}

class GraceSystemNotifier extends Notifier<GraceSystemState> {
  @override
  GraceSystemState build() => GraceSystemState();

  String? _currentUserId;

  /// Initialize the provider with user data
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _refreshGraceStatus();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA123',
        errorMessage: 'Failed to initialize grace system: $e',
        errorContext: {
          'userId': userId,
          'service': 'GraceSystemNotifier.initialize',
        },
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load grace system data',
      );
    }
  }

  /// Track when user completes tasks
  Future<void> trackTaskCompletion(String taskType, bool completed) async {
    if (_currentUserId == null) {
      return;
    }

    try {
      await GraceSystemService.trackTaskCompletion(
        userId: _currentUserId!,
        date: DateTime.now(),
        taskType: taskType,
        completed: completed,
      );

      // Refresh status with a small delay to ensure database trigger completes
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshGraceStatus();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA124',
        errorMessage: 'Failed to track task completion: $e',
        errorContext: {
          'userId': _currentUserId,
          'taskType': taskType,
          'completed': completed,
          'service': 'GraceSystemNotifier.trackTaskCompletion',
        },
      );
    }
  }

  /// Use a grace day
  Future<bool> useGraceDay() async {
    if (_currentUserId == null) return false;

    try {
      final success = await GraceSystemService.useGraceDay(_currentUserId!);
      if (success) {
        await _refreshGraceStatus();
      }
      return success;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA125',
        errorMessage: 'Failed to use grace day: $e',
        errorContext: {
          'userId': _currentUserId,
          'service': 'GraceSystemNotifier.useGraceDay',
        },
      );
      return false;
    }
  }

  /// Refresh grace status
  Future<void> _refreshGraceStatus() async {
    if (_currentUserId == null) {
      return;
    }

    try {
      final graceStatus = await GraceSystemService.getGraceStatus(
        _currentUserId!,
      );

      if (graceStatus != null) {
        state = state.copyWith(
          graceDaysAvailable: graceStatus['grace_days_available'] ?? 0,
          piecesToday: graceStatus['pieces_today'] ?? 0.0,
          piecesNeeded: 2.0 - (graceStatus['pieces_today'] ?? 0.0),
          progressPercentage: graceStatus['progress_percentage'] ?? 0,
          tasksCompletedToday: graceStatus['tasks_completed_today'] ?? 0,
          gracePiecesTotal: graceStatus['grace_pieces_total'] ?? 0.0,
        );
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA126',
        errorMessage: 'Failed to refresh grace status: $e',
        errorContext: {
          'userId': _currentUserId,
          'service': 'GraceSystemNotifier._refreshGraceStatus',
        },
      );
    }
  }

  /// Refresh grace status (public method)
  Future<void> refreshGraceStatus() async {
    await _refreshGraceStatus();
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider instances
final graceSystemProvider =
    NotifierProvider<GraceSystemNotifier, GraceSystemState>(() {
      return GraceSystemNotifier();
    });
