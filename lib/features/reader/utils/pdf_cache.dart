import 'dart:io';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global caches
// ─────────────────────────────────────────────────────────────────────────────

final Map<String, Uint8List> pdfBytesCache = {};

/// Called by LibraryScreen on tap — before the route transition starts.
/// Reads the file on a separate isolate via [compute] so it never competes
/// with the main thread during the fade transition animation.
void warmUpPdfBytes(String filePath) {
  if (pdfBytesCache.containsKey(filePath)) return; // already warm
  // ignore: unawaited_futures
  compute(readFileBytes, filePath).then((bytes) {
    pdfBytesCache[filePath] = bytes;
  }).ignore(); // silently discard errors; _loadBook will fall back to .file
}

// Top-level function required by compute() — must not be a closure or method.
Future<Uint8List> readFileBytes(String path) => File(path).readAsBytes();
