import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:aeropdf/core/db/isar_service.dart';
import 'package:aeropdf/core/models/book.dart';
import 'package:aeropdf/core/security/security_service.dart';

class SavedPasswordsScreen extends StatefulWidget {
  const SavedPasswordsScreen({super.key});

  @override
  State<SavedPasswordsScreen> createState() => _SavedPasswordsScreenState();
}

class _SavedPasswordsScreenState extends State<SavedPasswordsScreen> {
  bool _isAuthenticated = false;
  bool _isAuthenticating = true;
  List<Book> _protectedBooks = [];
  Map<int, String> _passwords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startAuth();
  }

  Future<void> _startAuth() async {
    final success = await SecurityService.authenticate();
    if (success) {
      setState(() {
        _isAuthenticated = true;
        _isAuthenticating = false;
      });
      _loadData();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _loadData() async {
    final isar = await IsarService.instance;
    final books = await isar.books.filter().isPasswordProtectedEqualTo(true).findAll();
    
    Map<int, String> pwdMap = {};
    for (var book in books) {
      final pwd = await SecurityService.getPassword(book.id);
      if (pwd != null) {
        pwdMap[book.id] = pwd;
      }
    }

    if (mounted) {
      setState(() {
        _protectedBooks = books.where((b) => pwdMap.containsKey(b.id)).toList();
        _passwords = pwdMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePassword(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Password?'),
        content: const Text('This will remove the saved password for this file. You will need to enter it again next time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SecurityService.deletePassword(book.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated) {
      return const Scaffold(body: Center(child: Text('Authentication Required')));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Notion-like colors
    final Color notionBg = isDark ? const Color(0xFF191919) : Colors.white;
    final Color notionSurface = isDark ? const Color(0xFF252525) : const Color(0xFFF7F7F5);
    final Color notionBorder = isDark ? const Color(0xFF373737) : const Color(0xFFEAEAEC);
    final Color notionText = isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF37352F);
    final Color notionMuted = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF9A9A9A);

    return Scaffold(
      backgroundColor: notionBg,
      appBar: AppBar(
        backgroundColor: notionBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: notionText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Passwords',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: notionText,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: notionBorder, height: 1),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: notionText),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _protectedBooks.isEmpty
              ? _buildEmptyState(notionText, notionMuted)
              : ListView.builder(
                  itemCount: _protectedBooks.length,
                  itemBuilder: (context, index) {
                    final book = _protectedBooks[index];
                    final pwd = _passwords[book.id] ?? '';
                    return _buildPasswordItem(book, pwd, notionText, notionMuted, notionBorder, notionSurface);
                  },
                ),
    );
  }

  Widget _buildEmptyState(Color text, Color muted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 48, color: muted.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No saved passwords yet',
            style: GoogleFonts.inter(color: muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordItem(Book book, String pwd, Color text, Color muted, Color border, Color surface) {
    return InkWell(
      onTap: () {
        // Show options or copy password?
        _showOptions(book, pwd);
      },
      hoverColor: surface,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: text, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.fileName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '•' * pwd.length,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9A9A9A),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_horiz, color: muted),
              onPressed: () => _showOptions(book, pwd),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(Book book, String pwd) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Password'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: pwd));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Remove from Vault', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deletePassword(book);
              },
            ),
          ],
        ),
      ),
    );
  }
}
