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
  await Isolate.run(() async {
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
          // Use TextLines and wordCollection to force space reconstruction
          // This fixes the "squished words" issue for absolute-positioned PDFs
          final lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
          final buffer = StringBuffer();
          for (final line in lines) {
            buffer.writeln(line.wordCollection.map((w) => w.text).join(' '));
          }
          pageText = buffer.toString();
        } catch (e) {
          debugPrint("Extraction failed on page $i: $e");
        }

        bool isScanned = pageText.trim().length < 30;
        if (isScanned) scannedPageCount++;

        if (pageText.trim().isNotEmpty) {
          indexResults.add(
            SearchIndex()
              ..bookId = bookId
              ..pageNumber = i
              ..pageText = pageText 
              ..isOcr = isScanned,
          );
        }

        sendPort?.send(IndexingProgress(
          bookId: bookId,
          currentPage: i + 1,
          totalPages: totalPages,
          isOcrActive: false,
        ));
      }

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
      await isar.close(); 
      
    } catch (e) {
      debugPrint("INDEXING CRITICAL FAILURE: $e");
    }
  });
}