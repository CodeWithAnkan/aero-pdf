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
            _buildNavTile('Typography', cs.onSurface, cs.onSurfaceVariant),
          ]),

          // ── Reading ─────────────────────────────────────────────────────
          _buildSectionHeader('Reading', cs.onSurfaceVariant),
          _buildSectionGroup(cs.outlineVariant, cs.surface, [
            _buildSwitchTile('Keep Screen Awake', _keepAwake, _toggleKeepAwake, cs.onSurface, cs.primary),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Default Zoom', cs.onSurface, cs.onSurfaceVariant, trailingText: 'Fit Width'),
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
            _buildInfoTile('Version', '1.0.0 (Build 1)', cs.onSurface, cs.onSurfaceVariant),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Privacy Policy', cs.onSurface, cs.onSurfaceVariant),
            _buildDivider(cs.outlineVariant),
            _buildNavTile('Terms of Service', cs.onSurface, cs.onSurfaceVariant),
          ]),
        ],
      ),
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

  Widget _buildNavTile(String title, Color textMain, Color textMuted, {String? trailingText}) {
    return InkWell(
      onTap: () {}, 
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