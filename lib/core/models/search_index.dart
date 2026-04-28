import 'package:isar/isar.dart';

part 'search_index.g.dart';

@collection
class SearchIndex {
  Id id = Isar.autoIncrement;

  late int bookId;
  late int pageNumber;

  /// FTS-indexed page content
  @Index()
  late String pageText;

  /// True if this entry was produced by OCR rather than native text extraction
  bool isOcr = false;
}
