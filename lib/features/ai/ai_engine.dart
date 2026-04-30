import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gemini_nano_android/gemini_nano_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Data Models
// ─────────────────────────────────────────────────────────────────────────────

class PageText {
  final int pageNumber;
  final String text;
  const PageText({required this.pageNumber, required this.text});
}

enum SummaryMode { singlePage, chapter, chunk, global }

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

enum AiEngineType { auto, geminiNano, slmPro }

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface — all engines implement this
// ─────────────────────────────────────────────────────────────────────────────

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
      // Add a strict timeout to hardware check to prevent hangs
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
      return const SummaryResult(
        sentences: ['Gemini Nano failed to generate summary.'],
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
      return SummaryResult(
        sentences: ['Gemini Nano failed to generate section summary.'],
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
    final truncated = combined.length > 4000 ? combined.substring(0, 4000) : combined;

    final prompt = '''The following are summaries of different parts of a book. Combine them into one final, comprehensive global summary of the entire book in 5-8 bullet points.
    
    Part Summaries:
    $truncated
    
    Final Global Summary:''';

    try {
      final response = await _gemini.generate(prompt);
      final sentences = _parseBulletPoints(response);
      return SummaryResult(
        sentences: sentences.isNotEmpty ? sentences : [response],
        sourcePageCount: 0,
        mode: SummaryMode.global,
      );
    } catch (e) {
      return SummaryResult(
        sentences: ['Gemini Nano failed to generate global summary.'],
        sourcePageCount: 0,
        mode: SummaryMode.global,
      );
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
// Engine 2: Local SLM (Gemma 2B) — Placeholder for development
// ─────────────────────────────────────────────────────────────────────────────

class SlmEngine implements AiEngine {
  LlmInferenceEngine? _engine;
  bool _isBusy = false;

  @override
  bool get isAvailable => true;

  @override
  String get engineName => 'Gemma 2B (Pro SLM)';

  Future<void> _ensureInitialized() async {
    if (_engine != null) return;

    final directory = await getApplicationSupportDirectory();
    final modelPath = '${directory.path}/gemma-2b-it-cpu-int4.bin';

    if (!await File(modelPath).exists()) {
      throw Exception("Model file not found at $modelPath. Please download it first.");
    }

    debugPrint('[AeroPDF] Initializing MediaPipe LlmInferenceEngine...');

    _engine = LlmInferenceEngine(
      LlmInferenceOptions.cpu(
        modelPath: modelPath,
        cacheDir: directory.path,
        maxTokens: 256,
        temperature: 0.6,
        topK: 20,
      ),
    );

    // Warm-up/Prime the engine ONLY during the first boot
    try {
      debugPrint('[AeroPDF] Priming SLM engine...');
      // We must consume the ENTIRE stream to ensure the controller is freed
      await _engine!.generateResponse('Hi').join().timeout(const Duration(seconds: 15));
      debugPrint('[AeroPDF] SLM engine primed and ready.');
    } catch (e) {
      debugPrint('[AeroPDF] Priming skipped: $e');
    }
  }

  @override
  Future<SummaryResult> summarizePage({
    required PageText page,
    required List<PageText> allPages,
    void Function(String)? onPartialResult,
  }) async {
    try {
      await _ensureInitialized();
      if (_isBusy) throw Exception("AI Engine is already processing a request.");
      _isBusy = true;

      final prompt = """<start_of_turn>user
Summarize the following page from a PDF document in 3-5 concise bullet points. Focus on the main ideas and technical details.

TEXT:
${page.text}<end_of_turn>
<start_of_turn>model
""";

      debugPrint('[AeroPDF] Starting generateResponse stream...');
      final stream = _engine!.generateResponse(prompt);
      final chunks = <String>[];
      
      await for (final chunk in stream) {
        if (chunks.isEmpty) debugPrint('[AeroPDF] First token received!');
        chunks.add(chunk);
        if (onPartialResult != null) onPartialResult(chunk);
      }
      debugPrint('[AeroPDF] Stream complete. Total chunks: ${chunks.length}');
      final response = chunks.join();
      
      final sentences = response
          .split(RegExp(r'\n|•|\*|-'))
          .map((s) => s.trim())
          .where((s) => s.length > 10)
          .toList();

      return SummaryResult(
        sentences: sentences.isNotEmpty ? sentences : [response],
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    } catch (e) {
      debugPrint('[AeroPDF] SLM Inference error: $e');
      _engine = null; // FORCE RESET ENGINE ON ANY ERROR
      return SummaryResult(
        sentences: ["Inference failed: ${e.toString()}"],
        sourcePageCount: 1,
        mode: SummaryMode.singlePage,
      );
    } finally {
      _isBusy = false;
    }
  }

  @override
  Future<SummaryResult> summarizeChapter({
    required List<PageText> pages,
    required List<PageText> allPages,
    void Function(String)? onPartialResult,
  }) async {
    try {
      await _ensureInitialized();
      if (_isBusy) throw Exception("AI Engine is already processing a request.");
      _isBusy = true;

      final combinedText = pages.map((p) => p.text).join('\n\n');
      final prompt = """<start_of_turn>user
Summarize this section of a PDF document in 5-7 clear bullet points. Highlight the key takeaways and important concepts.

TEXT:
$combinedText<end_of_turn>
<start_of_turn>model
""";

      debugPrint('[AeroPDF] Starting generateResponse stream (Chapter)...');
      final stream = _engine!.generateResponse(prompt);
      final chunks = <String>[];
      await for (final chunk in stream) {
        if (chunks.isEmpty) debugPrint('[AeroPDF] First token received (Chapter)!');
        chunks.add(chunk);
        if (onPartialResult != null) onPartialResult(chunk);
      }
      debugPrint('[AeroPDF] Stream complete. Total chunks: ${chunks.length}');
      final response = chunks.join();
      
      final sentences = response
          .split(RegExp(r'\n|•|\*|-'))
          .map((s) => s.trim())
          .where((s) => s.length > 10)
          .toList();

      return SummaryResult(
        sentences: sentences.isNotEmpty ? sentences : [response],
        sourcePageCount: pages.length,
        mode: SummaryMode.chapter,
      );
    } catch (e) {
      debugPrint('[AeroPDF] SLM Inference error: $e');
      _engine = null; // FORCE RESET ENGINE ON ANY ERROR
      return SummaryResult(
        sentences: ["Inference failed: ${e.toString()}"],
        sourcePageCount: 0,
        mode: SummaryMode.chapter,
      );
    } finally {
      _isBusy = false;
    }
  }

  @override
  Future<SummaryResult> summarizeGlobal({
    required List<String> chunkSummaries,
    void Function(String)? onPartialResult,
  }) async {
    try {
      await _ensureInitialized();
      if (_isBusy) throw Exception("AI Engine is already processing a request.");
      _isBusy = true;

      final combinedText = chunkSummaries.join('\n\n');
      final prompt = """<start_of_turn>user
The following are summaries of different sections of a PDF document. Synthesize them into one final, cohesive global summary of the entire document in 5-8 insightful bullet points.

SUMMARIES:
$combinedText<end_of_turn>
<start_of_turn>model
""";

      debugPrint('[AeroPDF] Starting generateResponse stream (Global)...');
      final stream = _engine!.generateResponse(prompt);
      final chunks = <String>[];
      await for (final chunk in stream) {
        if (chunks.isEmpty) debugPrint('[AeroPDF] First token received (Global)!');
        chunks.add(chunk);
        if (onPartialResult != null) onPartialResult(chunk);
      }
      debugPrint('[AeroPDF] Stream complete. Total chunks: ${chunks.length}');
      final response = chunks.join();
      
      final sentences = response
          .split(RegExp(r'\n|•|\*|-'))
          .map((s) => s.trim())
          .where((s) => s.length > 10)
          .toList();

      return SummaryResult(
        sentences: sentences.isNotEmpty ? sentences : [response],
        sourcePageCount: 0,
        mode: SummaryMode.global,
      );
    } catch (e) {
      debugPrint('[AeroPDF] SLM Inference error: $e');
      _engine = null; // FORCE RESET ENGINE ON ANY ERROR
      return SummaryResult(
        sentences: ["Global synthesis failed: ${e.toString()}"],
        sourcePageCount: 0,
        mode: SummaryMode.global,
      );
    } finally {
      _isBusy = false;
    }
  }

  void dispose() {
    _engine = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Factory — picks best available engine at runtime
// ─────────────────────────────────────────────────────────────────────────────

Future<AiEngine> buildAiEngine({AiEngineType override = AiEngineType.auto}) async {
  // ── Manual Overrides for Development ───────────────────────────────────────
  if (override == AiEngineType.geminiNano) return AiCoreEngine(isAvailable: true);
  if (override == AiEngineType.slmPro) return SlmEngine();

  // ── Auto Detection ─────────────────────────────────────────────────────────
  if (defaultTargetPlatform == TargetPlatform.android) {
    final aiCoreSupported = await AiCoreEngine.checkSupport();
    if (aiCoreSupported) {
      return AiCoreEngine(isAvailable: true);
    }
  }
  
  // Fallback to SLM (it will handle its own "isDownloaded" check or show empty)
  return SlmEngine();
}
