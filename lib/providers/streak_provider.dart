import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data_fetch_service.dart';
import '../services/user_data_service.dart';
import '../services/grace_system_service.dart';
import '../repositories/data_repository.dart';

/// Streak state
class StreakState {
  final int current;
  final int longest;
  final int graceDaysAvailable;
  final double gracePiecesTotal;
  final double piecesToday;
  final bool isLoading;
  final String? error;

  StreakState({
    this.current = 0,
    this.longest = 0,
    this.graceDaysAvailable = 0,
    this.gracePiecesTotal = 0.0,
    this.piecesToday = 0.0,
    this.isLoading = false,
    this.error,
  });

  StreakState copyWith({
    int? current,
    int? longest,
    int? graceDaysAvailable,
    double? gracePiecesTotal,
    double? piecesToday,
    bool? isLoading,
    String? error,
  }) {
    return StreakState(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      graceDaysAvailable: graceDaysAvailable ?? this.graceDaysAvailable,
      gracePiecesTotal: gracePiecesTotal ?? this.gracePiecesTotal,
      piecesToday: piecesToday ?? this.piecesToday,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Streak provider
class StreakNotifier extends Notifier<StreakState> {
  final DataFetchService _dataFetchService = DataFetchService(repository: DataRepository());
  String? _userId;

  @override
  StreakState build() {
    return StreakState();
  }

  /// Initialize streak data
  Future<void> initialize(String userId) async {
    if (_userId == userId && !state.isLoading) return;
    
    _userId = userId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch streak data
      final streakData = await _dataFetchService.fetchStreaks(userId);
      
      // Fetch grace status
      final graceStatus = await GraceSystemService.getGraceStatus(
        userId,
        dataFetchService: _dataFetchService,
      );

      if (streakData != null && graceStatus != null) {
        state = state.copyWith(
          current: streakData['current'] as int? ?? 0,
          longest: streakData['longest'] as int? ?? 0,
          graceDaysAvailable: graceStatus['grace_days_available'] as int? ?? 0,
          gracePiecesTotal: graceStatus['grace_pieces_total'] as double? ?? 0.0,
          piecesToday: graceStatus['pieces_today'] as double? ?? 0.0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh streak data
  Future<void> refresh() async {
    if (_userId == null) return;
    await initialize(_userId!);
  }

  /// Recalculate streak (after task completion or entry save)
  Future<void> recalculate() async {
    if (_userId == null) return;
    
    try {
      await UserDataService.recalculateStreak(
        _userId!,
        dataFetchService: _dataFetchService,
      );
      // Refresh state
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Streak provider
final streakProvider = NotifierProvider<StreakNotifier, StreakState>(() {
  return StreakNotifier();
});
