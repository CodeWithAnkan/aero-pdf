import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadTheme();
    return false; // Default to light mode
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('darkMode') ?? false;
  }

  Future<void> toggle(bool isDark) async {
    state = isDark; 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark); 
  }
}

class TypographyNotifier extends Notifier<String> {
  @override
  String build() {
    _loadTypography();
    return 'Inter'; 
  }

  Future<void> _loadTypography() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('appTypography') ?? 'Inter';
  }

  Future<void> setTypography(String font) async {
    state = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTypography', font);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);
final typographyProvider = NotifierProvider<TypographyNotifier, String>(TypographyNotifier.new);