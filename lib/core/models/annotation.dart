import 'package:isar/isar.dart';

part 'annotation.g.dart';

@collection
class Annotation {
  Id id = Isar.autoIncrement;

  @Index()
  late int bookId;
  @Index()
  late int pageNumber;

  /// 'highlight' | 'note' | 'underline'
  late String type;

  late String colorHex;

  /// Normalized 0.0–1.0 quad points for resolution-independent storage
  late List<double> quadPoints;

  /// Non-null for 'note' type
  String? noteText;

  DateTime? createdAt;
}
