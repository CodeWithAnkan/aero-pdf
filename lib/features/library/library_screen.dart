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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'AeroPDF',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
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
          final book =
              await ref.read(libraryProvider.notifier).pickAndAddPdf();
          if (book != null && context.mounted) {
            context.push('/reader/${book.id}');
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add PDF'),
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
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: state.books.length,
                    itemBuilder: (context, i) {
                      final book = state.books[i];
                      return BookCard(
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
            Icons.picture_as_pdf_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first PDF',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add PDF'),
          ),
        ],
      ),
    );
  }
}
