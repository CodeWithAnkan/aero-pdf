import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart'; // Make sure you added pdfx to pubspec.yaml
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
    final colorScheme = Theme.of(context).colorScheme;
    final progress = book.totalPages > 0 ? book.lastReadPage / book.totalPages : 0.0;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showOptions(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // REMOVED: height: 110 (This caused the overflow)
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.all(12), // Slightly increased padding for breathing room
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align to top to prevent flex issues
          children: [
            // Thumbnail
            SizedBox(
              width: 72,
              height: 96, // FIXED: Give the thumbnail explicit dimensions instead of the container
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _PdfThumbnail(book: book),
              ),
            ),
            const SizedBox(width: 14),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // REMOVED: MainAxisAlignment.center so the column sizes to its children naturally
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Metadata Row: Pages & File Size
                  Row(
                    children: [
                      Icon(Icons.description_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${book.totalPages} pages',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.folder_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      _FileSizeWidget(filePath: book.filePath),
                    ],
                  ),
                  const SizedBox(height: 12), // Added a bit more spacing here
                  
                  // Last Opened & Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opened: ${_formatDate(book.lastOpened)}',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colorScheme.surfaceContainerHigh,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
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

// ─────────────────────────────────────────────────────────────────────────────
// File Size Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FileSizeWidget extends StatelessWidget {
  final String filePath;
  const _FileSizeWidget({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: File(filePath).length(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('-- MB', style: TextStyle(fontSize: 12));
        
        final bytes = snapshot.data!;
        final mb = bytes / (1024 * 1024);
        return Text(
          '${mb.toStringAsFixed(1)} MB',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real PDF Thumbnail using pdfx
// ─────────────────────────────────────────────────────────────────────────────

// Global cache so thumbnails don't re-render wildly when scrolling the list
final Map<String, MemoryImage> _thumbnailCache = {};

class _PdfThumbnail extends StatefulWidget {
  final Book book;
  const _PdfThumbnail({required this.book});

  @override
  State<_PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<_PdfThumbnail> {
  MemoryImage? _image;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // 1. Check cache first
    if (_thumbnailCache.containsKey(widget.book.fileHash)) {
      if (mounted) setState(() => _image = _thumbnailCache[widget.book.fileHash]);
      return;
    }

    try {
      // 2. Open PDF and get page 1
      final document = await PdfDocument.openFile(widget.book.filePath);
      final page = await document.getPage(1);
      
      // 3. Render page at low resolution to save memory (scaled down by 3)
      final pageImage = await page.render(
        width: page.width / 3, 
        height: page.height / 3,
        format: PdfPageImageFormat.jpeg,
      );

      await page.close();
      await document.close();

      // 4. Save to cache and update UI
      if (pageImage != null) {
        final img = MemoryImage(pageImage.bytes);
        _thumbnailCache[widget.book.fileHash] = img;
        if (mounted) setState(() => _image = img);
      }
    } catch (e) {
      debugPrint("[AeroPDF] Thumbnail error for ${widget.book.title}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image != null) {
      return Image(
        image: _image!, 
        fit: BoxFit.cover,
      );
    }
    
    // Fallback gradient while loading or if it fails
    final idx = widget.book.title.isEmpty ? 0 : widget.book.title.codeUnitAt(0) % 5;
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
    ][idx];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          widget.book.title.isEmpty ? '?' : widget.book.title[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}