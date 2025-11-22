import 'dart:io';
import 'package:flutter/material.dart';
import 'package:liquid_tabbar_minimize/liquid_tabbar_minimize.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  double _lastScrollOffset = 0;

  // Native data builder
  // List<Map<String, String>> _buildNativeData(int tabIndex, String label) {
  //   // Her tab için farklı item count
  //   final counts = [10, 50, 50, 50]; // Home: 10, diğerleri: 50
  //   final count = counts[tabIndex];

  //   return List.generate(
  //     count,
  //     (i) => {
  //       'title': '$label Item ${i + 1}',
  //       'subtitle': 'Scroll to see effect',
  //     },
  //   );
  // }

  // iOS 26+ için SF Symbol mapping
  String _iconToSFSymbol(IconData icon) {
    if (icon == Icons.home) return 'house.fill';
    if (icon == Icons.public) return 'globe';
    if (icon == Icons.star) return 'star.fill';
    if (icon == Icons.settings) return 'gearshape.fill';

    return 'circle.fill'; // fallback
  }

  static Widget _buildPageWithScroll(
    String title,
    Color color,
    int count,
    Function(double, double) onScroll,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: color),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            onScroll(notification.metrics.pixels, notification.metrics.pixels);
          }
          return false;
        },
        child: ListView.builder(
          itemCount: count,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.3),
                child: Text('${index + 1}'),
              ),
              title: Text('$title Item ${index + 1}'),
              subtitle: const Text('Scroll to see liquid effect'),
            );
          },
        ),
      ),
    );
  }

  void _handleScroll(double offset, double delta) {
    final barState = LiquidBottomNavigationBar.barKey.currentState;
    barState?.handleScroll(offset, offset - _lastScrollOffset);
    _lastScrollOffset = offset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildPageWithScroll('Home', Colors.blue, 12, _handleScroll),
          _buildPageWithScroll('Explore', Colors.green, 50, _handleScroll),
          _buildPageWithScroll('Favorites', Colors.orange, 50, _handleScroll),
          _buildPageWithScroll('Settings', Colors.purple, 50, _handleScroll),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Search',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: LiquidBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          debugPrint('Tab index: $index');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        pages: [
          _buildPageWithScroll('Home', Colors.blue, 10, _handleScroll),
          _buildPageWithScroll('Explore', Colors.green, 50, _handleScroll),
          _buildPageWithScroll('Favorites', Colors.orange, 50, _handleScroll),
          _buildPageWithScroll('Settings', Colors.purple, 50, _handleScroll),
        ],
        itemCounts: const [12, 50, 50, 50], // iOS 26 native için
        sfSymbolMapper: _iconToSFSymbol,
        showActionButton: true,
        actionIcon: (const Icon(Icons.search), 'magnifyingglass'),
        onActionTap: () {
          debugPrint('Search tapped!');
          setState(() => _selectedIndex = 4);
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        labelVisibility: LabelVisibility.always,
        height: 68,
        minimizeThreshold: 0.1, // 100px scroll sonrası minimize
        forceCustomBar:
            false, // iOS 26'da da custom bar kullan (threshold kontrolü için)
      ),
    );
  }
}
