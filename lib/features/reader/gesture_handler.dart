import 'package:flutter/material.dart';

/// Centralises all gesture recognition for the PDF reader:
///
/// - **Single tap** → toggle AppBar + controls visibility
/// - **Double tap** → toggle zoom (fit-width ↔ 150%)
/// - **Long press** → text selection / highlight toolbar
/// - **Pinch zoom** → delegated to the wrapping [InteractiveViewer]
class GestureHandler extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(LongPressStartDetails) onLongPress;

  const GestureHandler({
    super.key,
    required this.child,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPressStart: onLongPress,
      child: child,
    );
  }
}

/// Builds the annotation / selection toolbar shown after a long-press.
/// Returns null if the toolbar should not appear.
Widget buildSelectionToolbar({
  required BuildContext context,
  required VoidCallback onHighlight,
  required VoidCallback onUnderline,
  required VoidCallback onCopy,
  required VoidCallback onAddNote,
}) {
  return Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(8),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarButton(
          icon: Icons.highlight,
          label: 'Highlight',
          color: Colors.yellow,
          onTap: onHighlight,
        ),
        _ToolbarButton(
          icon: Icons.format_underline,
          label: 'Underline',
          color: Colors.blue,
          onTap: onUnderline,
        ),
        _ToolbarButton(
          icon: Icons.note_add_outlined,
          label: 'Note',
          color: Colors.green,
          onTap: onAddNote,
        ),
        _ToolbarButton(
          icon: Icons.copy_rounded,
          label: 'Copy',
          onTap: onCopy,
        ),
      ],
    ),
  );
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
