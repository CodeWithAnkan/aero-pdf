import 'package:go_router/go_router.dart';

import '../features/library/library_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/reader/:bookId',
      builder: (context, state) {
        final bookId = int.parse(state.pathParameters['bookId']!);
        return ReaderScreen(bookId: bookId);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/search/:bookId',
      builder: (context, state) {
        final bookId = int.parse(state.pathParameters['bookId']!);
        return SearchScreen(bookId: bookId);
      },
    ),
  ],
);
