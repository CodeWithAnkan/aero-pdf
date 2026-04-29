import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ── State Variables ───────────────────────────────────────────────────────
  // Note: Dark mode is handled globally by Riverpod now, so it's not here!
  bool _keepAwake = true;
  String _defaultZoom = 'Fit Page';

  String _storageUsed = 'Calculating...';
  String _cacheSize = 'Calculating...';
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateStorage();
  }

  // ── Settings Persistence ──────────────────────────────────────────────────
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepAwake = prefs.getBool('keepAwake') ?? true;
      _defaultZoom = prefs.getString('defaultZoom') ?? 'Fit Page';
    });
    
    if (_keepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<void> _toggleKeepAwake(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keepAwake', value);
    setState(() => _keepAwake = value);
    
    if (value) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  // ── Real Storage & Cache Logic ────────────────────────────────────────────

  Future<void> _calculateStorage() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final storageBytes = await _getDirectorySize(docDir);

      final tempDir = await getTemporaryDirectory();
      final cacheBytes = await _getDirectorySize(tempDir);

      if (mounted) {
        setState(() {
          _storageUsed = _formatBytes(storageBytes);
          _cacheSize = _formatBytes(cacheBytes);
        });
      }
    } catch (e) {
      debugPrint("[Settings] Storage calculation error: $e");
      if (mounted) {
        setState(() {
          _storageUsed = 'Error';
          _cacheSize = 'Error';
        });
      }
    }
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;
    if (await dir.exists()) {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _clearCache() async {
    if (_cacheSize == '0 B' || _isClearingCache) return;

    setState(() => _isClearingCache = true);

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      
      await _calculateStorage();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("[Settings] Cache clear error: $e");
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  // ── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 1. Get the current theme colors dynamically
    final isDarkMode = ref.watch(themeProvider);
    final cs = Theme.of(context).colorScheme;
    final bgLight = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cs.outlineVariant, height: 1), 
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          'Settings',
          style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // ── Appearance ─────────────────────────────────────────────────
          _buildSectionHeader('Appearance', cs.onSurfaceVariant),
          _buildSectionGroup(cs.outlineVariant, cs.surface, [
            _buildSwitchTile('Dark Mode', isDarkMode, (val) {
              ref.read(themeProvider.notifier).toggle(val);
            }, cs.onSurface, cs.primary),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Typography', cs.onSurface, cs.onSurfaceVariant, trailingText: ref.watch(typographyProvider), onTap: _showTypographyOptions),
          ]),

          // ── Reading ─────────────────────────────────────────────────────
          _buildSectionHeader('Reading', cs.onSurfaceVariant),
          _buildSectionGroup(cs.outlineVariant, cs.surface, [
            _buildSwitchTile('Keep Screen Awake', _keepAwake, _toggleKeepAwake, cs.onSurface, cs.primary),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Default Zoom', cs.onSurface, cs.onSurfaceVariant, trailingText: _defaultZoom, onTap: _showZoomOptions),
          ]),

          // ── Storage ─────────────────────────────────────────────────────
          _buildSectionHeader('Storage', cs.onSurfaceVariant),
          _buildSectionGroup(cs.outlineVariant, cs.surface, [
            _buildInfoTile('Local Storage Used', _storageUsed, cs.onSurface, cs.onSurfaceVariant),
            _buildDivider(cs.outlineVariant),
            _isClearingCache 
                ? _buildInfoTile('Clearing...', '', cs.onSurfaceVariant, cs.onSurfaceVariant)
                : _buildInfoTile('Clear Cache', _cacheSize, Colors.red.shade400, cs.onSurfaceVariant, isDestructive: true, onTap: _clearCache),
          ]),

          // ── About ───────────────────────────────────────────────────────
          _buildSectionHeader('About', cs.onSurfaceVariant),
          _buildSectionGroup(cs.outlineVariant, cs.surface, [
            _buildInfoTile('Version', '1.0.0', cs.onSurface, cs.onSurfaceVariant),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Privacy Policy', cs.onSurface, cs.onSurfaceVariant, onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
            }),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Terms of Service', cs.onSurface, cs.onSurfaceVariant, onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
            }),
          ]),
        ],
      ),
    );
  }

  void _showTypographyOptions() {
    final cs = Theme.of(context).colorScheme;
    final options = ['Inter', 'Roboto', 'Outfit', 'Archivo'];
    final currentFont = ref.read(typographyProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Typography', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ),
              Divider(color: cs.outlineVariant, height: 1),
              ...options.map((opt) => ListTile(
                title: Text(opt, style: TextStyle(color: cs.onSurface)),
                trailing: currentFont == opt ? Icon(Icons.check, color: cs.primary) : null,
                onTap: () {
                  ref.read(typographyProvider.notifier).setTypography(opt);
                  Navigator.of(context).pop();
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _showZoomOptions() {
    final cs = Theme.of(context).colorScheme;
    final options = ['Fit Page', 'Fit Width', '100%', '150%'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Default Zoom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ),
              Divider(color: cs.outlineVariant, height: 1),
              ...options.map((opt) => ListTile(
                title: Text(opt, style: TextStyle(color: cs.onSurface)),
                trailing: _defaultZoom == opt ? Icon(Icons.check, color: cs.primary) : null,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('defaultZoom', opt);
                  setState(() => _defaultZoom = opt);
                  Navigator.of(context).pop();
                },
              )),
            ],
          ),
        );
      },
    );
  }

  // ── UI Helper Methods ───────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionGroup(Color border, Color surface, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.symmetric(horizontal: BorderSide(color: border)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(Color border) {
    return Container(
      height: 1,
      color: border,
      margin: const EdgeInsets.only(left: 16),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, Color textMain, Color primary) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 15, color: textMain, fontWeight: FontWeight.w500)),
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: value,
                activeColor: primary,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(String title, Color textMain, Color textMuted, {String? trailingText, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap, 
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 15, color: textMain, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  if (trailingText != null) ...[
                    Text(trailingText, style: TextStyle(fontSize: 15, color: textMuted)),
                    const SizedBox(width: 4),
                  ],
                  Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, Color textMain, Color textMuted, {bool isDestructive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 15, color: textMain, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 15, color: textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Privacy Policy', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policy for AeroPDF', style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Effective Date: April 29, 2026', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 16),
            Text('At AeroPDF, we believe your data belongs to you. This Privacy Policy outlines our commitment to a 100% offline, private PDF experience.', style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5)),
            const SizedBox(height: 24),
            _buildSection(cs, '1. Zero-Cloud Architecture', 'AeroPDF is built to function entirely offline. Your PDF documents, annotations, and library data are stored exclusively on your device. We do not maintain servers to store, process, or backup your personal files.'),
            _buildSection(cs, '2. Information Handling', '• Document Data: All PDF files remain in your device\'s local storage. AeroPDF accesses these files only to provide viewing, searching, and management features.\n\nOn-Device AI & OCR:\n• OCR (Optical Character Recognition): Text extraction is performed locally using on-device vision libraries.\n• AI Insights: All AI-powered features (summarization, analysis, insights) utilize on-device machine learning models. No document text or metadata is ever transmitted to an external server or third-party API for processing.\n\n• Analytics: AeroPDF does not track your behavior or collect usage telemetry. We do not use cookies or trackers.'),
            _buildSection(cs, '3. Permissions', 'To provide its services, AeroPDF requires:\n• Storage/Files: To import and manage your PDF documents locally.'),
            _buildSection(cs, '4. No Third-Party Data Sharing', 'Because AeroPDF operates offline, we do not share, sell, or trade any user information with third parties. There are no external AI service providers involved in the core functionality of the app.'),
            _buildSection(cs, '5. Security', 'Data security is managed at the device level. We utilize the Isar database for high-performance local storage. We recommend using device encryption and secure lock screens to protect your local data.'),
            _buildSection(cs, '6. Changes to This Policy', 'If future updates introduce optional cloud features, this policy will be updated, and such features will be strictly "opt-in."'),
            _buildSection(cs, '7. Contact Us', 'For questions regarding this privacy-first approach, contact us at: ankanchatterjee4855@gmail.com'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ColorScheme cs, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Terms of Service', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terms of Service for AeroPDF', style: TextStyle(color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Last Updated: April 29, 2026', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 16),
            Text('Welcome to AeroPDF. By using our application, you agree to these Terms. AeroPDF is designed as a fully offline productivity tool.', style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5)),
            const SizedBox(height: 24),
            _buildSection(cs, '1. License and Scope', 'AeroPDF grants you a personal, non-exclusive license to use the software. As a fully offline tool, you are responsible for maintaining the application and your data on your own hardware.'),
            _buildSection(cs, '2. Intellectual Property', 'The AeroPDF software, including its unique on-device AI implementation and UI/UX design, is the exclusive property of the developer. You may not decompile or attempt to extract the source code of the application.'),
            _buildSection(cs, '3. Local Data Responsibility', 'You retain 100% ownership of your content. Since AeroPDF does not sync to the cloud:\n\n• Backup: You are solely responsible for backing up your PDF documents and annotations.\n• Data Loss: We are not liable for data loss resulting from device failure, app deletion, or hardware damage.'),
            _buildSection(cs, '4. On-Device AI and OCR', '• Privacy: You acknowledge that all AI processing happens locally on your hardware.\n• Performance: AI performance and accuracy are dependent on your device\'s hardware capabilities (CPU/GPU/NPU).\n• No Warranty: While we aim for high-quality extractions and summaries, AI outputs are provided "as-is" without a guarantee of perfect accuracy.'),
            _buildSection(cs, '5. Disclaimer of Warranties', 'AeroPDF is provided "AS IS." We disclaim all warranties regarding the constant availability of the app or its compatibility with every possible PDF format variation.'),
            _buildSection(cs, '6. Limitation of Liability', 'In no event shall the developer of AeroPDF be liable for any damages arising out of the use or inability to use the software, even if notified of the possibility of such damages.'),
            _buildSection(cs, '7. Governing Law', 'These Terms are governed by the laws of India.'),
            _buildSection(cs, '8. Contact', 'Gmail: ankanchatterjee4855@gmail.com'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ColorScheme cs, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}

class StaticDocScreen extends StatelessWidget {
  final String title;
  final String content;

  const StaticDocScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          content,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}