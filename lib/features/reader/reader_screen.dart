import 'dart:async';
import 'dart:io';

import 'package:aeropdf/core/models/search_index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/book.dart';
import '../../core/pdf/indexing_isolate.dart';
import '../ai/ai_provider.dart';
import '../ai/extractive_engine.dart';
import '../ocr/ocr_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global caches
// ─────────────────────────────────────────────────────────────────────────────

final Map<String, Uint8List> _pdfBytesCache = {};
final Map<int, List<String>> _summaryCache = {};

// ─────────────────────────────────────────────────────────────────────────────
// Reader Screen
// ─────────────────────────────────────────────────────────────────────────────

class ReaderScreen extends ConsumerStatefulWidget {
  final int bookId;
  final int initialPage;
  const ReaderScreen({super.key, required this.bookId, this.initialPage = 0});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Book? _book;
  String? _error;
  bool _isLoading = true;
  bool _showUi = true;
  bool _viewerPadded = true;
  bool _hasSelection = false;

  static const _barAnimDuration = Duration(milliseconds: 220);

  void _setShowUi(bool visible) {
    if (visible) {
      setState(() { _showUi = true; _viewerPadded = true; });
    } else {
      setState(() => _showUi = false);
      Future.delayed(_barAnimDuration, () {
        if (mounted && !_showUi) setState(() => _viewerPadded = false);
      });
    }
    _setSystemUi(visible);
  }

  // ── System UI ──────────────────────────────────────────────────────────────
  void _setSystemUi(bool visible) {
    if (visible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  int _currentPage = 0;
  int _initialPageNumber = 1;
  int _totalPages = 1;

  late final PdfViewerController _pdfController;
  late final UndoHistoryController _undoController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  // ── Scroll & Indicator State ──
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0.0);
  double _maxScrollExtent = 0.0;

  // ── Search state ──
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _undoController = UndoHistoryController();
    _setSystemUi(true);
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
        _currentPage =
            widget.initialPage > 0 ? widget.initialPage : book.lastReadPage;
        _initialPageNumber = _currentPage + 1;
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
        if (_currentPage > book.lastReadPage) {
          book.lastReadPage = _currentPage;
        }
        book.lastOpened = DateTime.now();
        await isar.books.put(book);
      });
    } catch (_) {}
  }

  // ── Scroll & Scrubber Logic ──────────────────────────────────────────────

  bool _handlePdfScroll(ScrollNotification notification) {
    if (_totalPages <= 1 ||
        notification.metrics.axis != Axis.vertical ||
        notification.metrics.maxScrollExtent <= 0) {
      return false;
    }

    _maxScrollExtent = notification.metrics.maxScrollExtent;
    final pixels = notification.metrics.pixels;
    final viewportHeight = notification.metrics.viewportDimension;
    _scrollProgress.value = (pixels / _maxScrollExtent).clamp(0.0, 1.0);

    final totalHeight = _maxScrollExtent + viewportHeight;
    final pageHeight = totalHeight / _totalPages;

    int detectedPage = 0;
    for (int i = 0; i < _totalPages; i++) {
      final bottomEdge = (i + 1) * pageHeight;
      final distFromTop = bottomEdge - pixels;
      final ratio = distFromTop / viewportHeight;
      if (ratio <= 0.60) {
        detectedPage = i + 1;
      } else {
        break;
      }
    }

    detectedPage = detectedPage.clamp(0, _totalPages - 1);

    if (detectedPage != _currentPage) {
      setState(() {
        _currentPage = detectedPage;
      });
      _checkAndTriggerOcr(detectedPage);
      _saveProgress();
    }
    return false;
  }

  void _onScrub(double value) {
    _scrollProgress.value = value;
    if (_maxScrollExtent > 0) {
      _pdfController.jumpTo(yOffset: value * _maxScrollExtent);
    } else {
      final targetPage = (value * (_totalPages - 1)).round() + 1;
      _pdfController.jumpToPage(targetPage);
    }
  }

  void _onScrubEnd(double value) {
    HapticFeedback.lightImpact();
  }

  // ── Search & Insights ───────────────────────────────────────────────────

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
    result.addListener(() {
      if (mounted) setState(() => _searchResult = result);
    });
    setState(() => _searchResult = result);
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
    _setSystemUi(true); // always restore on exit
    _saveProgress();
    _pdfController.dispose();
    _undoController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgLight = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isLoading
            ? Center(
                key: const ValueKey('loading'),
                child: CircularProgressIndicator(color: cs.onSurface),
              )
            : _error != null || _book == null
                ? Center(
                    key: const ValueKey('error'),
                    child: Text(
                      _error ?? 'Unknown error',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  )
                : PopScope(
                    key: const ValueKey('content'),
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) {
                      if (didPop) return;
                      if (_isSearching) {
                        _closeSearch();
                        return;
                      }
                      if (_hasSelection) {
                        _pdfController.clearSelection();
                        return;
                      }
                      context.pop();
                    },
                    child: _isSearching
                        ? _buildSearchLayout(cs, bgLight)
                        : _buildReaderLayout(cs, bgLight),
                  ),
      ),
    );
  }

  void onPageChanged(int pageIndex) async {
    _currentPage = pageIndex;

    if (_totalPages > 1) {
      _scrollProgress.value = _currentPage / (_totalPages - 1);
    }

    _checkAndTriggerOcr(pageIndex);
  }

  Future<void> _checkAndTriggerOcr(int pageIndex) async {
    final isar = await IsarService.instance;

    final indexEntry = await isar.searchIndexs
        .filter()
        .bookIdEqualTo(widget.bookId)
        .pageNumberEqualTo(pageIndex)
        .findFirst();

    if (indexEntry != null && indexEntry.isOcr) {
      ref.read(ocrControllerProvider.notifier).processPageIfNeeded(
            bookId: widget.bookId,
            pageNumber: pageIndex,
            filePath: _book!.filePath,
          );
    }
  }

  Future<void> _saveAnnotations() async {
    try {
      // Extract the PDF bytes with annotations baked in
      final List<int> bytes = await _pdfController.saveDocument();
      
      // Overwrite the original file in storage
      final file = File(_book!.filePath);
      await file.writeAsBytes(bytes, flush: true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Annotations saved to file'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Widget _buildPdfViewer() {
    return SfPdfViewerTheme(
      data: SfPdfViewerThemeData(
        backgroundColor: Colors.black,
      ),
      child: SfPdfViewer.file(
        File(_book!.filePath),
        key: _pdfViewerKey,
        controller: _pdfController,
      undoController: _undoController,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      canShowPaginationDialog: false,
      enableTextSelection: true,
      enableDoubleTapZooming: true,
      onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
        if (details.selectedText != null) {
          HapticFeedback.lightImpact();
        }
        setState(() {
          _hasSelection = details.selectedText != null;
        });
      },
      initialPageNumber: _initialPageNumber.clamp(1, 999999),
      pageLayoutMode: PdfPageLayoutMode.continuous,
      scrollDirection: PdfScrollDirection.vertical,
      pageSpacing: 4,
      onDocumentLoaded: (details) {
        setState(() => _totalPages = _pdfController.pageCount);
        if (_pdfController.pageCount == 1) {
          _saveProgress();
        }
      },
      onPageChanged: (details) {
        final newIdx = details.newPageNumber - 1;
        setState(() {
          _currentPage = newIdx;
        });
        if (_totalPages > 1) {
          _scrollProgress.value = _currentPage / (_totalPages - 1);
        }
        _checkAndTriggerOcr(newIdx);
        _saveProgress();
      },
    ),
  );
}

  Widget _buildSearchLayout(ColorScheme cs, Color bgLight) {
    return SafeArea(
      child: Column(
        children: [
          _buildSearchBar(context, cs, bgLight),
          Expanded(child: _buildPdfViewer()),
        ],
      ),
    );
  }

  Widget _buildReaderLayout(ColorScheme cs, Color bgLight) {
    final topBarHeight = MediaQuery.of(context).padding.top + 64.0;
    final bottomBarHeight = MediaQuery.of(context).padding.bottom + 80.0;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            top: _viewerPadded ? topBarHeight : 0,
            bottom: _viewerPadded ? bottomBarHeight : 0,
            left: 0,
            right: 0,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handlePdfScroll,
              child: _buildPdfViewer(),
            ),
          ),

          // Transparent tap overlay — sits above viewer, below bars.
          // Only covers the middle strip so text selection near edges still works.
          // GestureDetector with only onTap does NOT consume scroll/drag events,
          // so scrolling the PDF passes through freely.
          Positioned(
            top: topBarHeight + 60,
            bottom: bottomBarHeight + 60,
            left: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_hasSelection) {
                  _pdfController.clearSelection();
                } else {
                  _setShowUi(!_showUi);
                }
                HapticFeedback.selectionClick();
              },
            ),
          ),

          // Top bar slides up off-screen when hidden
          AnimatedPositioned(
            duration: _barAnimDuration,
            curve: Curves.easeInOut,
            top: _showUi ? 0 : -300,
            left: 0,
            right: 0,
            child: Container(
              color: bgLight,
              child: SafeArea(bottom: false, child: _buildTopBar(cs, bgLight)),
            ),
          ),

          // Bottom bar slides down off-screen when hidden
          AnimatedPositioned(
            duration: _barAnimDuration,
            curve: Curves.easeInOut,
            bottom: _showUi ? 0 : -300,
            left: 0,
            right: 0,
            child: Container(
              color: bgLight,
              child: SafeArea(top: false, child: _buildBottomBar(cs, bgLight)),
            ),
          ),

          _buildOcrIndicator(cs),
        ],
      ),
    );
  }

  Widget _buildOcrIndicator(ColorScheme cs) {
    return Consumer(
      builder: (context, ref, _) {
        final ocrState = ref.watch(ocrControllerProvider);
        return ocrState.maybeWhen(
          loading: () => Positioned(
            top: 80,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'OCR ACTIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildTopBar(ColorScheme cs, Color bgLight) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: bgLight,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
              onPressed: () => context.pop()),
          Expanded(
            child: Text(
              _book!.title,
              style: GoogleFonts.archivo(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _undoController,
            builder: (context, undoValue, _) {
              final hasEdits = undoValue.canUndo;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasEdits) ...[
                    IconButton(
                      icon: Icon(Icons.undo_rounded,
                          color: undoValue.canUndo ? cs.onSurface : cs.onSurfaceVariant.withOpacity(0.4), size: 20),
                      onPressed: undoValue.canUndo ? () => _undoController.undo() : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.save_rounded,
                          color: cs.onSurface, size: 20),
                      onPressed: _saveAnnotations,
                    ),
                  ],
                ],
              );
            },
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: cs.onSurface),
                    const SizedBox(width: 12),
                    const Text('Search Document'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: cs.onSurface),
                    const SizedBox(width: 12),
                    const Text('AI Insights'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 1) {
                _startSearch();
              } else if (value == 2) {
                _openInsightsPanel();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme cs, Color bgLight) {
    return Container(
      decoration: BoxDecoration(
        color: bgLight,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _scrollProgress,
            builder: (context, progress, _) {
              final displayPage = (progress * (_totalPages - 1)).round() + 1;
              final percent = (progress * 100).toInt();
              final style = GoogleFonts.archivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.2);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PG. $displayPage', style: style),
                  Text('$percent%', style: style.copyWith(color: cs.onSurface)),
                  Text('$_totalPages PAGES', style: style),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: _scrollProgress,
            builder: (context, progress, child) {
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  activeTrackColor: cs.onSurface,
                  inactiveTrackColor: cs.outlineVariant,
                  thumbColor: cs.onSurface,
                  overlayColor: cs.onSurface.withValues(alpha: 0.1),
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6, elevation: 0),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                  trackShape: const RectangularSliderTrackShape(),
                ),
                child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: _onScrub,
                    onChangeEnd: _onScrubEnd),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ColorScheme cs, Color bgLight) {
    final result = _searchResult;
    final hasResults = result != null && result.totalInstanceCount > 0;

    return Container(
      decoration: BoxDecoration(
          color: bgLight,
          border:
              Border(bottom: BorderSide(color: cs.outlineVariant, width: 1))),
      height: 64,
      child: Row(
        children: [
          IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
              onPressed: _closeSearch),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: GoogleFonts.archivo(color: cs.onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.archivo(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixText: hasResults
                    ? '${result.currentInstanceIndex} / ${result.totalInstanceCount}'
                    : null,
                suffixStyle: GoogleFonts.archivo(
                    fontSize: 13, color: cs.onSurfaceVariant),
              ),
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (hasResults) ...[
            IconButton(
                icon:
                    Icon(Icons.keyboard_arrow_up_rounded, color: cs.onSurface),
                onPressed: () => result.previousInstance()),
            IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurface),
                onPressed: () => result.nextInstance()),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cached AI Insights Panel (Unchanged internally, minimal UI tweaks)
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
          _error = 'No text found in this document.';
        });
        return;
      }

      final engine = await ref.read(aiEngineProvider.future);
      _engineName = engine.engineName;

      final result =
          await engine.summarizeChapter(pages: pages, allPages: pages);
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
    const textMain = Color(0xFF121212);
    const muted = Color(0xFF8E8D8A);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E4E0),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 20, color: textMain),
                  const SizedBox(width: 8),
                  Text(
                    'AI Summary',
                    style: GoogleFonts.archivo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textMain),
                  ),
                  const Spacer(),
                  if (_engineName.isNotEmpty)
                    Text(
                      _engineName,
                      style: GoogleFonts.archivo(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 0.5),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (_sentences == null && !_loading && _error == null) ...[
                OutlinedButton.icon(
                  onPressed: _generateSummary,
                  icon: const Icon(Icons.bolt_rounded, color: textMain),
                  label: Text('Generate',
                      style: GoogleFonts.archivo(
                          color: textMain, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: textMain),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Processed entirely on-device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.archivo(fontSize: 12, color: muted),
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child:
                      Center(child: CircularProgressIndicator(color: textMain)),
                ),
              if (_error != null)
                Text(_error!,
                    style: GoogleFonts.archivo(color: Colors.red.shade600),
                    textAlign: TextAlign.center),
              if (_sentences != null)
                ..._sentences!.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${entry.key + 1}. ${entry.value}',
                      style: GoogleFonts.newsreader(
                          fontSize: 18, color: textMain, height: 1.5),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}