import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:isar/isar.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/ocr_cache.dart';
import '../../core/models/search_index.dart';
import 'ocr_service.dart';
import 'package:flutter/foundation.dart';

final ocrServiceProvider = Provider((ref) => OcrService());

class OcrController extends StateNotifier<AsyncValue<void>> {
  final OcrService _ocrService;
  OcrController(this._ocrService) : super(const AsyncValue.data(null));

Future<void> processPageIfNeeded({
    required int bookId,
    required int pageNumber,
    required String filePath,
  }) async {
    final isar = await IsarService.instance;

    // 1. Check if we already have this page in OcrCache
    final existing = await isar.ocrCaches
        .filter()
        .bookIdEqualTo(bookId)
        .pageNumberEqualTo(pageNumber)
        .findFirst();

    if (existing != null) return; 

    state = const AsyncValue.loading();

    try {
      final document = await PdfDocument.openFile(filePath);
      final page = await document.getPage(pageNumber + 1);
      
      // ── THE FIX: Define render dimensions as doubles ──
      final double renderWidth = page.width * 2;
      final double renderHeight = page.height * 2;

      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: PdfPageImageFormat.jpeg,
        quality: 100,
      );

      await page.close();
      await document.close();

      if (pageImage == null) {
         state = const AsyncValue.data(null);
         return;
      }

      // Pass the non-null dimensions using ! since pageImage was rendered successfully
      final result = await _ocrService.recognizeImage(
        imageBytes: pageImage.bytes,
        width: pageImage.width!, 
        height: pageImage.height!,
      );

      // 3. Save to Cache and Update Search Index
      await isar.writeTxn(() async {
        final cache = OcrCache()
          ..bookId = bookId
          ..pageNumber = pageNumber
          ..blocksJson = jsonEncode(result.blocks.map((b) => b.toJson()).toList());
        
        await isar.ocrCaches.put(cache);

        final searchEntry = await isar.searchIndexs
            .filter()
            .bookIdEqualTo(bookId)
            .pageNumberEqualTo(pageNumber)
            .findFirst();

        if (searchEntry != null) {
          searchEntry.pageText = result.fullText;
          searchEntry.isOcr = false; 
          await isar.searchIndexs.put(searchEntry);
        }
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      debugPrint("OCR Controller Error: $e");
      state = AsyncValue.error(e, st);
    }
  }
}

final ocrControllerProvider = StateNotifierProvider<OcrController, AsyncValue<void>>((ref) {
  return OcrController(ref.watch(ocrServiceProvider));
});