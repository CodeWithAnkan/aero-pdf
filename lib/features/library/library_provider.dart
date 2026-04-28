import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

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
      final file = File(path);
      final fileName = file.uri.pathSegments.last;
      final hash = await hashFile(path);

      final isar = await IsarService.instance;

      // Check if we already know this file by hash
      final existing = await isar.books
          .where()
          .fileHashEqualTo(hash)
          .findFirst();

      if (existing != null) {
        // File was moved — update path only
        await isar.writeTxn(() async {
          existing.filePath = path;
          existing.lastOpened = DateTime.now();
          await isar.books.put(existing);
        });
        await loadBooks();
        return existing;
      }

      // Open briefly to extract metadata
      final doc = await PdfService.openDocument(path);
      if (doc == null) {
        state = state.copyWith(
            isLoading: false, error: 'File is corrupted or cannot be opened.');
        return null;
      }

      final title = PdfService.extractTitle(fileName);
      final totalPages = doc.pages.count;
      doc.dispose();

      // Insert new book
      final book = Book()
        ..title = title
        ..filePath = path
        ..fileHash = hash
        ..fileName = fileName
        ..totalPages = totalPages
        ..isIndexed = false
        ..addedAt = DateTime.now()
        ..lastOpened = DateTime.now();

      await isar.writeTxn(() => isar.books.put(book));

      // Start background FTS + OCR indexing
      final isarDir = await IsarService.directoryPath;
      indexBookInBackground(book.id, path, isarDir);

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
    await isar.writeTxn(() async {
      await isar.books.delete(bookId);
      await isar.annotations
          .filter()
          .bookIdEqualTo(bookId)
          .deleteAll();
      await isar.searchIndexs
          .filter()
          .bookIdEqualTo(bookId)
          .deleteAll();
      await isar.ocrCaches
          .filter()
          .bookIdEqualTo(bookId)
          .deleteAll();
    });
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
