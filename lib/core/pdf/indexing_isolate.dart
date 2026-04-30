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
          final lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
          final buffer = StringBuffer();
          
          for (final line in lines) {
            if (line.wordCollection.isEmpty) continue;
            
            final words = line.wordCollection;
            buffer.write(words[0].text);
            
            for (int j = 1; j < words.length; j++) {
              final prev = words[j - 1];
              final curr = words[j];
              
              // If the distance between words is very small (< 2.0 pixels), 
              // it's likely a fragmented word from kerning/layout quirks.
              final distance = curr.bounds.left - (prev.bounds.left + prev.bounds.width);
              
              if (distance < 2.0 && distance > -5.0) {
                // Join without space
                buffer.write(curr.text);
              } else {
                // Actual space between words
                buffer.write(' ');
                buffer.write(curr.text);
              }
            }
            buffer.writeln();
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