import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ReaderAppBar extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  final Color bgLight;
  final UndoHistoryController undoController;
  final VoidCallback onSaveAnnotations;
  final VoidCallback onStartSearch;
  final VoidCallback onOpenInsights;

  const ReaderAppBar({
    super.key,
    required this.title,
    required this.cs,
    required this.bgLight,
    required this.undoController,
    required this.onSaveAnnotations,
    required this.onStartSearch,
    required this.onOpenInsights,
  });

  @override
  Widget build(BuildContext context) {
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
              title,
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
            valueListenable: undoController,
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
                          ? () => undoController.undo()
                          : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.save_rounded,
                          color: cs.onSurface, size: 20),
                      onPressed: onSaveAnnotations,
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
                onStartSearch();
              } else if (value == 2) {
                onOpenInsights();
              }
            },
          ),
        ],
      ),
    );
  }
}
