import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/library/folder_screen.dart';
import '../features/navigation/main_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/library/import_intent_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  // 1. Intercept Android file intents before GoRouter crashes
  redirect: (context, state) {
    final uriString = state.uri.toString();
    
    // Catch external intents from WhatsApp/Files app
    if (uriString.startsWith('content://') || uriString.startsWith('file://')) {
      // Pass the raw URI to the import screen safely
      return '/import?uri=${Uri.encodeComponent(uriString)}';
    }
    return null; // Return null to proceed normally for standard routes
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/folder',
      builder: (context, state) => const FolderScreen(),
    ),
    GoRoute(
      path: '/reader/:bookId',
      // Custom instant transition — no slide animation competing with I/O.
      // The reader fades in over 180ms, which feels intentional rather than
      // abrupt, and gives the PDF viewer time to paint its first frame.
      pageBuilder: (context, state) {
        final bookId = int.parse(state.pathParameters['bookId']!);
        final pageStr = state.uri.queryParameters['page'];
        final initialPage = pageStr != null ? int.parse(pageStr) : 0;

        return CustomTransitionPage(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          child: ReaderScreen(bookId: bookId, initialPage: initialPage),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
              ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    // If you want a specific "Search within this book" screen:
    GoRoute(
      path: '/search/:bookId',
      builder: (context, state) {
        final bookId = int.parse(state.pathParameters['bookId']!);
        return SearchScreen(bookId: bookId);
      },
    ),
    // 2. Add the handler route for external intents
    GoRoute(
      path: '/import',
      builder: (context, state) {
        final uri = state.uri.queryParameters['uri']!;
        return ImportIntentScreen(intentUri: uri);
      },
    ),
  ],
);
