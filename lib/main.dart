import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/db/isar_service.dart';

import 'package:google_fonts/google_fonts.dart';

// ... (other imports stay the same, but since this replaces the whole section, I must include them)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress brief red error screens from non-critical widget disposal
  // errors (e.g., pdfrx text selection cleanup during navigation).
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget suppressed: ${details.exception}');
    return const SizedBox.shrink();
  };
  // Force portrait + landscape, let user decide
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Warm up Isar on the main thread before the widget tree mounts.
  // Subsequent calls to IsarService.instance are instant (singleton).
  await IsarService.instance;

  runApp(
    const ProviderScope(
      child: AeroPdfApp(),
    ),
  );
}

class AeroPdfApp extends StatelessWidget {
  const AeroPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AeroPDF',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: ThemeMode.system,
    );
  }

  // ── Light theme ─────────────────────────────────────────────────────────────

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0075DE), // Notion Blue
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      textTheme: _buildNotionTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFFFFFFF),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────────────────

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0075DE),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF31302E), // Warm Dark
      textTheme: _buildNotionTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFF31302E),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  TextTheme _buildNotionTextTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final baseTextColor = isLight ? const Color(0xF2000000) : const Color(0xFFF6F5F4);
    final mutedTextColor = isLight ? const Color(0xFF615D59) : const Color(0xFFA39E98);

    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 64,
        fontWeight: FontWeight.w700,
        letterSpacing: -2.125,
        height: 1.0,
        color: baseTextColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 54,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.875,
        height: 1.04,
        color: baseTextColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.0,
        color: baseTextColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.5,
        color: baseTextColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22, // Card Title
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.27,
        color: baseTextColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.5,
        color: baseTextColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.125,
        height: 1.4,
        color: baseTextColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: baseTextColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.33,
        color: baseTextColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.43,
        color: mutedTextColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.125,
        height: 1.33,
        color: baseTextColor,
      ),
    );
  }
}
