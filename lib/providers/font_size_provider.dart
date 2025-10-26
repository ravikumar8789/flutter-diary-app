import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Font size enum
enum FontSize {
  small('small', 14.0),
  medium('medium', 16.0),
  large('large', 18.0);

  const FontSize(this.value, this.size);
  final String value;
  final double size;

  static FontSize fromString(String? value) {
    switch (value) {
      case 'small':
        return FontSize.small;
      case 'large':
        return FontSize.large;
      default:
        return FontSize.medium;
    }
  }
}

/// Font size provider
final fontSizeProvider = NotifierProvider<FontSizeNotifier, FontSize>(() {
  return FontSizeNotifier();
});

/// Font size notifier for managing font size state
class FontSizeNotifier extends Notifier<FontSize> {
  static const String _fontSizeKey = 'font_size';

  @override
  FontSize build() {
    _loadFontSize();
    return FontSize.medium; // Default to medium
  }

  /// Load font size from SharedPreferences
  Future<void> _loadFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontSizeString = prefs.getString(_fontSizeKey);

      if (fontSizeString != null) {
        state = FontSize.fromString(fontSizeString);
      }
    } catch (e) {
      // Use default if loading fails
      state = FontSize.medium;
    }
  }

  /// Set font size and save to SharedPreferences
  Future<void> setFontSize(FontSize size) async {
    try {
      state = size;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontSizeKey, size.value);
    } catch (e) {
      // Handle error silently or log it
      print('Error saving font size: $e');
    }
  }

  /// Get current font size display name
  String get currentFontSizeDisplayName {
    switch (state) {
      case FontSize.small:
        return 'Small';
      case FontSize.medium:
        return 'Medium';
      case FontSize.large:
        return 'Large';
    }
  }

  /// Get current font size value
  double get currentFontSize => state.size;
}
