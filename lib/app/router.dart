import 'package:go_router/go_router.dart';
import '../features/library/folder_screen.dart';
import '../features/navigation/main_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';

final router = GoRouter(
  initialLocation: '/',
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
      builder: (context, state) {
        // 1. Extract the Book ID from the path
        final bookId = int.parse(state.pathParameters['bookId']!);

        // 2. Extract the Page Number from the query string (?page=10)
        final pageStr = state.uri.queryParameters['page'];
        final initialPage = pageStr != null ? int.parse(pageStr) : 0;

        return ReaderScreen(
          bookId: bookId,
          initialPage: initialPage, // Make sure your ReaderScreen accepts this!
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
        return SearchScreen(bookId: bookId); // Update SearchScreen constructor!
      },
    ),
  ],
);
