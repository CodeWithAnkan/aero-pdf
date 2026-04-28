import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/db/isar_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress non-critical widget disposal errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget suppressed: ${details.exception}');
    return const SizedBox.shrink();
  };
  
  // Force orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Warm up the database
  await IsarService.instance;

  // ProviderScope is required for Riverpod to work globally
  runApp(
    const ProviderScope(
      child: AeroPdfApp(),
    ),
  );
}

// ConsumerWidget allows the app to listen to state changes (like Dark Mode)
class AeroPdfApp extends ConsumerWidget {
  const AeroPdfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Listen to the current theme mode
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'AeroPDF',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      
      // 2. Dynamically apply light or dark mode based on the provider
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme, 
    );
  }
}