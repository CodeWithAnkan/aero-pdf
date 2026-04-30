import 'dart:async';
import 'dart:io';

import 'package:aeropdf/core/models/search_index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/book.dart';
import '../../core/pdf/indexing_isolate.dart';
import '../ai/ai_provider.dart';
import '../ai/ai_engine.dart';
import '../ai/model_manager.dart';
import '../ocr/ocr_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global caches
// ─────────────────────────────────────────────────────────────────────────────

final Map<String, Uint8List> _pdfBytesCache = {};

/// Called by LibraryScreen on tap — before the route transition starts.
/// Reads the file on a separate isolate via [compute] so it never competes
/// with the main thread during the fade transition animation.
void warmUpPdfBytes(String filePath) {
  if (_pdfBytesCache.containsKey(filePath)) return; // already warm
  // ignore: unawaited_futures
  compute(_readFileBytes, filePath).then((bytes) {
    _pdfBytesCache[filePath] = bytes;
  }).ignore(); // silently discard errors; _loadBook will fall back to .file
}

// Top-level function required by compute() — must not be a closure or method.
Future<Uint8List> _readFileBytes(String path) => File(path).readAsBytes();

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

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  Book? _book;
  Uint8List?
      _pdfBytes; // pre-loaded bytes — avoids file I/O on every page render
  String? _error;
  bool _isLoading = true;
  bool _showUi = true;
  bool _hasSelection = false;
  bool _isViewerReady = false; // true once onDocumentLoaded fires

  static const _barAnimDuration = Duration(milliseconds: 220);

  void _setShowUi(bool visible) {
    setState(() => _showUi = visible);
    _setSystemUi(visible);
  }

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
  double _initialZoom = 1.0;
  PdfPageLayoutMode _layoutMode = PdfPageLayoutMode.continuous;

  late final PdfViewerController _pdfController;
  late final UndoHistoryController _undoController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  // ── Scroll & Indicator State ──
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0.0);

  // ── Search state ──
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;

  // ── Scroll debounce — prevents Isar queries on every scroll tick ──
  Timer? _scrollDebounce;

  // ── OCR debounce — prevents firing on transient page changes ──
  Timer? _ocrDebounce;
  int? _lastOcrCheckedPage;

  // ── Loading progress bar ──
  late final AnimationController _loadProgressController;
  late final Animation<double> _loadProgressAnim;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _undoController = UndoHistoryController();
    _setSystemUi(true);

    // Animate 0 → 0.82 over 2 s — covers Isar + file read on any device.
    // The progress bar is manually advanced in 3 stages:
    // 50% (Isar check), 80% (Byte loading), 100% (Ready)
    _loadProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadProgressAnim = CurvedAnimation(
      parent: _loadProgressController,
      curve: Curves.easeOut,
    );

    _loadBook();
  }

  // Animates the bar to a specific percentage.
  Future<void> _updateLoadProgress(double value) async {
    await _loadProgressController.animateTo(
      value,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
    );
  }

  // Called when _loadBook finishes — snaps bar to 100% then switches view.
  Future<void> _finishLoadBar() async {
    await _updateLoadProgress(1.0);
  }

  Future<void> _loadBook() async {
    try {
      final isar = await IsarService.instance;
      final book = await isar.books.get(widget.bookId);
      if (!mounted) return;

      await _updateLoadProgress(0.5); // Stage 1: Book info loaded

      if (book == null) {
        setState(() {
          _isLoading = false;
          _error = 'Book not found';
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final zoomStr = prefs.getString('defaultZoom') ?? 'Fit Page';
      double zoomVal = 1.0;
      PdfPageLayoutMode layoutVal = PdfPageLayoutMode.continuous;

      if (zoomStr == '150%') {
        zoomVal = 1.5;
      } else if (zoomStr == 'Fit Page') {
        layoutVal = PdfPageLayoutMode.single;
      }

      final exitPage =
          prefs.getInt('exit_page_${book.id}') ?? book.lastReadPage;

      // Pre-load PDF bytes for SfPdfViewer.memory when the file is small enough.
      // Under 80 MB: load into RAM → zero file I/O per page during scrolling.
      // 80 MB and above: leave _pdfBytes null → fall back to SfPdfViewer.file
      // to avoid spiking memory on low-end devices.
      const int memoryThreshold = 80 * 1024 * 1024; // 80 MB
      Uint8List? bytes;
      final fileSize = await File(book.filePath).length();
      if (fileSize < memoryThreshold) {
        if (_pdfBytesCache.containsKey(book.filePath)) {
          bytes = _pdfBytesCache[book.filePath]!;
        } else {
          // Read on a separate isolate — keeps the main thread free so the
          // fade-in transition animation runs at full 60fps while bytes load.
          final loaded = await compute(_readFileBytes, book.filePath);
          _pdfBytesCache[book.filePath] = loaded;
          bytes = loaded;
        }
      }

      if (!mounted) return;

      await _updateLoadProgress(
          0.8); // Stage 2: Bytes ready / file access confirmed

      await _finishLoadBar(); // Stage 3: 100% progress

      if (!mounted) return;

      setState(() {
        _book = book;
        _pdfBytes = bytes; // null for large files → viewer uses .file fallback
        _initialZoom = zoomVal;
        _layoutMode = layoutVal;
        _currentPage = widget.initialPage > 0 ? widget.initialPage : exitPage;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('exit_page_${book.id}', _currentPage);

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

    final pixels = notification.metrics.pixels;
    final maxExtent = notification.metrics.maxScrollExtent;
    final viewportHeight = notification.metrics.viewportDimension;

    // Update the scrubber ValueNotifier directly — no setState needed here,
    // so the PDF widget tree is never rebuilt during scroll.
    _scrollProgress.value = (pixels / maxExtent).clamp(0.0, 1.0);

    // Debounce the heavy work: page detection + OCR trigger + progress save.
    // This fires at most once per 120 ms instead of every scroll frame.
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;

      final totalHeight = maxExtent + viewportHeight;
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
        setState(() => _currentPage = detectedPage);
        _scheduleOcrCheck(detectedPage);
        _saveProgress();
      }
    });

    return false;
  }

  void _onScrub(double value) {
    _scrollProgress.value = value;
    if (_totalPages > 1) {
      final targetPage =
          ((value * (_totalPages - 1)).round() + 1);
      _pdfController.jumpToPage(targetPage);
    }
  }

  void _onScrubEnd(double value) {
    HapticFeedback.lightImpact();
  }

  // ── OCR check — deduplicated and debounced ──────────────────────────────

  void _scheduleOcrCheck(int pageIndex) {
    // Don't re-check a page we already checked in this session
    if (_lastOcrCheckedPage == pageIndex) return;

    _ocrDebounce?.cancel();
    _ocrDebounce = Timer(const Duration(milliseconds: 300), () {
      _checkAndTriggerOcr(pageIndex);
    });
  }

  Future<void> _checkAndTriggerOcr(int pageIndex) async {
    if (_lastOcrCheckedPage == pageIndex) return;
    _lastOcrCheckedPage = pageIndex;

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
        currentPage: _pdfController.pageNumber,
      ),
    );
  }

  @override
  void dispose() {
    _setSystemUi(true);
    _saveProgress();
    _scrollDebounce?.cancel();
    _ocrDebounce?.cancel();
    _loadProgressController.dispose();
    _pdfController.dispose();
    _undoController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  // ── Loading screen ───────────────────────────────────────────────────────

  Widget _buildLoadingScreen(ColorScheme cs, Color bgLight) {
    return Container(
      key: const ValueKey('loading'),
      color: bgLight,
      child: SafeArea(
        child: Column(
          children: [
            // ── Thin progress bar at the very top ─────────────────────────
            AnimatedBuilder(
              animation: _loadProgressAnim,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: _loadProgressAnim.value,
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                );
              },
            ),
            const Spacer(),
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 48,
              color: cs.onSurface.withOpacity(0.15),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgLight = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgLight,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isLoading
            ? _buildLoadingScreen(cs, bgLight)
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

  // ── PDF Viewer ────────────────────────────────────────────────────────────
  //
  // Key performance decisions:
  //   • SfPdfViewer.memory — bytes are pre-loaded in _loadBook into _pdfBytes
  //     (and the global _pdfBytesCache). The renderer reads from RAM instead of
  //     hitting the filesystem on every page decode. This is the primary fix
  //     for scroll lag on large PDFs.
  //   • No artificial delay — the viewer starts rendering as soon as _loadBook
  //     completes.
  //   • The widget is kept alive in a Positioned.fill so bar show/hide never
  //     triggers a rebuild or resize of the viewer.

  Widget _buildPdfViewer(Color bgLight) {
    void onTextSel(PdfTextSelectionChangedDetails d) {
      if (d.selectedText != null) HapticFeedback.lightImpact();
      setState(() => _hasSelection = d.selectedText != null);
    }

    void onDocLoaded(PdfDocumentLoadedDetails d) {
      setState(() {
        _totalPages = _pdfController.pageCount;
        _isViewerReady = true; // lifts the splash cover
      });
      if (_totalPages > 1) {
        _scrollProgress.value = _currentPage / (_totalPages - 1);
      }
      if (_pdfController.pageCount == 1) _saveProgress();
    }

    void onPageChanged(PdfPageChangedDetails d) {
      final newIdx = d.newPageNumber - 1;
      setState(() => _currentPage = newIdx);
      if (_totalPages > 1) {
        _scrollProgress.value = _currentPage / (_totalPages - 1);
      }
      _scheduleOcrCheck(newIdx);
      _saveProgress();
    }

    final scrollDir = _layoutMode == PdfPageLayoutMode.single
        ? PdfScrollDirection.horizontal
        : PdfScrollDirection.vertical;

    final Widget viewer = _pdfBytes != null
        // ── Fast path: whole PDF in RAM, zero disk I/O per page ──────────
        ? SfPdfViewer.memory(
            _pdfBytes!,
            key: _pdfViewerKey,
            controller: _pdfController,
            undoController: _undoController,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            canShowPaginationDialog: false,
            canShowPageLoadingIndicator: false,
            enableTextSelection: true,
            enableDoubleTapZooming: true,
            enableDocumentLinkAnnotation: false,
            initialPageNumber: _initialPageNumber,
            initialZoomLevel: _initialZoom,
            pageLayoutMode: _layoutMode,
            scrollDirection: scrollDir,
            pageSpacing: 4,
            onTextSelectionChanged: onTextSel,
            onDocumentLoaded: onDocLoaded,
            onPageChanged: onPageChanged,
          )
        // ── Large-file fallback: stream from disk ─────────────────────────
        : SfPdfViewer.file(
            File(_book!.filePath),
            key: _pdfViewerKey,
            controller: _pdfController,
            undoController: _undoController,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            canShowPaginationDialog: false,
            canShowPageLoadingIndicator: false,
            enableTextSelection: true,
            enableDoubleTapZooming: true,
            enableDocumentLinkAnnotation: false,
            initialPageNumber: _initialPageNumber,
            initialZoomLevel: _initialZoom,
            pageLayoutMode: _layoutMode,
            scrollDirection: scrollDir,
            pageSpacing: 4,
            onTextSelectionChanged: onTextSel,
            onDocumentLoaded: onDocLoaded,
            onPageChanged: onPageChanged,
          );

    return SfPdfViewerTheme(
      data: SfPdfViewerThemeData(backgroundColor: bgLight),
      child: viewer,
    );
  }

  Widget _buildSearchLayout(ColorScheme cs, Color bgLight) {
    return SafeArea(
      child: Column(
        children: [
          _buildSearchBar(context, cs, bgLight),
          Expanded(child: _buildPdfViewer(bgLight)),
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
          // ── PDF viewer — always full screen, never rebuilt on bar toggle ──
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handlePdfScroll,
              child: _buildPdfViewer(bgLight),
            ),
          ),

          // ── Transparent tap overlay ────────────────────────────────────
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

          // ── Top bar ────────────────────────────────────────────────────
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

          // ── Bottom bar ─────────────────────────────────────────────────
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

          // ── Splash cover — fades out once the viewer signals ready ───────
          // The viewer renders underneath from the first frame, so by the time
          // this opacity animation completes the first page is already painted.
          // This eliminates the mid-render flash without any artificial delay.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isViewerReady ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(color: bgLight),
            ),
          ),
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
                          color: undoValue.canUndo
                              ? cs.onSurface
                              : cs.onSurfaceVariant.withOpacity(0.4),
                          size: 20),
                      onPressed: undoValue.canUndo
                          ? () => _undoController.undo()
                          : null,
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

  Future<void> _saveAnnotations() async {
    try {
      final List<int> bytes = await _pdfController.saveDocument();
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Cached AI Insights Panel
// ─────────────────────────────────────────────────────────────────────────────

class _CachedInsightsPanel extends ConsumerStatefulWidget {
  final int bookId;
  final String filePath;
  final int currentPage;

  const _CachedInsightsPanel({
    required this.bookId,
    required this.filePath,
    required this.currentPage,
  });

  @override
  ConsumerState<_CachedInsightsPanel> createState() => _CachedInsightsPanelState();
}

class _CachedInsightsPanelState extends ConsumerState<_CachedInsightsPanel> {
  final ScrollController _thinkingScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(insightsProvider.notifier).checkCache(widget.bookId);
    });
  }

  @override
  void dispose() {
    _thinkingScrollController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not yet indexed. Please wait a few seconds.')),
      );
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _EngineChip(
                        label: 'Nano', 
                        type: AiEngineType.geminiNano,
                        onTap: state.isProcessingGlobal ? null : () {
                          ref.read(aiEngineSelectionProvider.notifier).state = AiEngineType.geminiNano;
                        },
                      ),
                      const SizedBox(width: 8),
                      _EngineChip(
                        label: 'Pro SLM', 
                        type: AiEngineType.slmPro,
                        onTap: state.isProcessingGlobal ? null : () {
                          ref.read(aiEngineSelectionProvider.notifier).state = AiEngineType.slmPro;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildDownloadSection(),
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
                    if (state.thinkingSteps.isNotEmpty) ...[
                      _buildThinkingLog(state),
                    ],
                    state.result.when(
                      data: (result) {
                        if (result == null) return const SizedBox.shrink();
                        return _buildSummaryContent(result);
                      },
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (state.isProcessingGlobal)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                )
              else
                Icon(Icons.check_circle_outline_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 12),
              Text(
                state.isProcessingGlobal ? 'AI is thinking...' : 'Analysis Complete',
                style: GoogleFonts.archivo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              controller: _thinkingScrollController,
              itemCount: state.thinkingSteps.length,
              itemBuilder: (context, index) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_thinkingScrollController.hasClients) {
                    _thinkingScrollController.jumpTo(_thinkingScrollController.position.maxScrollExtent);
                  }
                });
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '> ${state.thinkingSteps[index]}',
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              },
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

  Widget _buildDownloadSection() {
    final modelState = ref.watch(modelManagerProvider);
    final cs = Theme.of(context).colorScheme;
    if (modelState.isDownloaded) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upgrade to Pro AI for full book analysis',
                  style: GoogleFonts.archivo(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (modelState.isDownloading) ...[
             LinearProgressIndicator(value: modelState.progress),
             const SizedBox(height: 8),
             Text('Downloading: ${(modelState.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10)),
          ] else
            FilledButton.icon(
              onPressed: () => ref.read(modelManagerProvider.notifier).downloadModel(),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download Gemma 2B (1.5GB)'),
            ),
        ],
      ),
    );
  }

  Widget _EngineChip({required String label, required AiEngineType type, VoidCallback? onTap}) {
    final selection = ref.watch(aiEngineSelectionProvider);
    final isSelected = selection == type;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.archivo(fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: onTap == null ? null : (val) {
        if (val) onTap();
      },
    );
  }
}
