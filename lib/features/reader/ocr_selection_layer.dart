import 'package:flutter/material.dart';

import '../../core/pdf/ocr_service.dart';

/// Transparent overlay on top of a scanned PDF page that enables
/// long-press text selection using OCR bounding boxes.
///
/// Rendered at page size. Bounding boxes are in 0.0–1.0 normalised coords.
class OcrSelectionLayer extends StatefulWidget {
  final List<OcrBlock> blocks;
  final Size pageSize;
  final void Function(String text) onTextSelected;

  const OcrSelectionLayer({
    super.key,
    required this.blocks,
    required this.pageSize,
    required this.onTextSelected,
  });

  @override
  State<OcrSelectionLayer> createState() => _OcrSelectionLayerState();
}

class _OcrSelectionLayerState extends State<OcrSelectionLayer> {
  final Set<int> _selectedIndices = {};

  void _hitTestBlocks(Offset localPosition) {
    final normX = localPosition.dx / widget.pageSize.width;
    final normY = localPosition.dy / widget.pageSize.height;

    for (int i = 0; i < widget.blocks.length; i++) {
      final box = widget.blocks[i].boundingBox;
      if (box.contains(Offset(normX, normY))) {
        setState(() {
          if (_selectedIndices.contains(i)) {
            _selectedIndices.remove(i);
          } else {
            _selectedIndices.add(i);
          }
        });

        // Report selected text upward
        final selectedText = _selectedIndices
            .map((idx) => widget.blocks[idx].text)
            .join(' ');
        widget.onTextSelected(selectedText);
        return;
      }
    }

    // Tap outside any block → clear selection
    if (_selectedIndices.isNotEmpty) {
      setState(() => _selectedIndices.clear());
      widget.onTextSelected('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (d) => _hitTestBlocks(d.localPosition),
      child: CustomPaint(
        size: widget.pageSize,
        painter: _OcrHighlightPainter(
          blocks: widget.blocks,
          selectedIndices: _selectedIndices,
          pageSize: widget.pageSize,
        ),
      ),
    );
  }
}

class _OcrHighlightPainter extends CustomPainter {
  final List<OcrBlock> blocks;
  final Set<int> selectedIndices;
  final Size pageSize;

  _OcrHighlightPainter({
    required this.blocks,
    required this.selectedIndices,
    required this.pageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.28)
      ..style = PaintingStyle.fill;

    for (final idx in selectedIndices) {
      if (idx >= blocks.length) continue;
      final norm = blocks[idx].boundingBox;
      final rect = Rect.fromLTRB(
        norm.left * size.width,
        norm.top * size.height,
        norm.right * size.width,
        norm.bottom * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OcrHighlightPainter old) =>
      old.selectedIndices != selectedIndices || old.blocks != blocks;
}
