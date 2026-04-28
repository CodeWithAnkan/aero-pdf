import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import 'library_provider.dart';
import 'book_card.dart'; 

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  
  // ── Removal Logic ──────────────────────────────────────────────────────────

  void _showRemoveSheet(Book book) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notion-style drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant, 
                borderRadius: BorderRadius.circular(2)
              ),
            ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: cs.onSurface),
              title: Text('Remove "${book.title}"', 
                style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Removes from workspace. File stays on device.'),
              onTap: () {
                ref.read(libraryProvider.notifier).deleteBook(book.id);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final cs = Theme.of(context).colorScheme;
    final bgLight = Theme.of(context).scaffoldBackgroundColor;

    final recentBooks = state.books.where((b) => b.lastOpened != null).toList()
      ..sort((a, b) => b.lastOpened!.compareTo(a.lastOpened!));
    final displayRecents = recentBooks.take(5).toList();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Workspace',
          style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: cs.onSurface),
            onPressed: () {}, 
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cs.outlineVariant, height: 1),
        ),
      ),
      body: state.isLoading && state.books.isEmpty
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : RefreshIndicator(
              onRefresh: () => ref.read(libraryProvider.notifier).loadBooks(),
              color: cs.primary,
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 100),
                children: [
                  if (displayRecents.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Jump Back In', style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: displayRecents.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) => _buildJumpBackInCard(displayRecents[i], cs),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('All Documents', style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
                    child: state.books.isEmpty 
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text("Empty workspace", style: TextStyle(color: cs.onSurfaceVariant))),
                        )
                      : Column(
                          children: state.books.map((book) => _buildNotionListTile(book, cs)).toList(),
                        ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(libraryProvider.notifier).pickAndAddPdf(),
        backgroundColor: cs.onSurface, 
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(Icons.add_rounded, color: bgLight, size: 28),
      ),
    );
  }

  Widget _buildJumpBackInCard(Book book, ColorScheme cs) {
    final progress = book.totalPages > 0 ? book.lastReadPage / book.totalPages : 0.0;
    
    return GestureDetector(
      onTap: () => context.push('/reader/${book.id}'),
      onLongPress: () => _showRemoveSheet(book), // ── WIRE UP LONG PRESS
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: PdfThumbnail(
                  book: book,
                  key: ValueKey('jump_${book.id}'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                book.title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotionListTile(Book book, ColorScheme cs) {
    return InkWell(
      onTap: () => context.push('/reader/${book.id}'),
      onLongPress: () => _showRemoveSheet(book), // ── WIRE UP LONG PRESS
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                book.title,
                style: TextStyle(fontSize: 15, color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _FileSizeWidget(filePath: book.filePath),
          ],
        ),
      ),
    );
  }
}

class _FileSizeWidget extends StatelessWidget {
  final String filePath;
  const _FileSizeWidget({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<int>(
      future: File(filePath).length(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('', style: TextStyle(fontSize: 12));
        final mb = snapshot.data! / (1024 * 1024);
        return Text(
          '${mb.toStringAsFixed(1)} MB',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
        );
      },
    );
  }
}