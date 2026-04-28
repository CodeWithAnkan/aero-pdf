import 'dart:io';
import 'dart:isolate';

import 'package:isar/isar.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/book.dart';
import '../models/ocr_cache.dart';
import '../models/search_index.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Message types for isolate progress reporting
// ─────────────────────────────────────────────────────────────────────────────

class IndexingProgress {
  final int bookId;
  final int currentPage;
  final int totalPages;
  final bool isOcrActive;

  const IndexingProgress({
    required this.bookId,
    required this.currentPage,
    required this.totalPages,
    required this.isOcrActive,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Indexing isolate entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Indexes all pages of a PDF into Isar's FTS engine.
/// Runs entirely in a background isolate — never blocks the UI thread.
///
/// Steps per page:
/// 1. Try native text extraction via Syncfusion PDF.
/// 2. If page looks scanned (<30 chars), mark for lazy OCR.
/// 3. Store text in [SearchIndex] (FTS-indexed).
/// 4. Mark [Book.isIndexed] = true when done.
///
/// [sendPort] receives [IndexingProgress] updates (nullable — omit for fire-and-forget).
Future<void> indexBookInBackground(
  int bookId,
  String filePath,
  String isarDirectory, {
  SendPort? sendPort,
}) async {
  await Isolate.run(() async {
    final isar = await Isar.open(
      [BookSchema, SearchIndexSchema, OcrCacheSchema],
      directory: isarDirectory,
      name: 'aeropdf',
    );

    try {
      final bytes = await File(filePath).readAsBytes();
      final pdfDoc = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(pdfDoc);
      final totalPages = pdfDoc.pages.count;
      int scannedPageCount = 0;

      for (int i = 0; i < totalPages; i++) {
        String pageText;

        // Try native text extraction first
        try {
          pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        } catch (_) {
          pageText = '';
        }

        // If page has very little text, it's likely scanned
        bool isScanned = false;
        if (pageText.trim().length < 30) {
          isScanned = true;
          scannedPageCount++;
          // Note: OCR can't run in a background isolate (requires platform channels).
          // OCR will run lazily on the main isolate when the user views the page.
        }

        // Feed into FTS regardless of source
        if (pageText.trim().isNotEmpty) {
          await isar.writeTxn(() => isar.searchIndexs.put(
                SearchIndex()
                  ..bookId = bookId
                  ..pageNumber = i
                  ..pageText = pageText
                  ..isOcr = isScanned,
              ));
        }

        // Report progress back to the main isolate
        sendPort?.send(IndexingProgress(
          bookId: bookId,
          currentPage: i + 1,
          totalPages: totalPages,
          isOcrActive: false,
        ));
      }

      pdfDoc.dispose();

      // Mark book as indexed
      final book = await isar.books.get(bookId);
      if (book != null) {
        await isar.writeTxn(() async {
          book.isIndexed = true;
          book.scannedPageCount = scannedPageCount;
          await isar.books.put(book);
        });
      }
    } catch (_) {
      // Indexing failed silently — book remains unindexed
    }
  });
}
