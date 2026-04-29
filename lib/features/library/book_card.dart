import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart'; 
import '../../core/models/book.dart';

class BookListTile extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BookListTile({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; // Dynamic colors!
    final progress = book.totalPages > 0 ? book.lastReadPage / book.totalPages : 0.0;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            SizedBox(
              width: 50,
              height: 70, 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: PdfThumbnail(
                  book: book,
                  key: ValueKey('list_${book.id}'),
                  ), // Using the public widget
              ),
            ),
            const SizedBox(width: 14),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(Icons.description_outlined, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${book.totalPages}p', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Icon(Icons.folder_outlined, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      _FileSizeWidget(filePath: book.filePath),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHigh,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Remove from Library', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
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
    return FutureBuilder<int>(
      future: File(filePath).length(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('', style: TextStyle(fontSize: 12));
        final mb = snapshot.data! / (1024 * 1024);
        return Text(
          '${mb.toStringAsFixed(1)} MB',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        );
      },
    );
  }
}

// ── Public PDF Thumbnail Widget ──────────────────────────────────────────────

// CHANGED: Using int instead of String to use book.id, ensuring it never fails on a null hash.
final Map<int, MemoryImage> thumbnailCache = {};

class PdfThumbnail extends StatefulWidget {
  final Book book;
  const PdfThumbnail({super.key, required this.book});

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  MemoryImage? _image;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  // Forces the widget to reload if the book changes (e.g., during re-import)
  @override
  void didUpdateWidget(PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final currentBookId = widget.book.id;

    // 1. Check cache
    if (thumbnailCache.containsKey(currentBookId)) {
      if (mounted) setState(() => _image = thumbnailCache[currentBookId]);
      return;
    }

    try {
      final file = File(widget.book.filePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final document = await PdfDocument.openData(bytes);
      final page = await document.getPage(1);
      
      final pageImage = await page.render(
        width: page.width / 2, 
        height: page.height / 2,
        format: PdfPageImageFormat.jpeg,
        quality: 40,
      );

      await page.close();
      await document.close();

      // 2. ONLY update state if the widget hasn't been recycled for a new book
      if (pageImage != null && mounted && widget.book.id == currentBookId) {
        final img = MemoryImage(pageImage.bytes);
        thumbnailCache[currentBookId] = img;
        setState(() => _image = img);
      }
    } catch (e) {
      debugPrint("Thumb error: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_image != null) {
      return Image(
        key: ValueKey('thumb_${widget.book.id}'), // Force unique identity
        image: _image!, 
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // Smooth fade-in when the thumbnail loads
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    }
    
    // ── Fallback Placeholder ──────────────────────────────────────────
    return Container(
      color: cs.surfaceContainerHigh,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Icon(
          Icons.picture_as_pdf_rounded, 
          color: cs.onSurfaceVariant.withOpacity(0.3), 
          size: 32
        ),
      ),
    );
  }
}