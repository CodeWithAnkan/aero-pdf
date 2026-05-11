import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ReaderSearchBar extends StatelessWidget {
  final ColorScheme cs;
  final Color bgLight;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final PdfTextSearchResult? searchResult;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;

  const ReaderSearchBar({
    super.key,
    required this.cs,
    required this.bgLight,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResult,
    required this.onCloseSearch,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final result = searchResult;
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
              onPressed: onCloseSearch),
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
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
              onChanged: onSearchChanged,
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
