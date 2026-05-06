import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../db/isar_service.dart';
import '../models/book.dart';

/// Thin wrapper for PDF document operations.
class PdfService {
  PdfService._();

  /// Opens a [sf.PdfDocument] from [path].
  /// NOTE: This still uses readAsBytes because syncfusion_flutter_pdf requires it
  /// for manipulation (like saving annotations). Use with caution for large files.
  static Future<sf.PdfDocument?> openDocument(
    String path, {
    String? password,
  }) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (password != null) {
        return sf.PdfDocument(inputBytes: bytes, password: password);
      }
      return sf.PdfDocument(inputBytes: bytes);
    } catch (e) {
      debugPrint('[AeroPDF] Failed to open PDF for manipulation: $e');
      return null;
    }
  }

  /// Extracts the page count using pdfx, which is memory-efficient (streams from disk).
  static Future<int> getPageCount(String path) async {
    try {
      final document = await pdfx.PdfDocument.openFile(path);
      final count = document.pagesCount;
      await document.close();
      return count;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      // If pdfx says it's a password/encrypt error, we're done.
      if (errorStr.contains('password') || errorStr.contains('encrypt') || errorStr.contains('protect')) {
        return -1;
      }

      // If it's an "Unknown error" or similar, try Syncfusion as a second opinion.
      // Syncfusion sometimes gives more detailed error strings for encryption.
      try {
        final bytes = await File(path).readAsBytes();
        sf.PdfDocument(inputBytes: bytes);
        // If this succeeded, it means it's NOT password protected (otherwise it would throw).
        // But pdfx failed for some other reason? Unlikely, but let's be safe.
      } catch (sfError) {
        final sfErrStr = sfError.toString().toLowerCase();
        if (sfErrStr.contains('password') || sfErrStr.contains('encrypt') || sfErrStr.contains('protect')) {
          return -1;
        }
      }

      debugPrint('[AeroPDF] Failed to get page count: $e');
      return 0;
    }
  }

  /// Re-links a book's file path after the user moves/renames the file.
  /// The book is matched by its SHA-256 hash, not its path.
  static Future<bool> relinkBook(String newPath, String hash) async {
    try {
      final isar = await IsarService.instance;
      final book = await isar.books
          .where()
          .fileHashEqualTo(hash)
          .findFirst();
      if (book == null) return false;
      await isar.writeTxn(() async {
        book.filePath = newPath;
        await isar.books.put(book);
      });
      return true;
    } catch (e) {
      debugPrint('[AeroPDF] relinkBook failed: $e');
      return false;
    }
  }

  /// Extracts the display title from the filename.
  static String extractTitle(String fileName) {
    final name = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    return name;
  }
}
