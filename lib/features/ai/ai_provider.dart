import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/isar_service.dart';
import '../../core/models/ai_summary.dart';
import 'ai_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Engine provider — initialised once per app session
// ─────────────────────────────────────────────────────────────────────────────

final aiEngineSelectionProvider = StateProvider<AiEngineType>((ref) => AiEngineType.auto);

final aiEngineProvider = FutureProvider.autoDispose<AiEngine>((ref) async {
  final selection = ref.watch(aiEngineSelectionProvider);
  return buildAiEngine(override: selection);
});

// ─────────────────────────────────────────────────────────────────────────────
// Summary state
// ─────────────────────────────────────────────────────────────────────────────

class InsightsState {
  final AsyncValue<SummaryResult?> result;
  final List<String> thinkingSteps;
  final bool isProcessingGlobal;
  final bool hasFastSummary;

  const InsightsState({
    this.result = const AsyncValue.data(null),
    this.thinkingSteps = const [],
    this.isProcessingGlobal = false,
    this.hasFastSummary = false,
  });

  InsightsState copyWith({
    AsyncValue<SummaryResult?>? result,
    List<String>? thinkingSteps,
    bool? isProcessingGlobal,
    bool? hasFastSummary,
  }) =>
      InsightsState(
        result: result ?? this.result,
        thinkingSteps: thinkingSteps ?? this.thinkingSteps,
        isProcessingGlobal: isProcessingGlobal ?? this.isProcessingGlobal,
        hasFastSummary: hasFastSummary ?? this.hasFastSummary,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Insights notifier
// ─────────────────────────────────────────────────────────────────────────────

class InsightsNotifier extends StateNotifier<InsightsState> {
  InsightsNotifier() : super(const InsightsState());

  bool _isCancelled = false;
  bool _isGenerating = false;
  
  void cancel() {
    _isCancelled = true;
    _isGenerating = false;
  }
  
  Future<void> checkCache(int bookId) async {
    final isar = await IsarService.instance;
    final existing = await isar.collection<AiSummary>().filter().bookIdEqualTo(bookId).findFirst();
    
    if (existing?.globalSummary != null) {
      state = state.copyWith(
        result: AsyncValue.data(SummaryResult(
          sentences: existing!.globalSummary!.split('\n'),
          sourcePageCount: 0,
          mode: SummaryMode.global,
        )),
        hasFastSummary: existing.quickSummary != null,
      );
    } else if (existing?.quickSummary != null) {
       state = state.copyWith(
        result: AsyncValue.data(SummaryResult(
          sentences: existing!.quickSummary!.split('\n'),
          sourcePageCount: 0,
          mode: SummaryMode.chapter,
        )),
        hasFastSummary: true,
      );
    }
  }

  Future<void> generate({
    required int bookId,
    required AiEngine engine,
    required PageText currentPage,
    required List<PageText> allPages,
  }) async {
    if (_isGenerating) return;
    _isGenerating = true;
    
    try {
      final isar = await IsarService.instance;
      
      // 1. Check for existing Global Summary
      final existing = await isar.collection<AiSummary>().filter().bookIdEqualTo(bookId).findFirst();
      if (existing?.globalSummary != null) {
        state = state.copyWith(
          result: AsyncValue.data(SummaryResult(
            sentences: existing!.globalSummary!.split('\n'),
            sourcePageCount: allPages.length,
            mode: SummaryMode.global,
          )),
          isProcessingGlobal: false,
          thinkingSteps: ['Loaded cached global summary.'],
        );
        return;
      }

      _isCancelled = false;
      state = state.copyWith(
        result: const AsyncValue.loading(),
        thinkingSteps: ['Booting AI Engine...', 'Checking hardware compatibility...'],
        isProcessingGlobal: true,
        hasFastSummary: existing?.quickSummary != null,
      );

      // 2. Run FAST MIX first
      await _generateFastMix(bookId, engine, currentPage, allPages, isar);
      
      // Mandatory cooldown to let native controller clear
      await Future.delayed(const Duration(seconds: 1));

      // 3. Start MAP-REDUCE in background
      await _runMapReduce(bookId, engine, allPages, isar, existing);

    } catch (e, st) {
      state = state.copyWith(
        result: AsyncValue.error(e, st),
        isProcessingGlobal: false,
      );
      _addStep('Fatal Error: $e');
    } finally {
      _isGenerating = false;
    }
  }

  Future<void> _generateFastMix(int bookId, AiEngine engine, PageText currentPage, List<PageText> allPages, Isar isar) async {
    _addStep('Stage 1: Generating Quick Summary (Intro + Current)...');
    
    // Quick Mix: Pages 1-10 + Current +/- 10
    final pageNum = currentPage.pageNumber;
    final targetPages = allPages.where((p) => 
      p.pageNumber <= 10 || (p.pageNumber >= pageNum - 10 && p.pageNumber <= pageNum + 10)
    ).toList();

    try {
      _addStep('Waiting for AI response...');
      final result = await engine.summarizeChapter(
        pages: targetPages,
        allPages: allPages,
        onPartialResult: (chunk) => _updateLastStep(chunk),
      );
      if (_isCancelled) return;

      final summaryText = result.sentences.join('\n');
      
      // Save to DB
      await isar.writeTxn(() async {
        final existing = await isar.collection<AiSummary>().filter().bookIdEqualTo(bookId).findFirst();
        final update = (existing ?? AiSummary())..bookId = bookId..quickSummary = summaryText..lastUpdated = DateTime.now();
        await isar.collection<AiSummary>().put(update);
      });

      if (!state.hasFastSummary) {
        state = state.copyWith(
          result: AsyncValue.data(result),
          hasFastSummary: true,
        );
        _addStep('Quick Summary ready.');
      }
    } catch (e) {
      _addStep('Quick Summary failed: $e');
    }
  }

  Future<void> _runMapReduce(int bookId, AiEngine engine, List<PageText> allPages, Isar isar, AiSummary? existing) async {
    final chunks = <int, List<PageText>>{};
    for (int i = 0; i < allPages.length; i += 50) {
      final end = (i + 50 < allPages.length) ? i + 50 : allPages.length;
      chunks[i + 1] = allPages.sublist(i, end);
    }

    final chunkSummaries = <int, String>{};
    if (existing?.chunkSummariesJson != null) {
      final decoded = jsonDecode(existing!.chunkSummariesJson!) as Map<String, dynamic>;
      decoded.forEach((k, v) => chunkSummaries[int.parse(k)] = v as String);
    }
    
    for (final entry in chunks.entries) {
      if (_isCancelled) return;
      if (chunkSummaries.containsKey(entry.key)) {
        _addStep('Skipping cached Chunk ${entry.key} (Pages ${entry.key}-${entry.key + 49})...');
        continue;
      }

      final endPage = entry.key + entry.value.length - 1;
      _addStep('Analyzing Chunk ${entry.key} (Pages ${entry.key}-$endPage)...');
      
      try {
        _addStep('Waiting for AI response...');
        final result = await engine.summarizeChapter(
          pages: entry.value,
          allPages: allPages,
          onPartialResult: (chunk) => _updateLastStep(chunk),
        );
        chunkSummaries[entry.key] = result.sentences.join('\n');

        // Persist chunk immediately
        await isar.writeTxn(() async {
          final s = await isar.collection<AiSummary>().filter().bookIdEqualTo(bookId).findFirst();
          final update = (s ?? AiSummary())..bookId = bookId..chunkSummariesJson = jsonEncode(chunkSummaries.map((k, v) => MapEntry(k.toString(), v)))..lastUpdated = DateTime.now();
          await isar.collection<AiSummary>().put(update);
        });
      } catch (e) {
        _addStep('Failed chunk ${entry.key}: $e');
      }
    }

    // FINAL REDUCE
    if (_isCancelled) return;

    // Shortcut: If we only have 1 chunk, that IS our global summary.
    if (chunkSummaries.length == 1) {
      _addStep('Book is short. Finalizing result...');
      final globalText = chunkSummaries.values.first;
      await _saveGlobalSummary(bookId, globalText, allPages.length, isar);
      return;
    }

    _addStep('Synthesizing Global Summary from ${chunkSummaries.length} parts...');
    
    try {
      _addStep('Waiting for AI response...');
      final global = await engine.summarizeGlobal(
        chunkSummaries: chunkSummaries.values.toList(),
        onPartialResult: (chunk) => _updateLastStep(chunk),
      );
      await _saveGlobalSummary(bookId, global.sentences.join('\n'), allPages.length, isar);
    } catch (e) {
      _addStep('Global synthesis failed: $e');
      state = state.copyWith(isProcessingGlobal: false);
    }
  }

  Future<void> _saveGlobalSummary(int bookId, String text, int totalPages, Isar isar) async {
    try {
      await isar.writeTxn(() async {
        final s = await isar.collection<AiSummary>().filter().bookIdEqualTo(bookId).findFirst();
        final update = (s ?? AiSummary())..bookId = bookId..globalSummary = text;
        await isar.collection<AiSummary>().put(update);
      });

      state = state.copyWith(
        result: AsyncValue.data(SummaryResult(
          sentences: text.split('\n'),
          sourcePageCount: totalPages,
          mode: SummaryMode.global,
        )),
        isProcessingGlobal: false,
      );
      _addStep('Global Summary complete!');
    } catch (e) {
      _addStep('Failed to save global summary: $e');
      state = state.copyWith(isProcessingGlobal: false);
    }
  }

  void _addStep(String step) {
    state = state.copyWith(thinkingSteps: [...state.thinkingSteps, step]);
  }

  void _updateLastStep(String chunk) {
    if (state.thinkingSteps.isEmpty) return;
    final last = state.thinkingSteps.last;
    if (last.startsWith('AI: ')) {
      final newSteps = List<String>.from(state.thinkingSteps);
      // We append to the existing text in the log entry
      newSteps[newSteps.length - 1] = last + chunk;
      state = state.copyWith(thinkingSteps: newSteps);
    } else {
      _addStep('AI: $chunk');
    }
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
  }

  void clear(Isar isar, int bookId) async {
    await isar.writeTxn(() async {
      await isar.collection<AiSummary>().filter().bookIdEqualTo(bookId).deleteAll();
    });
    state = const InsightsState();
  }
}

final insightsProvider =
    StateNotifierProvider.autoDispose<InsightsNotifier, InsightsState>(
  (ref) => InsightsNotifier(),
);
