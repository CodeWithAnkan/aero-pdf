import 'package:flutter/foundation.dart';
import 'package:gemini_nano_android/gemini_nano_android.dart';

enum AiEngineType { auto, geminiNano }

enum SummaryMode { singlePage, chapter, global }

class SummaryResult {
  final List<String> sentences;
  final int sourcePageCount;
  final SummaryMode mode;

  const SummaryResult({
    required this.sentences,
    required this.sourcePageCount,
    required this.mode,
  });
}

class PageText {
  final int pageNumber;
  final String text;

  PageText({required this.pageNumber, required this.text});
}

abstract class AiEngine {
  Future<SummaryResult> summarizePage({
    required PageText page,
    required List<PageText> allPages,
    void Function(String)? onPartialResult,
  });

  Future<SummaryResult> summarizeChapter({
    required List<PageText> pages,
    required List<PageText> allPages,
    void Function(String)? onPartialResult,
  });

  Future<SummaryResult> summarizeGlobal({
    required List<String> chunkSummaries,
    void Function(String)? onPartialResult,
  });

  bool get isAvailable;
  String get engineName;
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine 1: On-Device (Gemini Nano via AICore)
// ─────────────────────────────────────────────────────────────────────────────

class AiCoreEngine implements AiEngine {
  @override
  final bool isAvailable;

  @override
  String get engineName => 'Gemini Nano (On-Device)';

  AiCoreEngine({required this.isAvailable});

  static Future<bool> checkSupport() async {
    try {
      final gemini = GeminiNanoAndroid();
      final available = await gemini.isAvailable().timeout(const Duration(seconds: 3));
      debugPrint('[AeroPDF] Gemini Nano available: $available');
      return available;
    } catch (e) {
      debugPrint('[AeroPDF] Gemini Nano check failed or timed out: $e');
      return false;
    }
  }

  @override
  Future<SummaryResult> summarizePage({
    required PageText page,
    required List<PageText> allPages,
    void Function(String)? onPartialResult,
  }) async {
    final text = page.text.trim();
    if (text.isEmpty) {
      return const SummaryResult(
        sentences: ['No text found on this page.'],
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    }

    const contextLimit = 8000;
    final truncated = text.length > contextLimit ? text.substring(0, contextLimit) : text;
    final prompt = '''Summarize this PDF page in exactly 3 short bullet points.
IMPORTANT: Be concise and ensure each sentence is finished completely.

TEXT:
$truncated''';

    try {
      final gemini = GeminiNanoAndroid();
      final response = await gemini.generate(prompt);

      return SummaryResult(
        sentences: _parseBulletPoints(response),
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    } catch (e) {
      return SummaryResult(
        sentences: ['Inference failed: $e'],
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    }
  }

  @override
  Future<SummaryResult> summarizeChapter({
    required List<PageText> pages,
    required List<PageText> allPages,
    void Function(String)? onPartialResult,
  }) async {
    if (pages.isEmpty) {
      return const SummaryResult(
        sentences: ['No content to summarize.'],
        sourcePageCount: 0,
        mode: SummaryMode.chapter,
      );
    }

    final combined = pages.map((p) => p.text.trim()).join('\n\n');
    const contextLimit = 10000;
    final truncated = combined.length > contextLimit ? combined.substring(0, contextLimit) : combined;

    final prompt = '''Summarize this PDF section in 3-5 concise bullet points. Focus on the most important key facts. 
IMPORTANT: Be brief and ensure every sentence is completed fully.

TEXT:
$truncated''';

    try {
      final gemini = GeminiNanoAndroid();
      final response = await gemini.generate(prompt);
      return SummaryResult(
        sentences: _parseBulletPoints(response),
        sourcePageCount: pages.length,
        mode: SummaryMode.chapter,
      );
    } catch (e) {
      return SummaryResult(
        sentences: ['Chapter summary failed: $e'],
        sourcePageCount: pages.length,
        mode: SummaryMode.chapter,
      );
    }
  }

  @override
  Future<SummaryResult> summarizeGlobal({
    required List<String> chunkSummaries,
    void Function(String)? onPartialResult,
  }) async {
    final combined = chunkSummaries.join('\n\n');
    const contextLimit = 8000;
    final truncated = combined.length > contextLimit ? combined.substring(0, contextLimit) : combined;

    final prompt = '''Synthesize these section summaries into a single cohesive final summary in 5-7 insightful bullet points.
IMPORTANT: Be extremely concise and ensure every sentence is finished completely.

SUMMARIES:
$truncated''';

    try {
      final gemini = GeminiNanoAndroid();
      final response = await gemini.generate(prompt);
      return SummaryResult(
        sentences: _parseBulletPoints(response),
        sourcePageCount: 0,
        mode: SummaryMode.global,
      );
    } catch (e) {
      return SummaryResult(
        sentences: ['Global synthesis failed: $e'],
        sourcePageCount: 0,
        mode: SummaryMode.global,
      );
    }
  }

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
// Factory — picks best available engine at runtime
// ─────────────────────────────────────────────────────────────────────────────

Future<AiEngine> buildAiEngine({AiEngineType type = AiEngineType.auto}) async {
  if (type == AiEngineType.geminiNano) return AiCoreEngine(isAvailable: true);

  if (defaultTargetPlatform == TargetPlatform.android) {
    final aiCoreSupported = await AiCoreEngine.checkSupport();
    if (aiCoreSupported) {
      return AiCoreEngine(isAvailable: true);
    }
  }

  return AiCoreEngine(isAvailable: false);
}