import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/book.dart';
import 'library_provider.dart';
import 'book_card.dart'; 

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';
  bool _sortByRecent = true;
  final FocusNode _searchFocusNode = FocusNode();
  
  // ── Removal Logic ──────────────────────────────────────────────────────────

  void _showOptionsSheet(Book book) {
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
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant, 
                borderRadius: BorderRadius.circular(2)
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: cs.onSurface),
              title: const Text('Rename PDF', 
                style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(book);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: cs.onSurface),
              title: const Text('Share PDF', 
                style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(book.filePath)], text: book.title);
              },
            ),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: cs.onSurface),
              title: const Text('Reset Progress', 
                style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                ref.read(libraryProvider.notifier).resetProgress(book.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.red),
              title: Text('Remove "${book.title}"', 
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.red),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('Removes from workspace. File stays on device.', style: TextStyle(color: Colors.redAccent)),
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

  void _showRenameDialog(Book book) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: book.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Rename "${book.title}"', style: TextStyle(color: cs.onSurface)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(libraryProvider.notifier).renameBook(book.id, newTitle);
              }
              Navigator.pop(context);
            },
            child: Text('Rename', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
          ),
        ],
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

    ref.listen<LibraryState>(libraryProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    if (View.of(context).viewInsets.bottom == 0.0 && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

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
                      height: 240,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: displayRecents.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, i) => _buildJumpBackInCard(displayRecents[i], cs),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    focusNode: _searchFocusNode,
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Search PDFs...',
                                      hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<bool>(
                          initialValue: _sortByRecent,
                          icon: Icon(Icons.sort_rounded, color: cs.onSurface),
                          onSelected: (val) => setState(() => _sortByRecent = val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: true,
                              child: Text('Recently Added'),
                            ),
                            const PopupMenuItem(
                              value: false,
                              child: Text('Previously Added'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('All Documents', style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
                    child: () {
                      final filteredBooks = state.books.where((b) {
                        return b.title.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();
                      
                      if (!_sortByRecent) {
                        filteredBooks.sort((a, b) => a.id.compareTo(b.id));
                      }

                      if (filteredBooks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text("No documents found", style: TextStyle(color: cs.onSurfaceVariant))),
                        );
                      }

                      return Column(
                        children: filteredBooks.map((book) => _buildNotionListTile(book, cs)).toList(),
                      );
                    }(),
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
    final progress = (book.totalPages == 0 || book.lastReadPage < 0)
        ? 0.0
        : (book.totalPages <= 1 ? 1.0 : book.lastReadPage / (book.totalPages - 1));
    
    return GestureDetector(
      onTap: () async {
        await context.push('/reader/${book.id}');
        ref.read(libraryProvider.notifier).loadBooks();
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showOptionsSheet(book);
      },
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatLastOpened(book.lastOpened),
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastOpened(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Opened $hour:$minute';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return 'Opened $day/$month';
    }
  }

  Widget _buildNotionListTile(Book book, ColorScheme cs) {
    return InkWell(
      onTap: () async {
        await context.push('/reader/${book.id}');
        ref.read(libraryProvider.notifier).loadBooks();
      },
      onLongPress: () => _showOptionsSheet(book), // ── WIRE UP LONG PRESS
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                book.title,
                style: TextStyle(fontSize: 15, color: cs.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 20),
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
        final bytes = snapshot.data!;
        final String sizeStr;
        
        if (bytes < 1024 * 1024) {
          final kb = bytes / 1024;
          sizeStr = '${kb.toStringAsFixed(1)} KB';
        } else if (bytes < 1024 * 1024 * 1024) {
          final mb = bytes / (1024 * 1024);
          sizeStr = '${mb.toStringAsFixed(1)} MB';
        } else {
          final gb = bytes / (1024 * 1024 * 1024);
          sizeStr = '${gb.toStringAsFixed(1)} GB';
        }

        return Text(
          sizeStr,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
        );
      },
    );
  }
}