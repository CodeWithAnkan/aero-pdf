import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/book.dart';
import '../../core/pdf/indexing_isolate.dart';
import '../ai/ai_provider.dart';
import '../ai/extractive_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global caches (persist across screen navigations within session)
// ─────────────────────────────────────────────────────────────────────────────

/// PDF file bytes cache — avoids re-reading from disk on re-open.
final Map<String, Uint8List> _pdfBytesCache = {};

/// AI summary cache — avoids re-generating on panel re-open.
final Map<int, List<String>> _summaryCache = {};

/// ─────────────────────────────────────────────────────────────────────────────
// Reader Screen
// ─────────────────────────────────────────────────────────────────────────────

class ReaderScreen extends ConsumerStatefulWidget {
  final int bookId;
  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  Book? _book;
  String? _error;
  bool _isLoading = true;
  bool _showUi = true;

  int _currentPage = 0;
  int _initialPageNumber = 1;
  int _totalPages = 1;

  // ValueNotifiers for smooth scroll without rebuilding the whole screen
  final ValueNotifier<double> _scrollPageEstimate = ValueNotifier(0.0);
  final ValueNotifier<double> _pageSweepProgress = ValueNotifier(0.0);

  late final PdfViewerController _pdfController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  // PDF bytes for memory-based loading
  Uint8List? _pdfBytes;

  // ── Search state ──────────────────────────────────────────────────────────
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;

  // ── Custom page indicator animation ───────────────────────────────────────
  late final AnimationController _pageIndicatorAnim;
  Timer? _pageIndicatorHideTimer;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _pageIndicatorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final isar = await IsarService.instance;
      final book = await isar.books.get(widget.bookId);
      if (!mounted) return;

      if (book == null) {
        setState(() {
          _isLoading = false;
          _error = 'Book not found';
        });
        return;
      }

      // Pre-load PDF bytes (from cache or disk)
      Uint8List bytes;
      if (_pdfBytesCache.containsKey(book.filePath)) {
        bytes = _pdfBytesCache[book.filePath]!;
      } else {
        bytes = await File(book.filePath).readAsBytes();
        _pdfBytesCache[book.filePath] = bytes;
      }

      setState(() {
        _book = book;
        _pdfBytes = bytes;
        _currentPage = book.lastReadPage;
        _initialPageNumber = book.lastReadPage + 1;
        _scrollPageEstimate.value = book.lastReadPage.toDouble();
        _isLoading = false;
      });

      // Kick off background indexing if not done yet
      if (!book.isIndexed) {
        final isarDir = await IsarService.directoryPath;
        indexBookInBackground(book.id, book.filePath, isarDir);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveProgress() async {
    final book = _book;
    if (book == null) return;
    try {
      final isar = await IsarService.instance;
      await isar.writeTxn(() async {
        book.lastReadPage = _currentPage;
        book.lastOpened = DateTime.now();
        await isar.books.put(book);
      });
    } catch (_) {}
  }

  // ── Search methods ────────────────────────────────────────────────────────

  void _startSearch() {
    setState(() => _isSearching = true);
    _searchFocusNode.requestFocus();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _searchResult?.clear();
      setState(() => _searchResult = null);
      return;
    }
    final result = _pdfController.searchText(query);
    setState(() => _searchResult = result);
    result.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _closeSearch() {
    _searchResult?.clear();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchResult = null;
    });
  }

  // ── Page indicator ────────────────────────────────────────────────────────

  void _showPageBubble() {
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorAnim.forward();
  }

  void _schedulePageBubbleHide() {
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _pageIndicatorAnim.reverse();
    });
  }

  bool _handlePdfScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _showPageBubble();
    } else if (notification is ScrollEndNotification) {
      _schedulePageBubbleHide();
    }

    if (_totalPages <= 1 ||
        notification.metrics.axis != Axis.vertical ||
        notification.metrics.maxScrollExtent <= 0) {
      return false;
    }

    final rawPage =
        (notification.metrics.pixels / notification.metrics.maxScrollExtent) *
            (_totalPages - 1);
    final pageEstimate = rawPage.clamp(0.0, (_totalPages - 1).toDouble());
    final pageIndex = pageEstimate.round().clamp(0, _totalPages - 1);
    final sweepProgress = pageEstimate - pageEstimate.floorToDouble();

    if ((pageEstimate - _scrollPageEstimate.value).abs() < 0.01 &&
        pageIndex == _currentPage) {
      return false;
    }

    _scrollPageEstimate.value = pageEstimate;
    _pageSweepProgress.value = sweepProgress;

    if (_currentPage != pageIndex) {
      _currentPage = pageIndex;
    }
    _showPageBubble();
    return false;
  }

  Future<void> _openPageJumpDialog() async {
    _showPageBubble();
    _pageIndicatorHideTimer?.cancel();

    final controller =
        TextEditingController(text: _indicatorPageNumber().toString());
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var selectedPage = _indicatorPageNumber().clamp(1, _totalPages);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setPage(int page) {
              selectedPage = page.clamp(1, _totalPages);
              controller.text = selectedPage.toString();
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              setSheetState(() {});
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: selectedPage > 1
                            ? () => setPage(selectedPage - 1)
                            : null,
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        tooltip: 'Previous page',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Page',
                            suffixText: '/ $_totalPages',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final page = int.tryParse(value.trim());
                            if (page == null) return;
                            selectedPage = page.clamp(1, _totalPages);
                            setSheetState(() {});
                          },
                          onSubmitted: (_) {
                            Navigator.of(context).pop(selectedPage);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: selectedPage < _totalPages
                            ? () => setPage(selectedPage + 1)
                            : null,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        tooltip: 'Next page',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Slider(
                    value: selectedPage.toDouble(),
                    min: 1,
                    max: _totalPages.toDouble(),
                    divisions: _totalPages > 1 && _totalPages <= 1000
                        ? _totalPages - 1
                        : null,
                    label: '$selectedPage',
                    onChanged: (value) => setPage(value.round()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '1',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '$_totalPages',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(selectedPage),
                      child: const Text('Go to page'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();

    if (target == null) {
      _schedulePageBubbleHide();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _jumpToPage(target);
    _schedulePageBubbleHide();
  }

  Future<void> _jumpToPage(int target) async {
    final page = target.clamp(1, _totalPages);
    FocusManager.instance.primaryFocus?.unfocus();
    _showPageBubble();
    _pdfController.jumpToPage(page);
    if (!mounted) return;

    _scrollPageEstimate.value = (page - 1).toDouble();
    _pageSweepProgress.value = 0.0;

    _currentPage = page - 1;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final offset = _pdfController.scrollOffset;
    if (offset.dy.isFinite) {
      final nudge = page < _totalPages ? 1.0 : -1.0;
      final nudgedY = (offset.dy + nudge).clamp(0.0, double.maxFinite);
      _pdfController.jumpTo(xOffset: offset.dx, yOffset: nudgedY);
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }

    if (mounted) {
      _pdfController.jumpToPage(page);
    }
  }

  // ── AI Insights ───────────────────────────────────────────────────────────

  void _openInsightsPanel() {
    final book = _book;
    if (book == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CachedInsightsPanel(
        bookId: book.id,
        filePath: book.filePath,
        ref: ref,
      ),
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _pdfController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorAnim.dispose();
    _scrollPageEstimate.dispose();
    _pageSweepProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading ─────────────────────────────────────────────────────────────
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Error ───────────────────────────────────────────────────────────────
    if (_error != null || _book == null || _pdfBytes == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Unknown error',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── PDF Viewer ──────────────────────────────────────────────────────────
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSearching) {
          _closeSearch();
          return;
        }
        if (_showUi) {
          setState(() => _showUi = false);
          return;
        }
        context.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: _isSearching ? _buildSearchLayout() : _buildReaderLayout(),
        ),
      ),
    );
  }

  // ── Search active: Column layout (search bar pushes PDF down) ──────────

  Widget _buildSearchLayout() {
    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(child: _buildPdfViewer()),
      ],
    );
  }

  // ── Normal reading: Stack layout (overlay top bar + page indicator) ────

  Widget _buildReaderLayout() {
    return Stack(
      children: [
        _buildPdfViewer(),

        // Top bar overlay
        if (_showUi)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),

        // Custom smooth page indicator — right side
        Positioned(
          right: 12,
          top: _showUi ? 68 : 16,
          bottom: 16,
          child: AnimatedBuilder(
            animation: _pageIndicatorAnim,
            builder: (context, child) {
              return IgnorePointer(
                ignoring: _pageIndicatorAnim.value == 0,
                child: child,
              );
            },
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollPageEstimate,
              builder: (context, scrollEstimate, _) {
                return Align(
                  alignment: Alignment(
                    1.0,
                    _totalPages <= 1
                        ? -1.0
                        : -1.0 + (2.0 * (scrollEstimate / (_totalPages - 1))),
                  ),
                  child: FadeTransition(
                    opacity: _pageIndicatorAnim,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openPageJumpDialog,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 88),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(scrollEstimate.round().clamp(0, _totalPages - 1)) + 1} / $_totalPages',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 13,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              width: 68,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _pageSweepProgress,
                                builder: (context, sweep, _) {
                                  return LinearProgressIndicator(
                                    value: sweep.clamp(0.0, 1.0),
                                    minHeight: 2,
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // â”€â”€ PDF viewer (loaded from memory bytes for instant re-open) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

        Positioned(
          left: 60,
          right: 60,
          top: 76,
          bottom: 80,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _showUi = !_showUi),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfViewer() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handlePdfScroll,
      child: SfPdfViewer.memory(
        _pdfBytes!,
        key: _pdfViewerKey,
        controller: _pdfController,
        canShowScrollHead: false,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        enableTextSelection: true,
        enableDoubleTapZooming: true,
        initialZoomLevel: 1.0,
        initialPageNumber: _initialPageNumber,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        scrollDirection: PdfScrollDirection.vertical,
        pageSpacing: 2,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
        },
        onPageChanged: (PdfPageChangedDetails details) {
          final newPage = details.newPageNumber - 1;
          _scrollPageEstimate.value = newPage.toDouble();
          _pageSweepProgress.value = 0.0;
          _currentPage = newPage;
          _showPageBubble();
        },
      ),
    );
  }

  int _indicatorPageNumber() {
    final page = _scrollPageEstimate.value.round().clamp(0, _totalPages - 1);
    return page + 1;
  }

  // ── Top bar (normal mode) ─────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Text(
                _book!.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon:
                  const Icon(Icons.auto_awesome_outlined, color: Colors.white),
              tooltip: 'AI Insights',
              onPressed: _openInsightsPanel,
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              tooltip: 'Search in PDF',
              onPressed: _startSearch,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar (Google Drive style) ───────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    final result = _searchResult;
    final hasResults = result != null && result.totalInstanceCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _closeSearch,
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search in PDF…',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixText: hasResults
                      ? '${result.currentInstanceIndex} / ${result.totalInstanceCount}'
                      : null,
                  suffixStyle: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
            ),
            if (hasResults) ...[
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                tooltip: 'Previous match',
                onPressed: () => result.previousInstance(),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                tooltip: 'Next match',
                onPressed: () => result.nextInstance(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cached AI Insights Panel — full PDF summary, generated once
// ─────────────────────────────────────────────────────────────────────────────

class _CachedInsightsPanel extends ConsumerStatefulWidget {
  final int bookId;
  final String filePath;
  final WidgetRef ref;

  const _CachedInsightsPanel({
    required this.bookId,
    required this.filePath,
    required this.ref,
  });

  @override
  ConsumerState<_CachedInsightsPanel> createState() =>
      _CachedInsightsPanelState();
}

class _CachedInsightsPanelState extends ConsumerState<_CachedInsightsPanel> {
  List<String>? _sentences;
  bool _loading = false;
  String? _error;
  String _engineName = '';

  @override
  void initState() {
    super.initState();
    if (_summaryCache.containsKey(widget.bookId)) {
      _sentences = _summaryCache[widget.bookId];
    }
  }

  Future<void> _generateSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Use cached bytes if available, else read from disk
      Uint8List bytes;
      if (_pdfBytesCache.containsKey(widget.filePath)) {
        bytes = _pdfBytesCache[widget.filePath]!;
      } else {
        bytes = await File(widget.filePath).readAsBytes();
      }

      final pdfDoc = sf_pdf.PdfDocument(inputBytes: bytes);
      final extractor = sf_pdf.PdfTextExtractor(pdfDoc);
      final pages = <PageText>[];

      for (int i = 0; i < pdfDoc.pages.count; i++) {
        try {
          final text =
              extractor.extractText(startPageIndex: i, endPageIndex: i);
          pages.add(PageText(pageNumber: i, text: text));
        } catch (_) {
          pages.add(PageText(pageNumber: i, text: ''));
        }
      }
      pdfDoc.dispose();

      if (pages.isEmpty || pages.every((p) => p.text.trim().isEmpty)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No text found in this PDF.';
        });
        return;
      }

      final engine = await ref.read(aiEngineProvider.future);
      _engineName = engine.engineName;

      final result = await engine.summarizeChapter(
        pages: pages,
        allPages: pages,
      );

      _summaryCache[widget.bookId] = result.sentences;

      if (!mounted) return;
      setState(() {
        _sentences = result.sentences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              // Drag handle
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
              // Header
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (_engineName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _engineName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Full document summary',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const Divider(height: 24),

              // Not generated yet
              if (_sentences == null && !_loading && _error == null) ...[
                const SizedBox(height: 20),
                Center(
                  child: FilledButton.icon(
                    onPressed: _generateSummary,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generate Summary'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Uses on-device AI. No data leaves your phone.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ],

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating summary…',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _generateSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              if (_sentences != null)
                ..._sentences!.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 1, right: 12),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Copy button
              if (_sentences != null && _sentences!.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    final text = _sentences!
                        .asMap()
                        .entries
                        .map((e) => '${e.key + 1}. ${e.value}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Summary copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Summary'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
