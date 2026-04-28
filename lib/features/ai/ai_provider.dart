import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_engine.dart';
import 'extractive_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Engine provider — initialised once per app session
// ─────────────────────────────────────────────────────────────────────────────

final aiEngineProvider = FutureProvider<AiEngine>((ref) => buildAiEngine());

// ─────────────────────────────────────────────────────────────────────────────
// Summary state
// ─────────────────────────────────────────────────────────────────────────────

enum SummaryScope { page, chapter }

class InsightsState {
  final SummaryScope scope;
  final AsyncValue<SummaryResult?> result;

  const InsightsState({
    this.scope = SummaryScope.page,
    this.result = const AsyncValue.data(null),
  });

  InsightsState copyWith({
    SummaryScope? scope,
    AsyncValue<SummaryResult?>? result,
  }) =>
      InsightsState(
        scope: scope ?? this.scope,
        result: result ?? this.result,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Insights notifier
// ─────────────────────────────────────────────────────────────────────────────

class InsightsNotifier extends StateNotifier<InsightsState> {
  InsightsNotifier() : super(const InsightsState());

  Future<void> summarize({
    required AiEngine engine,
    required PageText currentPage,
    required List<PageText> allPages,
    SummaryScope scope = SummaryScope.page,
  }) async {
    state = state.copyWith(
      scope: scope,
      result: const AsyncValue.loading(),
    );

    try {
      final SummaryResult result;

      if (scope == SummaryScope.page) {
        result = await engine.summarizePage(
          page: currentPage,
          allPages: allPages,
        );
      } else {
        // Chapter: current page ± 2
        final pageNum = currentPage.pageNumber;
        final chapterPages = allPages
            .where((p) =>
                p.pageNumber >= pageNum - 2 && p.pageNumber <= pageNum + 2)
            .toList();
        result = await engine.summarizeChapter(
          pages: chapterPages,
          allPages: allPages,
        );
      }

      state = state.copyWith(result: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(result: AsyncValue.error(e, st));
    }
  }

  void setScope(SummaryScope scope) {
    state = state.copyWith(scope: scope);
  }

  void clear() {
    state = const InsightsState();
  }
}

final insightsProvider =
    StateNotifierProvider<InsightsNotifier, InsightsState>(
  (ref) => InsightsNotifier(),
);
