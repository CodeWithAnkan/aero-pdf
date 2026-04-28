import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/db/isar_service.dart';

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
    const seed = Color(0xFF6366F1); // Indigo
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
    );
  }

  // ── Dark theme ──────────────────────────────────────────────────────────────

  ThemeData _darkTheme() {
    const seed = Color(0xFF818CF8); // Lighter indigo for dark surfaces
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFF0F0F10),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Color(0xFF0F0F10),
        centerTitle: false,
      ),
    );
  }
}
