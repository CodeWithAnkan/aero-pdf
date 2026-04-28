import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:isar/isar.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/search_index.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result type
// ─────────────────────────────────────────────────────────────────────────────

class SearchResult {
  final int bookId;
  final int pageNumber;
  final String snippet;
  final bool isOcr;

  const SearchResult({
    required this.bookId,
    required this.pageNumber,
    required this.snippet,
    required this.isOcr,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final AsyncValue<List<SearchResult>> results;

  const SearchState({
    this.query = '',
    this.results = const AsyncValue.data([]),
  });

  SearchState copyWith({
    String? query,
    AsyncValue<List<SearchResult>>? results,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier — family keyed by bookId (null = search all books)
// ─────────────────────────────────────────────────────────────────────────────

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._bookId) : super(const SearchState());

  final int? _bookId;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(query: query, results: const AsyncValue.data([]));
      return;
    }

    state = state.copyWith(
      query: query,
      results: const AsyncValue.loading(),
    );

    try {
      final isar = await IsarService.instance;

      // Isar FTS query (Isar v3 removed words so we use contains)
      var q = isar.searchIndexs.filter().pageTextContains(query, caseSensitive: false);

      // Scope to a single book if bookId is provided
      final List<SearchIndex> raw;
      if (_bookId != null) {
        raw = await q.bookIdEqualTo(_bookId).findAll();
      } else {
        raw = await q.findAll();
      }

      final results = raw.map((s) {
        // Extract a short snippet around the first occurrence of the query
        final lower = s.pageText.toLowerCase();
        final idx = lower.indexOf(query.toLowerCase());
        final start = (idx - 60).clamp(0, s.pageText.length);
        final end = (idx + 120).clamp(0, s.pageText.length);
        final snippet = (start > 0 ? '…' : '') +
            s.pageText.substring(start, end).trim() +
            (end < s.pageText.length ? '…' : '');
        return SearchResult(
          bookId: s.bookId,
          pageNumber: s.pageNumber,
          snippet: snippet,
          isOcr: s.isOcr,
        );
      }).toList();

      state = state.copyWith(results: AsyncValue.data(results));
    } catch (e, st) {
      state = state.copyWith(results: AsyncValue.error(e, st));
    }
  }

  void clear() => state = const SearchState();
}

final searchProvider = StateNotifierProvider.family<SearchNotifier, SearchState, int?>(
  (ref, bookId) => SearchNotifier(bookId),
);
