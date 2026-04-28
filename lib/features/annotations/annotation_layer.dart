import 'package:flutter/material.dart';

import '../../core/models/annotation.dart';

/// Renders highlight / underline / note annotations on top of a PDF page.
/// All coordinates are normalised (0.0–1.0) and scaled to [pageSize] at paint time.
class AnnotationLayer extends StatelessWidget {
  final List<Annotation> annotations;
  final Size pageSize;

  const AnnotationLayer({
    super.key,
    required this.annotations,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) return const SizedBox.expand();

    return CustomPaint(
      size: pageSize,
      painter: _AnnotationPainter(
        annotations: annotations,
        pageSize: pageSize,
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Size pageSize;

  _AnnotationPainter({required this.annotations, required this.pageSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final ann in annotations) {
      final color = _parseColor(ann.colorHex);
      if (ann.quadPoints.length < 4) continue;

      final rect = _quadToRect(ann.quadPoints, size);

      switch (ann.type) {
        case 'highlight':
          canvas.drawRect(
            rect,
            Paint()
              ..color = color.withOpacity(0.35)
              ..style = PaintingStyle.fill,
          );

        case 'underline':
          final linePaint = Paint()
            ..color = color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(rect.left, rect.bottom),
            Offset(rect.right, rect.bottom),
            linePaint,
          );

        case 'note':
          // Draw a small note icon at the top-right corner of the selection
          final iconPaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(rect.right, rect.top),
            6,
            iconPaint,
          );
      }
    }
  }

  /// Convert normalised [quadPoints] (left, top, right, bottom) to a [Rect]
  /// scaled to [size].
  Rect _quadToRect(List<double> pts, Size size) {
    final l = pts[0] * size.width;
    final t = pts[1] * size.height;
    final r = pts[2] * size.width;
    final b = pts[3] * size.height;
    return Rect.fromLTRB(l, t, r, b);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.yellow;
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) =>
      old.annotations != annotations || old.pageSize != pageSize;
}
