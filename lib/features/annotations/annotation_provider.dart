import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:isar/isar.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/annotation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider — family keyed by bookId
// ─────────────────────────────────────────────────────────────────────────────

final annotationProvider =
    StateNotifierProvider.family<AnnotationNotifier, List<Annotation>, int>(
  (ref, bookId) => AnnotationNotifier(bookId),
);

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AnnotationNotifier extends StateNotifier<List<Annotation>> {
  AnnotationNotifier(this._bookId) : super(const []) {
    _load();
  }

  final int _bookId;

  Future<void> _load() async {
    final isar = await IsarService.instance;
    final all = await isar.annotations
        .where()
        .bookIdEqualTo(_bookId)
        .findAll();
    state = all;
  }

  Future<void> addHighlight({
    required int pageNumber,
    required List<double> quadPoints,
    String colorHex = '#FFFF00',
  }) async {
    final ann = Annotation()
      ..bookId = _bookId
      ..pageNumber = pageNumber
      ..type = 'highlight'
      ..colorHex = colorHex
      ..quadPoints = quadPoints
      ..createdAt = DateTime.now();

    final isar = await IsarService.instance;
    await isar.writeTxn(() => isar.annotations.put(ann));
    await _load();
  }

  Future<void> addUnderline({
    required int pageNumber,
    required List<double> quadPoints,
    String colorHex = '#2196F3',
  }) async {
    final ann = Annotation()
      ..bookId = _bookId
      ..pageNumber = pageNumber
      ..type = 'underline'
      ..colorHex = colorHex
      ..quadPoints = quadPoints
      ..createdAt = DateTime.now();

    final isar = await IsarService.instance;
    await isar.writeTxn(() => isar.annotations.put(ann));
    await _load();
  }

  Future<void> addNote({
    required int pageNumber,
    required List<double> quadPoints,
    required String noteText,
  }) async {
    final ann = Annotation()
      ..bookId = _bookId
      ..pageNumber = pageNumber
      ..type = 'note'
      ..colorHex = '#4CAF50'
      ..quadPoints = quadPoints
      ..noteText = noteText
      ..createdAt = DateTime.now();

    final isar = await IsarService.instance;
    await isar.writeTxn(() => isar.annotations.put(ann));
    await _load();
  }

  Future<void> delete(int annotationId) async {
    final isar = await IsarService.instance;
    await isar.writeTxn(() => isar.annotations.delete(annotationId));
    await _load();
  }
}
