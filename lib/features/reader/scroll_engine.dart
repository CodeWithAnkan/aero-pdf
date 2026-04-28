import 'package:flutter/material.dart';

/// Wraps a [ScrollController] and tracks the current page index + scroll
/// direction for the TextureCache.
///
/// Attach [controller] to a [ListView] / [PageView] in [ReaderScreen].
/// Listen to [onPageChanged] for page + direction updates.
class ScrollEngine {
  ScrollEngine({
    required this.pageHeightProvider,
    required this.onPageChanged,
  }) {
    controller = ScrollController();
    controller.addListener(_onScroll);
  }

  /// Called whenever the current page changes.
  /// Provides (pageIndex, scrollDirection: +1 or -1).
  final void Function(int page, int direction) onPageChanged;

  /// Returns the pixel height of the rendered page at [index].
  final double Function(int index) pageHeightProvider;

  late final ScrollController controller;

  int _currentPage = 0;
  double _lastOffset = 0;
  int _scrollDirection = 1;

  int get currentPage => _currentPage;
  int get scrollDirection => _scrollDirection;

  void _onScroll() {
    final offset = controller.offset;
    _scrollDirection = offset > _lastOffset ? 1 : -1;
    _lastOffset = offset;

    // Compute page from cumulative heights
    int page = 0;
    // Simple fixed-height estimation — ReaderScreen can override with real heights
    final approxPageHeight = pageHeightProvider(_currentPage);
    if (approxPageHeight > 0) {
      page = (offset / approxPageHeight).floor();
    }

    if (page != _currentPage) {
      _currentPage = page;
      onPageChanged(page, _scrollDirection);
    }
  }

  /// Jumps to [page] without animation.
  void jumpToPage(int page) {
    final height = pageHeightProvider(page);
    if (controller.hasClients) {
      controller.jumpTo(page * height);
    }
  }

  /// Smoothly animates to [page].
  Future<void> animateToPage(int page) async {
    final height = pageHeightProvider(page);
    if (controller.hasClients) {
      await controller.animateTo(
        page * height,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void dispose() => controller.dispose();
}
