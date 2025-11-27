import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Separate ScrollController for each page
  late final ScrollController _homeScrollController;
  late final ScrollController _exploreScrollController;
  late final ScrollController _favoritesScrollController;
  late final ScrollController _settingsScrollController;

  @override
  void initState() {
    super.initState();
    _homeScrollController = ScrollController()
      ..addListener(() => _onScroll(_homeScrollController));
    _exploreScrollController = ScrollController()
      ..addListener(() => _onScroll(_exploreScrollController));
    _favoritesScrollController = ScrollController()
      ..addListener(() => _onScroll(_favoritesScrollController));
    _settingsScrollController = ScrollController()
      ..addListener(() => _onScroll(_settingsScrollController));
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _exploreScrollController.dispose();
    _favoritesScrollController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  void _onScroll(ScrollController controller) {
    final offset = controller.offset;
    final delta = offset - _lastScrollOffset;

    _handleScroll(offset, delta);

    _lastScrollOffset = offset;
  }

  void _handleScroll(double offset, double delta) {
    LiquidBottomNavigationBar.handleScroll(offset, delta);
  }

  void _stopCurrentScrollMomentum() {
    ScrollController? controller;
    switch (_selectedIndex) {
      case 0:
        controller = _homeScrollController;
      case 1:
        controller = _exploreScrollController;
      case 2:
        controller = _favoritesScrollController;
      case 3:
        controller = _settingsScrollController;
    }
    if (controller != null && controller.hasClients) {
      controller.animateTo(
        controller.offset,
        duration: Duration.zero,
        curve: Curves.linear,
      );
    }
  }

  // iOS 26+ SF Symbol mapping
  String _iconToSFSymbol(IconData icon) {
    if (icon == Icons.home) return 'house.fill';
    if (icon == Icons.public) return 'globe';
    if (icon == Icons.star) return 'star.fill';
    if (icon == Icons.settings) return 'gearshape.fill';

    return 'circle.fill'; // fallback
  }

  // Dedicated page for each tab
  Widget _buildHomePage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Home'), backgroundColor: Colors.blue),
      body: ListView.builder(
        controller: _homeScrollController,
        itemCount: 20,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(Icons.home, color: Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Home Item ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scroll to see minimize effect',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExplorePage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        backgroundColor: Colors.green,
      ),
      body: GridView.builder(
        controller: _exploreScrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemCount: 50,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 40, color: Colors.green),
                const SizedBox(height: 8),
                Text(
                  'Place ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.orange,
      ),
      body: ListView.builder(
        controller: _favoritesScrollController,
        itemCount: 50,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withValues(alpha: 0.3),
              child: Icon(Icons.star, color: Colors.orange),
            ),
            title: Text('Favorite Item ${index + 1}'),
            subtitle: const Text('Tap to view details'),
            trailing: Icon(Icons.chevron_right, color: Colors.orange),
          );
        },
      ),
    );
  }

  Widget _buildSettingsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.purple,
      ),
      body: ListView(
        controller: _settingsScrollController,
        children: [
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'John Doe',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'john.doe@example.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingsTile(
            Icons.notifications,
            'Notifications',
            'Manage notifications',
          ),
          _buildSettingsTile(Icons.privacy_tip, 'Privacy', 'Privacy settings'),
          _buildSettingsTile(Icons.language, 'Language', 'Change language'),
          _buildSettingsTile(Icons.dark_mode, 'Dark Mode', 'Toggle dark mode'),
          _buildSettingsTile(Icons.help, 'Help & Support', 'Get help'),
          _buildSettingsTile(Icons.info, 'About', 'App version 1.0.0'),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.purple),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildSearchPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(Icons.search, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Find what you need',
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          _buildExplorePage(),
          _buildFavoritesPage(),
          _buildSettingsPage(),
          _buildSearchPage(),
        ],
      ),
      bottomNavigationBar: LiquidBottomNavigationBar(
        enableMinimize: true,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _lastScrollOffset = 0;
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
        sfSymbolMapper: _iconToSFSymbol,
        showActionButton: true,
        actionIcon: (const Icon(Icons.search), 'magnifyingglass'),
        onActionTap: () {
          debugPrint('Search tapped!');
          _stopCurrentScrollMomentum();
          setState(() {
            _selectedIndex = 4;
            _lastScrollOffset = 0;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white,
        labelVisibility: LabelVisibility.always,
        height: 68,
        forceCustomBar: false,
        collapseStartOffset: 0,
      ),
    );
  }
}
