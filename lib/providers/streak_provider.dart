import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/database_manager.dart';
import '../services/user_data_service.dart';
import '../services/grace_system_service.dart';

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

/// Streak provider — local-only (reads from streaks table)
class StreakNotifier extends Notifier<StreakState> {
  String? _userId;

  @override
  StreakState build() {
    return StreakState();
  }

  /// Initialize streak data from local DB
  Future<void> initialize(String userId) async {
    if (_userId == userId && !state.isLoading) return;
    _userId = userId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final db = await DatabaseManager().database;
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      final graceStatus = await GraceSystemService.getGraceStatus(userId);

      if (streaks.isNotEmpty && graceStatus != null) {
        final s = streaks.first;
        state = state.copyWith(
          current: s['current'] as int? ?? 0,
          longest: s['longest'] as int? ?? 0,
          graceDaysAvailable: graceStatus['grace_days_available'] as int? ?? 0,
          gracePiecesTotal: graceStatus['grace_pieces_total'] as double? ?? 0.0,
          piecesToday: graceStatus['pieces_today'] as double? ?? 0.0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      await UserDataService.recalculateStreak(_userId!);
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
