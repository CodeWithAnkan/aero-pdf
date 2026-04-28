import 'package:isar/isar.dart';

part 'ocr_cache.g.dart';

@collection
class OcrCache {
  Id id = Isar.autoIncrement;

  @Index()
  late int bookId;
  @Index()
  late int pageNumber;

  /// JSON array of OcrBlock: [{text, left, top, right, bottom}]
  /// Bounding boxes are normalized 0.0–1.0
  late String blocksJson;
}
