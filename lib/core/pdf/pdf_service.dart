import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../db/isar_service.dart';
import '../models/book.dart';

/// Thin wrapper for PDF document operations.
/// Error handling (password, corrupt, OOM) lives here.
class PdfService {
  PdfService._();

  /// Opens a [PdfDocument] from [path].
  /// - Returns null on unrecoverable error (corrupted file).
  /// - Throws [PdfDocumentException] if the file is password-protected and
  ///   no password was provided — caller should prompt and retry.
  static Future<PdfDocument?> openDocument(
    String path, {
    String? password,
  }) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (password != null) {
        return PdfDocument(inputBytes: bytes, password: password);
      }
      return PdfDocument(inputBytes: bytes);
    } catch (e) {
      debugPrint('[AeroPDF] Failed to open PDF: $e');
      return null;
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
