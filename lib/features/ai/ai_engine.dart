import 'package:flutter/foundation.dart';
import 'package:gemini_nano_android/gemini_nano_android.dart';

import 'extractive_engine.dart';
import 'extractive_engine.dart' as extractive;

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface — all engines implement this
// ─────────────────────────────────────────────────────────────────────────────

abstract class AiEngine {
  Future<SummaryResult> summarizePage({
    required PageText page,
    required List<PageText> allPages,
  });

  Future<SummaryResult> summarizeChapter({
    required List<PageText> pages,
    required List<PageText> allPages,
  });

  bool get isAvailable;
  String get engineName;
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine 1: Gemini Nano via AICore — OnePlus 15, Pixel 9+, Galaxy S25+
// ─────────────────────────────────────────────────────────────────────────────

class AiCoreEngine implements AiEngine {
  @override
  final bool isAvailable;

  @override
  String get engineName => 'Gemini Nano (On-Device)';

  final _gemini = GeminiNanoAndroid();

  AiCoreEngine({required this.isAvailable});

  /// Check if the current device supports Gemini Nano via AICore.
  static Future<bool> checkSupport() async {
    try {
      final gemini = GeminiNanoAndroid();
      final available = await gemini.isAvailable();
      debugPrint('[AeroPDF] Gemini Nano available: $available');
      return available;
    } catch (e) {
      debugPrint('[AeroPDF] Gemini Nano check failed: $e');
      return false;
    }
  }

  @override
  Future<SummaryResult> summarizePage({
    required PageText page,
    required List<PageText> allPages,
  }) async {
    final text = page.text.trim();
    if (text.isEmpty) {
      return const SummaryResult(
        sentences: ['No text found on this page.'],
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    }

    // Truncate to ~2000 chars to fit Gemini Nano's context window
    final truncated = text.length > 2000 ? text.substring(0, 2000) : text;

    final prompt = '''Summarize the following PDF page content in exactly 3 concise bullet points. Each bullet point should be a single sentence capturing a key idea.

Page content:
$truncated

Summary:''';

    try {
      final response = await _gemini.generate(prompt);
      final sentences = _parseBulletPoints(response);
      return SummaryResult(
        sentences: sentences.isNotEmpty
            ? sentences
            : ['Could not parse summary from model output.'],
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    } catch (e) {
      debugPrint('[AeroPDF] Gemini Nano generation error: $e');
      // Fall back to extractive on error
      return extractive.summarizePage(page: page, allPages: allPages);
    }
  }

  @override
  Future<SummaryResult> summarizeChapter({
    required List<PageText> pages,
    required List<PageText> allPages,
  }) async {
    if (pages.isEmpty) {
      return const SummaryResult(
        sentences: [],
        sourcePageCount: 0,
        mode: SummaryMode.chapter,
      );
    }

    final combined = pages.map((p) => p.text.trim()).join('\n\n');
    // Truncate to ~3000 chars for chapter summaries
    final truncated =
        combined.length > 3000 ? combined.substring(0, 3000) : combined;

    final prompt = '''Summarize the following PDF section (${pages.length} pages) in exactly 5 concise bullet points. Each bullet point should be a single sentence capturing a key idea.

Section content:
$truncated

Summary:''';

    try {
      final response = await _gemini.generate(prompt);
      final sentences = _parseBulletPoints(response);
      return SummaryResult(
        sentences: sentences.isNotEmpty
            ? sentences
            : ['Could not parse summary from model output.'],
        sourcePageCount: pages.length,
        mode: SummaryMode.chapter,
      );
    } catch (e) {
      debugPrint('[AeroPDF] Gemini Nano chapter error: $e');
      return extractive.summarizeChapter(pages: pages, allPages: allPages);
    }
  }

  /// Parse bullet points from Gemini Nano's text output.
  List<String> _parseBulletPoints(String text) {
    if (text.trim().isEmpty) return [];

    return text
        .split('\n')
        .map((line) => line
            .replaceAll(RegExp(r'^[\s•\-\*\d\.]+'), '')
            .trim())
        .where((line) => line.isNotEmpty && line.length > 10)
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine 2: ExtractiveEngine — zero download fallback, all devices
// ─────────────────────────────────────────────────────────────────────────────

class LocalExtractiveEngine implements AiEngine {
  @override
  bool get isAvailable => true;

  @override
  String get engineName => 'AeroPDF On-Device (TF-IDF)';

  @override
  Future<SummaryResult> summarizePage({
    required PageText page,
    required List<PageText> allPages,
  }) =>
      extractive.summarizePage(page: page, allPages: allPages);

  @override
  Future<SummaryResult> summarizeChapter({
    required List<PageText> pages,
    required List<PageText> allPages,
  }) =>
      extractive.summarizeChapter(pages: pages, allPages: allPages);
}

// ─────────────────────────────────────────────────────────────────────────────
// Factory — picks best available engine at runtime
// ─────────────────────────────────────────────────────────────────────────────

Future<AiEngine> buildAiEngine() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final aiCoreSupported = await AiCoreEngine.checkSupport();
    if (aiCoreSupported) {
      debugPrint('[AeroPDF] ✓ AI engine: Gemini Nano via AICore');
      return AiCoreEngine(isAvailable: true);
    }
  }
  debugPrint('[AeroPDF] → AI engine: LocalExtractiveEngine (TF-IDF fallback)');
  return LocalExtractiveEngine();
}
