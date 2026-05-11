import 'package:flutter/material.dart';

class ReaderLoadingScreen extends StatelessWidget {
  final Animation<double> loadProgressAnim;
  final ColorScheme cs;
  final Color bgLight;

  const ReaderLoadingScreen({
    super.key,
    required this.loadProgressAnim,
    required this.cs,
    required this.bgLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('loading'),
      color: bgLight,
      child: SafeArea(
        child: Column(
          children: [
            // ── Thin progress bar at the very top ─────────────────────────
            AnimatedBuilder(
              animation: loadProgressAnim,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: loadProgressAnim.value,
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
}
