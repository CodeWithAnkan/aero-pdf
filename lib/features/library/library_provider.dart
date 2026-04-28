import 'dart:io';

import 'package:aeropdf/features/library/book_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/annotation.dart';
import '../../core/models/book.dart';
import '../../core/models/ocr_cache.dart';
import '../../core/models/search_index.dart';
import '../../core/pdf/hash_service.dart';
import '../../core/pdf/indexing_isolate.dart';
import '../../core/pdf/pdf_service.dart';
import '../../core/permissions/permission_handler.dart' as perms;

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class LibraryState {
  final List<Book> books;
  final bool isLoading;
  final String? error;

  const LibraryState({
    this.books = const [],
    this.isLoading = false,
    this.error,
  });

  LibraryState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
  }) =>
      LibraryState(
        books: books ?? this.books,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    loadBooks();
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isar = await IsarService.instance;
      final books = await isar.books
          .where()
          .sortByLastOpenedDesc()
          .findAll();
      state = state.copyWith(books: books, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Pick and add PDF ────────────────────────────────────────────────────────

  Future<Book?> pickAndAddPdf() async {
    final hasPermission = await perms.requestStoragePermission();
    if (!hasPermission) return null;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    return _addPdf(path);
  }

Future<Book?> _addPdf(String path) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final file = File(path); // <-- Defined as 'file' here
      final fileName = file.uri.pathSegments.last;
      final hash = await hashFile(path);

      final isar = await IsarService.instance;

      // Check if we already know this file by hash
      final existing = await isar.books
          .where()
          .fileHashEqualTo(hash)
          .findFirst();

      if (existing != null) {
        await isar.writeTxn(() async {
          existing.lastOpened = DateTime.now();
          await isar.books.put(existing);
        });
        await loadBooks();
        return existing;
      }

      // ── THE FIX: Copy file to permanent storage ──
      final appDocDir = await getApplicationDocumentsDirectory();
      final permanentPath = '${appDocDir.path}/$fileName';
      
      // Use 'file.copy' instead of 'originalFile.copy'
      final savedFile = await file.copy(permanentPath); 

      // Open briefly to extract metadata from the PERMANENT path
      final doc = await PdfService.openDocument(savedFile.path);
      if (doc == null) {
        state = state.copyWith(
            isLoading: false, error: 'File is corrupted or cannot be opened.');
        return null;
      }

      final title = PdfService.extractTitle(fileName);
      final totalPages = doc.pages.count;
      doc.dispose();

      // Insert new book pointing to permanent storage
      final book = Book()
        ..title = title
        ..filePath = savedFile.path
        ..fileHash = hash
        ..fileName = fileName
        ..totalPages = totalPages
        ..isIndexed = false
        ..addedAt = DateTime.now()
        ..lastOpened = DateTime.now();

      await isar.writeTxn(() => isar.books.put(book));

      // Start background FTS + OCR indexing
      final isarDir = await IsarService.directoryPath;
      indexBookInBackground(book.id, savedFile.path, isarDir);

      await loadBooks();
      return book;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // ── Delete book ─────────────────────────────────────────────────────────────

  Future<void> deleteBook(int bookId) async {
    final isar = await IsarService.instance;
    
    // We skip File(path).delete() here to keep the physical file safe.

    await isar.writeTxn(() async {
      // 1. Remove the book entry
      await isar.books.delete(bookId);
      
      // 2. Clean up associated data to prevent database bloat
      await isar.annotations.filter().bookIdEqualTo(bookId).deleteAll();
      await isar.searchIndexs.filter().bookIdEqualTo(bookId).deleteAll();
      await isar.ocrCaches.filter().bookIdEqualTo(bookId).deleteAll();
    });

    // 3. Clear the memory cache for the thumbnail
    thumbnailCache.remove(bookId); 

    await loadBooks(); 
  }

  // ── Mark corrupted ──────────────────────────────────────────────────────────

  Future<void> markCorrupted(String fileHash) async {
    final isar = await IsarService.instance;
    final book = await isar.books
        .where()
        .fileHashEqualTo(fileHash)
        .findFirst();
    if (book != null) await deleteBook(book.id);
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>(
  (ref) => LibraryNotifier(),
);
