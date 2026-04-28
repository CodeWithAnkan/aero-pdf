import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../core/db/isar_service.dart';
import '../../core/models/search_index.dart';
import '../../core/models/book.dart';

class SearchResult {
  final Book book;
  final List<SearchIndex> matches;
  SearchResult({required this.book, required this.matches});
}

class GlobalSearchNotifier extends StateNotifier<AsyncValue<List<SearchResult>>> {
  GlobalSearchNotifier() : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.length < 2) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final isar = await IsarService.instance;
      
      // 1. Find all text matches across all books
      final matches = await isar.searchIndexs
          .filter()
          .pageTextContains(query, caseSensitive: false)
          .findAll();

      if (matches.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // 2. Group matches by Book ID
      Map<int, List<SearchIndex>> grouped = {};
      for (var m in matches) {
        grouped.putIfAbsent(m.bookId, () => []).add(m);
      }

      // 3. Fetch Book details for each group
      List<SearchResult> results = [];
      for (var entry in grouped.entries) {
        final book = await isar.books.get(entry.key);
        if (book != null) {
          results.add(SearchResult(book: book, matches: entry.value));
        }
      }

      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final globalSearchProvider =
    StateNotifierProvider<GlobalSearchNotifier, AsyncValue<List<SearchResult>>>(
  (ref) => GlobalSearchNotifier(),
);
