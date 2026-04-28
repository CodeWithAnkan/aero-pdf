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

  late final PdfViewerController _pdfController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  // ── Scroll & Indicator State ──────────────────────────────────────────────
  final ValueNotifier<double> _scrollPageEstimate = ValueNotifier(0.0);
  late final AnimationController _pageIndicatorAnim;
  Timer? _pageIndicatorHideTimer;
  int _lastDraggedPage = -1;
  double _maxScrollExtent = 0.0; // Stores the physical pixel height of the PDF

  // ── Search state ──────────────────────────────────────────────────────────
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _pageIndicatorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
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

      setState(() {
        _book = book;
        _currentPage = book.lastReadPage;
        _initialPageNumber = book.lastReadPage + 1;
        _scrollPageEstimate.value = book.lastReadPage.toDouble();
        _isLoading = false;
      });

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

  // ── Scroll Indicator Logic ────────────────────────────────────────────────

  void _showPageBubble() {
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorAnim.forward();
  }

  void _schedulePageBubbleHide() {
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorHideTimer = Timer(const Duration(seconds: 2), () {
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

    // Capture the maximum scroll pixels for buttery smooth thumb dragging
    _maxScrollExtent = notification.metrics.maxScrollExtent;

    // Map raw scroll pixels to page estimate
    final rawPage = (notification.metrics.pixels / _maxScrollExtent) * (_totalPages - 1);
    final pageEstimate = rawPage.clamp(0.0, (_totalPages - 1).toDouble());

    _scrollPageEstimate.value = pageEstimate;
    _showPageBubble();
    return false;
  }

  void _handleThumbDrag(double localY, double maxHeight) {
    if (_totalPages <= 1) return;
    const bubbleHeight = 28.0; // Smaller height
    
    // Calculate progress (0.0 to 1.0) based on thumb position
    final progress = (localY - (bubbleHeight / 2)) / (maxHeight - bubbleHeight);
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    // Snap visual indicator immediately
    _scrollPageEstimate.value = clampedProgress * (_totalPages - 1);
    
    // Smooth pixel scrolling (if extent is known), fallback to jumpToPage if not scrolled yet
    final targetPage = (clampedProgress * (_totalPages - 1)).round() + 1;
    
    if (_maxScrollExtent > 0) {
      final targetYOffset = clampedProgress * _maxScrollExtent;
      _pdfController.jumpTo(yOffset: targetYOffset);
    } else {
      _pdfController.jumpToPage(targetPage);
    }
    
    // Only trigger physical haptics when crossing a whole page boundary
    if (targetPage != _lastDraggedPage) {
      _lastDraggedPage = targetPage;
      HapticFeedback.selectionClick(); 
    }
  }
  // ── Search & Insights Methods ─────────────────────────────────────────────

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
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _book == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop()),
        ),
        body: Center(
            child: Text(_error ?? 'Unknown error',
                style: const TextStyle(color: Colors.white70))),
      );
    }

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

  Widget _buildSearchLayout() {
    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(child: _buildPdfViewer()),
      ],
    );
  }

  Widget _buildReaderLayout() {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handlePdfScroll,
          child: _buildPdfViewer(),
        ),

        // UI toggler tap zone (center of screen)
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

        // Top bar overlay
        if (_showUi)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),

        // ── Adobe-style Draggable Scroll Thumb ─────────────────────────────────
        // ── Adobe-style Draggable Scroll Thumb ─────────────────────────────────
        Positioned(
          right: 0, 
          top: _showUi ? 60 : 16, 
          bottom: 16,
          width: 60, // Invisible hit-box width for easy grabbing
          child: AnimatedBuilder(
            animation: _pageIndicatorAnim,
            builder: (context, child) {
              return IgnorePointer(
                ignoring: _pageIndicatorAnim.value == 0,
                child: Opacity(
                  opacity: _pageIndicatorAnim.value,
                  child: child,
                ),
              );
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  // behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (details) {
                    _pageIndicatorHideTimer?.cancel();
                    _showPageBubble();
                    _handleThumbDrag(details.localPosition.dy, constraints.maxHeight);
                  },
                  onVerticalDragUpdate: (details) {
                    _handleThumbDrag(details.localPosition.dy, constraints.maxHeight);
                  },
                  onVerticalDragEnd: (_) {
                    _lastDraggedPage = -1;
                    _schedulePageBubbleHide();
                  },
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollPageEstimate,
                    builder: (context, scrollEstimate, _) {
                      final progress = _totalPages <= 1
                          ? 0.0
                          : (scrollEstimate / (_totalPages - 1)).clamp(0.0, 1.0);

                      const bubbleHeight = 28.0;
                      // Dynamic Y position
                      final topOffset = progress * (constraints.maxHeight - bubbleHeight);

                      return Stack(
                        children: [
                          Positioned(
                            top: topOffset,
                            right: 0, // Flush completely to the edge
                            child: Container(
                              height: bubbleHeight,
                              padding: const EdgeInsets.only(left: 12, right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A), 
                                // Flush right side, rounded left side (Adobe Style)
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(-2, 1),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${scrollEstimate.round() + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12, // Lowered size
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    ' / $_totalPages',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11, // Lowered size
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      File(_book!.filePath),
      key: _pdfViewerKey,
      controller: _pdfController,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      canShowPaginationDialog: false,
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
        _currentPage = details.newPageNumber - 1;
        _scrollPageEstimate.value = _currentPage.toDouble();
        _showPageBubble();
        _schedulePageBubbleHide();
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.1), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  _book!.title,
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome_outlined),
                tooltip: 'AI Insights',
                onPressed: _openInsightsPanel,
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search in PDF',
                onPressed: _startSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final result = _searchResult;
    final hasResults = result != null && result.totalInstanceCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.1), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
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
