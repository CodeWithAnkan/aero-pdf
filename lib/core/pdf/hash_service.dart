import 'dart:io';

import 'package:crypto/crypto.dart';

/// Computes a SHA-256 hash of the file at [path].
/// Used to detect file moves — if the hash matches an existing [Book],
/// annotations are re-linked instead of creating a duplicate entry.
Future<String> hashFile(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}
