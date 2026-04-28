import 'package:aeropdf/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // The screens attached to the bottom navigation
  final List<Widget> _screens = [
    const LibraryScreen(), // Your existing library
    const SearchScreen(),
    const SettingsScreen(), // The new settings screen
  ];

  @override
  @override
  Widget build(BuildContext context) {
    // Grab dynamic colors
    final cs = Theme.of(context).colorScheme;
    final bgLight = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant)), 
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: bgLight, // Dynamic background
          elevation: 0,
          selectedItemColor: cs.onSurface, // Dynamic selected icon (Black/White)
          unselectedItemColor: cs.onSurfaceVariant, // Dynamic unselected icon (Grey)
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4, top: 8), child: Icon(Icons.book_rounded)),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4, top: 8), child: Icon(Icons.search_rounded)),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4, top: 8), child: Icon(Icons.settings_rounded)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}