// ignore_for_file: experimental_members_api
import 'package:isar/isar.dart';

part 'ai_summary.g.dart';

@collection
class AiSummary {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int bookId;

  /// The final full-book summary produced by Map-Reduce
  String? globalSummary;

  /// The fast "Intro + Current" summary
  String? quickSummary;

  /// Mini-summaries for every 50-page chunk.
  /// Key: Start page number (e.g. 1, 51, 101)
  /// Value: The JSON-encoded map of chunk index -> summary text
  String? chunkSummariesJson;

  /// The page range that the quick summary covers (e.g. "1-10, 90-110")
  String? quickSummaryRange;

  DateTime? lastUpdated;

  AiSummary();
}
