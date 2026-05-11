import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReaderBottomBar extends StatelessWidget {
  final ColorScheme cs;
  final Color bgLight;
  final ValueNotifier<double> scrollProgress;
  final int totalPages;
  final ValueChanged<double> onScrub;
  final ValueChanged<double> onScrubEnd;

  const ReaderBottomBar({
    super.key,
    required this.cs,
    required this.bgLight,
    required this.scrollProgress,
    required this.totalPages,
    required this.onScrub,
    required this.onScrubEnd,
  });

  @override
  Widget build(BuildContext context) {
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
            valueListenable: scrollProgress,
            builder: (context, progress, _) {
              final displayPage = (progress * (totalPages - 1)).round() + 1;
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
                  Text('$totalPages PAGES', style: style),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: scrollProgress,
            builder: (context, progress, child) {
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  activeTrackColor: cs.onSurface,
                  inactiveTrackColor: cs.outlineVariant,
                  thumbColor: cs.onSurface,
                  overlayColor: cs.onSurface.withOpacity(0.1),
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6, elevation: 0),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                  trackShape: const RectangularSliderTrackShape(),
                ),
                child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onScrub,
                    onChangeEnd: onScrubEnd),
              );
            },
          ),
        ],
      ),
    );
  }
}
