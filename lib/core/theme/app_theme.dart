import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData getTheme({required bool isDark, required String fontFamily}) {
    final baseTheme = isDark ? darkTheme : lightTheme;
    return baseTheme.copyWith(
      textTheme: GoogleFonts.getTextTheme(fontFamily, baseTheme.textTheme),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7F8), // bgLight
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF37352F)),
        titleTextStyle: TextStyle(
          color: Color(0xFF37352F),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1882EC), // Accent Blue
        surface: Colors.white,      // Main cards/panels
        surfaceContainer: Color(0xFFF7F7F5), // Hover/Secondary surfaces
        onSurface: Color(0xFF37352F), // Main Text
        onSurfaceVariant: Color(0xFF9A9A9A), // Muted Text
        outlineVariant: Color(0xFFEAEAEC), // Borders
      ),
      dividerColor: const Color(0xFFEAEAEC),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212), // Dark Canvas
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFEBEBEB)),
        titleTextStyle: TextStyle(
          color: Color(0xFFEBEBEB),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3A94EE), // Slightly brighter blue for dark mode
        surface: Color(0xFF1E1E1E), // Main cards/panels
        surfaceContainer: Color(0xFF252525), // Hover/Secondary surfaces
        onSurface: Color(0xFFEBEBEB), // Main Text
        onSurfaceVariant: Color(0xFF9A9A9A), // Muted Text
        outlineVariant: Color(0xFF2F2F2F), // Borders
      ),
      dividerColor: const Color(0xFF2F2F2F),
    );
  }
}