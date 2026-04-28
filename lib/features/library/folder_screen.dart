import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FolderScreen extends StatelessWidget {
  final String folderName;
  
  const FolderScreen({
    super.key, 
    this.folderName = 'Behavioral Psychology',
  });

  // Notion Color Palette
  static const _bgLight = Color(0xFFF6F7F8);
  static const _surface = Colors.white;
  static const _surfaceHover = Color(0xFFF7F7F5);
  static const _textMain = Color(0xFF37352F);
  static const _textMuted = Color(0xFF9A9A9A);
  static const _border = Color(0xFFEAEAEC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          folderName,
          style: const TextStyle(
            color: _textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: _textMain),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sort & Filter Bar ──────────────────────────────────────────
          Container(
            color: _surfaceHover,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                _buildFilterChip('Sort by: Recent'),
                const SizedBox(width: 12),
                _buildFilterChip('Filter'),
              ],
            ),
          ),

          // ── Document List ──────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                _buildDocTile(context, 'Thinking_Fast_and_Slow.pdf', '4.2 MB', 'Oct 12, 2023'),
                _buildDocTile(context, 'Predictably_Irrational.pdf', '3.8 MB', 'Sep 28, 2023'),
                _buildDocTile(context, 'Nudge_Improving_Decisions.pdf', '5.1 MB', 'Aug 14, 2023'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildFilterChip(String label) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textMain,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _textMain),
        ],
      ),
    );
  }

  Widget _buildDocTile(BuildContext context, String title, String size, String date) {
    return InkWell(
      onTap: () {}, // Open PDF logic
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            // Leading Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surfaceHover,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.description_outlined, color: _textMain, size: 20),
            ),
            const SizedBox(width: 16),
            
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textMain,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$size • $date',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Trailing Options
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: _textMuted),
              highlightColor: _border,
              onPressed: () => _showFileOptions(context, title),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Sheet Modal ──────────────────────────────────────────────────

  void _showFileOptions(BuildContext context, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // File Name Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textMuted,
                  ),
                ),
              ),
              
              // Actions
              _buildSheetAction(Icons.edit_rounded, 'Rename', _textMain),
              _buildSheetAction(Icons.drive_file_move_outline, 'Move to...', _textMain),
              
              const Divider(color: _border, height: 16, indent: 8, endIndent: 8),
              
              _buildSheetAction(Icons.delete_outline_rounded, 'Delete', Colors.red.shade600),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetAction(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}