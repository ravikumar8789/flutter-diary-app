import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color palette - InnerGlow style (warm beige/cream with dark brown text)
  // Extracted from innerglow-journal.lovable.app
  static const Color primaryColor = Color(
    0xFFE98463,
  ); // Coral/salmon (rgb(233, 132, 99)) - buttons, links, accents
  static const Color secondaryColor = Color(
    0xFFA4C3A2,
  ); // Light sage (keep for subtle accents)
  static const Color accentColor = Color(0xFFE8DFD0); // Warm beige
  static const Color backgroundColor = Color(
    0xFFFAF8F4,
  ); // Warm beige/cream (rgb(250, 248, 244))
  static const Color surfaceColor = Color(
    0xFFFDFCFC,
  ); // Slightly lighter white for cards (rgb(253, 252, 252))
  static const Color textPrimaryColor = Color(
    0xFF32241B,
  ); // Dark brown (rgb(50, 36, 27))
  static const Color textSecondaryColor = Color(
    0xFF6B7669,
  ); // Medium gray-green
  static const Color errorColor = Color(0xFFB85C5C); // Muted red

  // Dark theme colors (adjusted to match InnerGlow warm aesthetic)
  static const Color darkPrimaryColor = Color(
    0xFFE98463,
  ); // Same coral/salmon for consistency
  static const Color darkSecondaryColor = Color(0xFFA4C3A2); // Light sage
  static const Color darkAccentColor = Color(0xFF2A2A2A); // Dark gray
  static const Color darkBackgroundColor = Color(
    0xFF1A1816,
  ); // Warm dark brown background
  static const Color darkSurfaceColor = Color(
    0xFF252320,
  ); // Slightly lighter dark surface
  static const Color darkTextPrimaryColor = Color(
    0xFFE8E4E0,
  ); // Warm light text
  static const Color darkTextSecondaryColor = Color(
    0xFFB8B4B0,
  ); // Medium warm light text

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();
    final lightTextTheme = baseTextTheme
        .apply(
          bodyColor: textPrimaryColor,
          displayColor: textPrimaryColor,
        )
        .copyWith(
          displayLarge: GoogleFonts.nunito(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
          headlineLarge: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
          headlineMedium: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: textPrimaryColor,
          ),
          titleLarge: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: textPrimaryColor,
          ),
          bodyLarge: GoogleFonts.nunito(
            fontSize: 16,
            color: textPrimaryColor,
          ),
          bodyMedium: GoogleFonts.nunito(
            fontSize: 14,
            color: textSecondaryColor,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: textSecondaryColor,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            color: textSecondaryColor,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            color: textSecondaryColor,
          ),
          labelSmall: baseTextTheme.labelSmall?.copyWith(
            color: textSecondaryColor,
          ),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor, // Coral/salmon for buttons, links, icons
        secondary: secondaryColor, // Light sage for subtle accents
        surface: surfaceColor, // Card background (slightly lighter white)
        error: errorColor,
        onPrimary: Colors.white, // White text on primary
        onSecondary: textPrimaryColor, // Dark brown text on secondary
        onSurface: textPrimaryColor, // Dark brown text on surface/cards
        onError: Colors.white,
        surfaceVariant: backgroundColor.withOpacity(
          0.5,
        ), // Subtle variant for dividers
        onSurfaceVariant: textPrimaryColor.withOpacity(0.7), // Muted text
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: lightTextTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textPrimaryColor,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, // Coral/salmon
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor, // Coral/salmon for text buttons/links
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();
    final darkTextTheme = baseTextTheme
        .apply(
          bodyColor: darkTextPrimaryColor,
          displayColor: darkTextPrimaryColor,
        )
        .copyWith(
          displayLarge: GoogleFonts.nunito(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: darkTextPrimaryColor,
          ),
          headlineLarge: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: darkTextPrimaryColor,
          ),
          headlineMedium: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: darkTextPrimaryColor,
          ),
          titleLarge: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: darkTextPrimaryColor,
          ),
          bodyLarge: GoogleFonts.nunito(
            fontSize: 16,
            color: darkTextPrimaryColor,
          ),
          bodyMedium: GoogleFonts.nunito(
            fontSize: 14,
            color: darkTextSecondaryColor,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: darkTextSecondaryColor,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            color: darkTextSecondaryColor,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            color: darkTextSecondaryColor,
          ),
          labelSmall: baseTextTheme.labelSmall?.copyWith(
            color: darkTextSecondaryColor,
          ),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: darkPrimaryColor, // Coral/salmon
        secondary: darkSecondaryColor, // Light sage
        surface: darkSurfaceColor, // Dark surface
        error: errorColor,
        onPrimary: Colors.white, // White text on primary
        onSecondary: darkTextPrimaryColor, // Light text on secondary
        onSurface: darkTextPrimaryColor, // Light text on surface
        onError: Colors.white,
        surfaceVariant: darkBackgroundColor.withOpacity(
          0.5,
        ), // Subtle variant for dividers
        onSurfaceVariant: darkTextPrimaryColor.withOpacity(0.7), // Muted text
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      textTheme: darkTextTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: darkBackgroundColor,
        foregroundColor: darkTextPrimaryColor,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimaryColor,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: darkSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryColor, // Coral/salmon
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              darkPrimaryColor, // Coral/salmon for text buttons/links
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkSecondaryColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkSecondaryColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
