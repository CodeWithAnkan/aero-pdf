import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uri_to_file/uri_to_file.dart';
import 'library_provider.dart';

class ImportIntentScreen extends ConsumerStatefulWidget {
  final String intentUri;
  const ImportIntentScreen({super.key, required this.intentUri});

  @override
  ConsumerState<ImportIntentScreen> createState() => _ImportIntentScreenState();
}

class _ImportIntentScreenState extends ConsumerState<ImportIntentScreen> {
  @override
  void initState() {
    super.initState();
    _processIncomingFile();
  }

  Future<void> _processIncomingFile() async {
    try {
      // 1. Convert the content:// URI into a readable temporary File
      final file = await toFile(widget.intentUri);
      
      // 2. Pass it to your existing library logic (copies to permanent storage, hashes, indexes)
      final book = await ref.read(libraryProvider.notifier).addPdfFromPath(file.path);
      
      if (!mounted) return;

      if (book != null) {
        // 3. Success -> Open the reader
        context.go('/');
        Future.microtask(() {
          if (mounted) context.push('/reader/${book.id}');
        });
      } else {
        // Failed to import -> Go home
        context.go('/');
      }
    } catch (e) {
      debugPrint("Intent Import Error: $e");
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Importing Document...',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}