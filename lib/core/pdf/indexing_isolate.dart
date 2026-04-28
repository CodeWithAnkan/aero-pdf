import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/book.dart';
import '../models/ocr_cache.dart';
import '../models/search_index.dart';

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

Future<void> indexBookInBackground(
  int bookId,
  String filePath,
  String isarDirectory, {
  SendPort? sendPort,
}) async {
  // Isolate.run creates a separate memory heap for this task
  await Isolate.run(() async {
    // Open a dedicated Isar instance for this isolate
    final isar = await Isar.open(
      [BookSchema, SearchIndexSchema, OcrCacheSchema],
      directory: isarDirectory,
      name: 'aeropdf',
    );

    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final pdfDoc = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(pdfDoc);
      final totalPages = pdfDoc.pages.count;
      
      int scannedPageCount = 0;
      List<SearchIndex> indexResults = [];

      for (int i = 0; i < totalPages; i++) {
        String pageText = '';
        try {
          // Extract text for the specific page
          pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        } catch (e) {
          debugPrint("Extraction failed on page $i: $e");
        }

        // Logic check: if text is sparse, mark for future OCR
        bool isScanned = pageText.trim().length < 30;
        if (isScanned) scannedPageCount++;

        if (pageText.trim().isNotEmpty) {
          indexResults.add(
            SearchIndex()
              ..bookId = bookId
              ..pageNumber = i
              ..pageText = pageText // Corrected naming
              ..isOcr = isScanned,
          );
        }

        // Send progress updates back to UI if a port is provided
        sendPort?.send(IndexingProgress(
          bookId: bookId,
          currentPage: i + 1,
          totalPages: totalPages,
          isOcrActive: false,
        ));
      }

      // Perform a single batch write for efficiency
      await isar.writeTxn(() async {
        await isar.searchIndexs.putAll(indexResults);
        
        final book = await isar.books.get(bookId);
        if (book != null) {
          book.isIndexed = true;
          book.scannedPageCount = scannedPageCount;
          await isar.books.put(book);
        }
      });

      pdfDoc.dispose();
      await isar.close(); // Important: Release database lock
      
    } catch (e) {
      debugPrint("INDEXING CRITICAL FAILURE: $e");
    }
  });
}
