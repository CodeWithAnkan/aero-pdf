import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  /// If non-null, scopes the search to a single book.
  final int? bookId;

  const SearchScreen({super.key, this.bookId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  SearchNotifier get _notifier =>
      ref.read(searchProvider(widget.bookId).notifier);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider(widget.bookId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black.withOpacity(0.1),
            height: 1.0,
          ),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search in PDF…',
            border: InputBorder.none,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFA39E98), // Warm Gray 300
            ),
          ),
          onChanged: (v) => _notifier.search(v),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _controller.clear();
                _notifier.clear();
              },
            ),
        ],
      ),
      body: searchState.results.when(
        data: (results) {
          if (searchState.query.isEmpty) {
            return const _EmptyHint();
          }
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No results for "${searchState.query}"',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) =>
                _ResultTile(result: results[i], query: searchState.query),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'Full-text search across all indexed pages',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  final String query;

  const _ResultTile({required this.result, required this.query});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'p.${result.pageNumber + 1}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (result.isOcr)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OCR',
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFFDD5B00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      title: _HighlightedText(text: result.snippet, query: query),
      onTap: () {
        // Navigate to reader at the matching page
        context.go('/reader/${result.bookId}');
        // TODO: pass initial page via extra once reader supports deep-link page
      },
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);

    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = idx + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
