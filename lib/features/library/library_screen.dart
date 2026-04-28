import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'book_card.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'AeroPDF',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black.withOpacity(0.1),
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search all books',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final book = await ref.read(libraryProvider.notifier).pickAndAddPdf();
          if (book != null && context.mounted) {
            context.push('/reader/${book.id}');
          }
        },
        backgroundColor: const Color(0xFF0075DE),
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add PDF',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ),
      body: state.isLoading && state.books.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.books.isEmpty
              ? _EmptyState(
                  onAdd: () async {
                    final book = await ref
                        .read(libraryProvider.notifier)
                        .pickAndAddPdf();
                    if (book != null && context.mounted) {
                      context.push('/reader/${book.id}');
                    }
                  },
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(libraryProvider.notifier).loadBooks(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: state.books.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final book = state.books[i];
                      return BookListTile(
                        key: ValueKey(book.id),
                        book: book,
                        onTap: () => context.push('/reader/${book.id}'),
                        onDelete: () => ref
                            .read(libraryProvider.notifier)
                            .deleteBook(book.id),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first PDF.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0075DE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              'Add PDF',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
