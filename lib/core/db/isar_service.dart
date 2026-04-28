import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/annotation.dart';
import '../models/book.dart';
import '../models/ocr_cache.dart';
import '../models/search_index.dart';

/// Singleton wrapper around the Isar database.
/// Call [IsarService.instance] to get the opened [Isar] handle.
class IsarService {
  IsarService._();

  static Isar? _isar;

  static Future<Isar> get instance async {
    if (_isar != null && _isar!.isOpen) return _isar!;
    _isar = await _open();
    return _isar!;
  }

  static Future<Isar> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [
        BookSchema,
        AnnotationSchema,
        SearchIndexSchema,
        OcrCacheSchema,
      ],
      directory: dir.path,
      name: 'aeropdf',
    );
  }

  /// Returns the Isar data directory path (needed for isolates that must open
  /// their own Isar instance with the same directory).
  static Future<String> get directoryPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
