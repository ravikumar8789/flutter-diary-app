import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_preference_sync_service.dart';
import '../services/error_logging_service.dart';

/// Paper style enum
enum PaperStyle {
  plain('plain'),
  ruled('ruled'),
  grid('grid');

  const PaperStyle(this.value);
  final String value;

  static PaperStyle fromString(String? value) {
    switch (value) {
      case 'plain':
        return PaperStyle.plain;
      case 'grid':
        return PaperStyle.grid;
      default:
        return PaperStyle.ruled;
    }
  }
}

/// Paper style provider
final paperStyleProvider = NotifierProvider<PaperStyleNotifier, PaperStyle>(() {
  return PaperStyleNotifier();
});

/// Paper style notifier for managing paper style state
class PaperStyleNotifier extends Notifier<PaperStyle> {
  static const String _paperStyleKey = 'paper_style';

  @override
  PaperStyle build() {
    _loadPaperStyle();
    return PaperStyle.ruled; // Default to ruled
  }

  /// Load paper style from SharedPreferences
  Future<void> _loadPaperStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paperStyleString = prefs.getString(_paperStyleKey);

      if (paperStyleString != null) {
        state = PaperStyle.fromString(paperStyleString);
      }
    } catch (e) {
      // Use default if loading fails
      state = PaperStyle.ruled;
    }
  }

  /// Set paper style and save to SharedPreferences
  Future<void> setPaperStyle(PaperStyle style) async {
    try {
      state = style;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_paperStyleKey, style.value);
    } catch (e) {
      // Handle error silently or log it

    }

    // Best-effort cloud sync
    try {
      await UserPreferenceSyncService.syncAppearanceToCloud(
        paperStyle: state.value,
      );
    } catch (e) {
      await ErrorLoggingService.logError(
        errorCode: 'ERRSYS134',
        errorMessage:
            'Settings save failed (cloud paper style sync): ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {
          'operation': 'sync_paper_style',
          'paper_style': state.value,
        },
      );
    }
  }

  /// Get current paper style display name
  String get currentPaperStyleDisplayName {
    switch (state) {
      case PaperStyle.plain:
        return 'Plain';
      case PaperStyle.ruled:
        return 'Ruled';
      case PaperStyle.grid:
        return 'Grid';
    }
  }
}
