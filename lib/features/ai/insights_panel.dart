import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_engine.dart';
import 'ai_provider.dart';
import 'extractive_engine.dart';

/// Sliding bottom-sheet AI Insights panel.
/// Shows a [DraggableScrollableSheet] with engine badge, scope toggle,
/// summary sentences, and a "Copy" action.
class InsightsPanel extends ConsumerWidget {
  final PageText currentPage;
  final List<PageText> allPages;

  const InsightsPanel({
    super.key,
    required this.currentPage,
    required this.allPages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineAsync = ref.watch(aiEngineProvider);
    final insights = ref.watch(insightsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              const _DragHandle(),
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Insights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    // Engine badge
                    engineAsync.when(
                      data: (engine) => _EngineBadge(engine: engine),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // ── Scope toggle ─────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _ScopeToggle(
                  scope: insights.scope,
                  onChanged: (s) {
                    ref.read(insightsProvider.notifier).setScope(s);
                    engineAsync.whenData((engine) {
                      ref.read(insightsProvider.notifier).summarize(
                            engine: engine,
                            currentPage: currentPage,
                            allPages: allPages,
                            scope: s,
                          );
                    });
                  },
                ),
              ),
              // ── Summarise button ─────────────────────────────────────────
              if (insights.result is AsyncData &&
                  (insights.result as AsyncData).value == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        engineAsync.whenData((engine) {
                          ref.read(insightsProvider.notifier).summarize(
                                engine: engine,
                                currentPage: currentPage,
                                allPages: allPages,
                                scope: insights.scope,
                              );
                        });
                      },
                      icon: const Icon(Icons.summarize_rounded),
                      label: const Text('Summarise'),
                    ),
                  ),
                ),
              // ── Result area ──────────────────────────────────────────────
              Expanded(
                child: insights.result.when(
                  data: (result) {
                    if (result == null) return const SizedBox.shrink();
                    return _SummaryList(
                      result: result,
                      scrollController: scrollController,
                    );
                  },
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Analysing…',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not generate summary.\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _EngineBadge extends StatelessWidget {
  final AiEngine engine;
  const _EngineBadge({required this.engine});

  @override
  Widget build(BuildContext context) {
    final isNano = engine.engineName.contains('Gemini');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNano
            ? Colors.blue.withOpacity(0.15)
            : Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNano ? Colors.blue : Colors.green,
          width: 0.8,
        ),
      ),
      child: Text(
        engine.engineName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isNano ? Colors.blue : Colors.green,
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  final SummaryScope scope;
  final ValueChanged<SummaryScope> onChanged;

  const _ScopeToggle({required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SummaryScope>(
      segments: const [
        ButtonSegment(
          value: SummaryScope.page,
          label: Text('This Page'),
          icon: Icon(Icons.description_outlined, size: 16),
        ),
        ButtonSegment(
          value: SummaryScope.chapter,
          label: Text('Chapter (±2)'),
          icon: Icon(Icons.auto_stories_outlined, size: 16),
        ),
      ],
      selected: {scope},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _SummaryList extends StatelessWidget {
  final SummaryResult result;
  final ScrollController scrollController;

  const _SummaryList({
    required this.result,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (result.sentences.isEmpty) {
      return const Center(child: Text('No summary available for this page.'));
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ...result.sentences.asMap().entries.map((entry) {
          return _SentenceTile(
            index: entry.key,
            sentence: entry.value,
          );
        }),
        const SizedBox(height: 12),
        // Copy all button
        OutlinedButton.icon(
          onPressed: () {
            final text = result.sentences.join('\n• ');
            Clipboard.setData(ClipboardData(text: '• $text'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Summary copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Summary'),
        ),
      ],
    );
  }
}

class _SentenceTile extends StatelessWidget {
  final int index;
  final String sentence;

  const _SentenceTile({required this.index, required this.sentence});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              sentence,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
