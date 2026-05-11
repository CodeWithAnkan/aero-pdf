import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<String?> showPasswordDialog(BuildContext context, {String fileName = 'document.pdf'}) async {
  final controller = TextEditingController();
  final cs = Theme.of(context).colorScheme;
  bool showPassword = false;
  
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password Protected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.archivo(
                        fontWeight: FontWeight.w700, 
                        fontSize: 17,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Requires password to open',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12, 
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // File Info Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 16, color: cs.onSurface.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.inter(
                          fontSize: 12, 
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Password',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                obscureText: !showPassword,
                autofocus: true,
                style: GoogleFonts.inter(color: cs.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  hintStyle: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.3), fontSize: 14),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.1),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() => showPassword = !showPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: cs.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Cancel', 
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_open_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Open File', 
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
