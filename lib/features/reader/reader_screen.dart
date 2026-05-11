import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/isar_service.dart';
import '../../core/models/book.dart';
import '../../core/pdf/indexing_isolate.dart';
import '../ocr/ocr_controller.dart';
import '../../core/models/search_index.dart';
import '../../core/security/security_service.dart';

import 'utils/pdf_cache.dart';
import 'widgets/reader_loading_screen.dart';
import 'widgets/reader_app_bar.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/insights_panel.dart';
import 'widgets/ocr_indicator.dart';
import 'widgets/password_dialog.dart';

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
  String? _currentPassword; // stores password if document is encrypted
  String? _viewerPassword; // password passed to SfPdfViewer

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
        if (pdfBytesCache.containsKey(book.filePath)) {
          bytes = pdfBytesCache[book.filePath]!;
        } else {
          // Read on a separate isolate — keeps the main thread free so the
          // fade-in transition animation runs at full 60fps while bytes load.
          final loaded = await compute(readFileBytes, book.filePath);
          pdfBytesCache[book.filePath] = loaded;
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
      builder: (_) => InsightsPanel(
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
            ? ReaderLoadingScreen(
                loadProgressAnim: _loadProgressAnim,
                cs: cs,
                bgLight: bgLight,
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

    void onDocLoaded(PdfDocumentLoadedDetails d) async {
      setState(() {
        _totalPages = _pdfController.pageCount;
        _isViewerReady = true; // lifts the splash cover
      });
      if (_totalPages > 1) {
        _scrollProgress.value = _currentPage / (_totalPages - 1);
      }
      if (_pdfController.pageCount == 1) _saveProgress();

      // Trigger indexing here to ensure we have the password if needed
      final book = _book;
      if (book != null) {
        // If it was imported as locked, we now have the true page count. Update Isar.
        if (book.totalPages == 0 || book.isPasswordProtected) {
          final isar = await IsarService.instance;
          await isar.writeTxn(() async {
            book.totalPages = _totalPages;
            book.isPasswordProtected = true; // Ensure flag is correct
            await isar.books.put(book);
          });
        }

        // Save password to secure storage if we have it
        if (_currentPassword != null) {
          SecurityService.savePassword(book.id, _currentPassword!);
        }

        if (!book.isIndexed) {
          IsarService.directoryPath.then((isarDir) {
            indexBookInBackground(
              book.id,
              book.filePath,
              isarDir,
              password: _currentPassword,
            );
          });
        }
      }
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

    void onDocLoadFailed(PdfDocumentLoadFailedDetails d) async {
      debugPrint('[AeroPDF] PDF Load Failed: ${d.error}');
      
      // Broad check for password/encryption related failures
      final isPasswordError = d.error.toLowerCase().contains('password') || 
                              d.error.toLowerCase().contains('encrypt') ||
                              d.error.toLowerCase().contains('protect');

      if (isPasswordError) {
        // Small delay to ensure the viewer has finished its internal cleanup
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (!mounted) return;
        final pwd = await showPasswordDialog(context, fileName: _book?.fileName ?? 'document.pdf');
        if (pwd != null) {
          setState(() {
            _viewerPassword = pwd;
            _currentPassword = pwd;
            _error = null;
          });
        } else {
          // User canceled password prompt -> Exit reader and go back to library
          if (mounted) context.pop();
        }
      } else {
        setState(() => _error = d.error);
      }
    }

    void onPdfTap(PdfGestureDetails details) {
      if (_hasSelection) {
        _pdfController.clearSelection();
      } else {
        _setShowUi(!_showUi);
      }
    }

    void onLinkClick(PdfHyperlinkClickedDetails details) {
      HapticFeedback.selectionClick();
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
            password: _viewerPassword,
            canShowPasswordDialog: false,
            onTextSelectionChanged: onTextSel,
            onDocumentLoaded: onDocLoaded,
            onPageChanged: onPageChanged,
            onDocumentLoadFailed: onDocLoadFailed,
            onTap: onPdfTap,
            onHyperlinkClicked: onLinkClick,
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
            password: _viewerPassword,
            canShowPasswordDialog: false,
            onTextSelectionChanged: onTextSel,
            onDocumentLoaded: onDocLoaded,
            onPageChanged: onPageChanged,
            onDocumentLoadFailed: onDocLoadFailed,
            onTap: onPdfTap,
            onHyperlinkClicked: onLinkClick,
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



          // ── Top bar ────────────────────────────────────────────────────
          AnimatedPositioned(
            duration: _barAnimDuration,
            curve: Curves.easeInOut,
            top: _showUi ? 0 : -300,
            left: 0,
            right: 0,
            child: ReaderAppBar(
              title: _book!.title,
              cs: cs,
              bgLight: bgLight,
              undoController: _undoController,
              onSaveAnnotations: _saveAnnotations,
              onStartSearch: _startSearch,
              onOpenInsights: _openInsightsPanel,
            ),
          ),

          // ── Bottom bar ─────────────────────────────────────────────────
          AnimatedPositioned(
            duration: _barAnimDuration,
            curve: Curves.easeInOut,
            bottom: _showUi ? 0 : -300,
            left: 0,
            right: 0,
            child: ReaderBottomBar(
              cs: cs,
              bgLight: bgLight,
              scrollProgress: _scrollProgress,
              totalPages: _totalPages,
              onScrub: _onScrub,
              onScrubEnd: _onScrubEnd,
            ),
          ),

          const OcrIndicator(),

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

  Widget _buildSearchBar(BuildContext context, ColorScheme cs, Color bgLight) {
    return ReaderSearchBar(
      cs: cs,
      bgLight: bgLight,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      searchResult: _searchResult,
      onCloseSearch: _closeSearch,
      onSearchChanged: _onSearchChanged,
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