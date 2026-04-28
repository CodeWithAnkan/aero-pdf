import 'package:isar/isar.dart';

part 'book.g.dart';

@collection
class Book {
  Id id = Isar.autoIncrement;

  late String title;
  late String filePath;

  /// SHA-256 hash — used to re-link annotations if file moves
  @Index()
  late String fileHash;

  /// Display fallback when title can't be extracted
  late String fileName;

  int lastReadPage = 0;
  int totalPages = 0;

  /// True once FTS indexing completes
  bool isIndexed = false;

  bool isPasswordProtected = false;

  /// Count of pages that were OCR'd (0 for native-text PDFs)
  int scannedPageCount = 0;

  @Index()
  DateTime? lastOpened;
  DateTime? addedAt;
}
