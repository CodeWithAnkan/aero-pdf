import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'search_provider.dart';
import '../library/book_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final int? bookId;
  const SearchScreen({super.key, this.bookId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(globalSearchProvider);
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: cs.onSurface, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Search across all documents...',
            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 18),
            border: InputBorder.none,
          ),
          onChanged: (val) => ref.read(globalSearchProvider.notifier).search(val),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cs.outlineVariant, height: 1),
        ),
      ),
      body: searchState.when(
        data: (results) => results.isEmpty
            ? _buildEmptyState(cs)
            : ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, i) => _buildBookGroup(results[i], cs),
              ),
        loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
        error: (e, _) => Center(child: Text('Search Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(
            _controller.text.isEmpty ? "Find anything" : "No matches found",
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGroup(SearchResult result, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              SizedBox(
                width: 24, height: 32,
                child: PdfThumbnail(book: result.book),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.book.title,
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Match list
        ...result.matches.map((m) => _buildMatchTile(result.book.id, m, cs)),
        Divider(color: cs.outlineVariant, indent: 16),
      ],
    );
  }

  Widget _buildMatchTile(int bookId, dynamic match, ColorScheme cs) {
    return InkWell(
      onTap: () => context.push('/reader/$bookId?page=${match.pageNumber}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('p. ${match.pageNumber + 1}', 
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                match.content.trim(),
                style: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
