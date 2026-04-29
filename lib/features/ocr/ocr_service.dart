import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result types
// ─────────────────────────────────────────────────────────────────────────────

class OcrBlock {
  final String text;

  /// Bounding box normalised to 0.0–1.0 (relative to page dimensions).
  final Rect boundingBox;

  const OcrBlock({required this.text, required this.boundingBox});

  Map<String, dynamic> toJson() => {
        'text': text,
        'left': boundingBox.left,
        'top': boundingBox.top,
        'right': boundingBox.right,
        'bottom': boundingBox.bottom,
      };

  factory OcrBlock.fromJson(Map<String, dynamic> json) => OcrBlock(
        text: json['text'] as String,
        boundingBox: Rect.fromLTRB(
          (json['left'] as num).toDouble(),
          (json['top'] as num).toDouble(),
          (json['right'] as num).toDouble(),
          (json['bottom'] as num).toDouble(),
        ),
      );
}

class OcrResult {
  final String fullText;
  final List<OcrBlock> blocks;
  const OcrResult({required this.fullText, required this.blocks});
}

// ─────────────────────────────────────────────────────────────────────────────
// OcrService
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps Google ML Kit Text Recognition v2 for on-device OCR.
///
/// - Zero APK size increase (model is served by Play Services).
/// - Fully offline after the first model fetch (~2MB, once per device).
/// - Returns normalised bounding boxes suitable for resolution-independent
///   annotation rendering.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs ML Kit OCR on raw image bytes, returns structured result.
  /// [imageBytes] must be BGRA8888 format.
  Future<OcrResult> recognizeImage({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async {
    // Convert raw bytes → InputImage for ML Kit
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: width * 4,
      ),
    );

    // Run on-device OCR
    final recognized = await _recognizer.processImage(inputImage);

    // Normalise bounding boxes and return
    final blocks = recognized.blocks
        .map((b) => OcrBlock(
              text: b.text,
              boundingBox: _normalise(
                b.boundingBox,
                width.toDouble(),
                height.toDouble(),
              ),
            ))
        .toList();

    return OcrResult(
      fullText: blocks.map((b) => b.text).join('\n'),
      blocks: blocks,
    );
  }

  Rect _normalise(Rect rect, double w, double h) => Rect.fromLTRB(
        rect.left / w,
        rect.top / h,
        rect.right / w,
        rect.bottom / h,
      );

  void dispose() => _recognizer.close();
}
