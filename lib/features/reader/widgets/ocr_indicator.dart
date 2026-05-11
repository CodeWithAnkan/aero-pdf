import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ocr/ocr_controller.dart';

class OcrIndicator extends ConsumerWidget {
  const OcrIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
  }
}
