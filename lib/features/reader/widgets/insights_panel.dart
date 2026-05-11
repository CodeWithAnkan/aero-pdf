import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';

import '../../../core/db/isar_service.dart';
import '../../../core/models/search_index.dart';
import '../../ai/ai_provider.dart';
import '../../ai/ai_engine.dart';

class InsightsPanel extends ConsumerStatefulWidget {
  final int bookId;
  final String filePath;
  final int currentPage;

  const InsightsPanel({
    super.key,
    required this.bookId,
    required this.filePath,
    required this.currentPage,
  });

  @override
  ConsumerState<InsightsPanel> createState() => _InsightsPanelState();
}

class _InsightsPanelState extends ConsumerState<InsightsPanel> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(insightsProvider.notifier).checkCache(widget.bookId);
    });
  }

  @override
  void dispose() {
    ref.read(insightsProvider.notifier).cancelFullAnalysisOnly();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    final notifier = ref.read(insightsProvider.notifier);
    final engine = await ref.read(aiEngineProvider.future);
    final isar = await IsarService.instance;

    // 1. Get Text for analysis
    final indexEntries = await isar.searchIndexs
        .filter()
        .bookIdEqualTo(widget.bookId)
        .sortByPageNumber()
        .findAll();

    if (indexEntries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document not yet indexed. Please wait a few seconds.')),
        );
      }
      return;
    }

    final allPages = indexEntries
        .map((e) => PageText(pageNumber: e.pageNumber, text: e.pageText))
        .toList();

    final currentPageText = allPages.firstWhere(
      (p) => p.pageNumber == widget.currentPage,
      orElse: () => allPages.first,
    );

    await notifier.generate(
      bookId: widget.bookId,
      engine: engine,
      currentPage: currentPageText,
      allPages: allPages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider);
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 22, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      'AI Insights',
                      style: GoogleFonts.archivo(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (state.result.hasValue && state.result.value != null)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: state.isProcessingGlobal ? null : () async {
                          final isar = await IsarService.instance;
                          ref.read(insightsProvider.notifier).clear(isar, widget.bookId);
                        },
                        tooltip: 'Regenerate Summary',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (state.isProcessingGlobal) ...[
                _buildThinkingLog(state),
                const Divider(height: 32),
              ],
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    if (state.result.value == null && !state.isProcessingGlobal) ...[
                      const SizedBox(height: 40),
                      Icon(Icons.description_outlined, size: 48, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Generate deep insights for this document.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.archivo(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: state.isProcessingGlobal ? null : _generateSummary,
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text('Analyze Full Book'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                    if (state.result.hasValue && state.result.value != null)
                      Column(
                        children: [
                          _buildSummaryContent(state.result.value!),
                          if (state.result.value!.mode != SummaryMode.global && !state.isProcessingGlobal) ...[
                            const SizedBox(height: 32),
                            OutlinedButton.icon(
                              onPressed: _generateSummary,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text('Complete Full Book Analysis'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      state.result.when(
                        data: (_) => const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (err, _) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingLog(InsightsState state) {
    if (!state.isProcessingGlobal) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            state.progressLabel != null 
                ? 'AI is thinking... (${state.progressLabel})'
                : 'AI is thinking...',
            style: GoogleFonts.archivo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(SummaryResult result) {
    final cs = Theme.of(context).colorScheme;
    final isGlobal = result.mode == SummaryMode.global;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isGlobal ? cs.primaryContainer : cs.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isGlobal ? 'FULL BOOK SUMMARY' : 'QUICK INSIGHTS',
                style: GoogleFonts.archivo(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isGlobal ? cs.onPrimaryContainer : cs.onSecondaryContainer,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'On-Device AI',
              style: GoogleFonts.archivo(fontSize: 10, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...result.sentences.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: GoogleFonts.newsreader(fontSize: 20, height: 1.2)),
              Expanded(
                child: Text(
                  s,
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
