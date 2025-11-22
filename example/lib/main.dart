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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidTabBar(
      items: [
        LiquidTabItem(
          icon: 'house.fill',
          label: 'Home',
          child: _buildPage('Home', Colors.blue),
          nativeData: List.generate(
            20,
            (i) => {
              'title': 'Ana Sayfa ${i + 1}',
              'subtitle': 'Burası home sayfası - item ${i + 1}',
            },
          ),
        ),
        LiquidTabItem(
          icon: 'globe',
          label: 'Explore',
          child: _buildPage('Explore', Colors.green),
          nativeData: List.generate(
            25,
            (i) => {
              'title': 'Keşfet ${i + 1}',
              'subtitle': 'Yeni içerik keşfet - ${i + 1}',
            },
          ),
        ),
        LiquidTabItem(
          icon: 'star.fill',
          label: 'Favorites',
          child: _buildPage('Favorites', Colors.orange),
          nativeData: List.generate(
            30,
            (i) => {
              'title': 'Favori ${i + 1}',
              'subtitle': 'Bu benim favori item\'im',
            },
          ),
        ),
        LiquidTabItem(
          icon: 'gearshape.fill',
          label: 'Settings',
          child: _buildPage('Settings', Colors.purple),
          nativeData: [
            {'title': 'Hesap', 'subtitle': 'Profil ayarları'},
            {'title': 'Bildirimler', 'subtitle': 'Bildirim tercihleri'},
            {'title': 'Gizlilik', 'subtitle': 'Gizlilik ayarları'},
            {'title': 'Güvenlik', 'subtitle': 'Şifre ve güvenlik'},
            {'title': 'Dil', 'subtitle': 'Türkçe'},
            {'title': 'Tema', 'subtitle': 'Koyu mod'},
            {'title': 'Yardım', 'subtitle': 'SSS ve destek'},
            {'title': 'Hakkında', 'subtitle': 'Versiyon 1.0.0'},
          ],
        ),
      ],
      // Yeni parametreler
      showActionTab: true,
      actionIcon: 'magnifyingglass',
      bottomPadding: 0, // Home indicator'dan yukarıda
      tabBarHeight: 68,
      onActionTap: () {
        debugPrint('Search tapped!');
      },
      onTabChanged: (index) {
        debugPrint('Tab changed to: $index');
      },
    );
  }

  Widget _buildPage(String title, Color color) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: color),
      body: ListView.builder(
        itemCount: 50,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.3),
              child: Text('${index + 1}'),
            ),
            title: Text('$title Item ${index + 1}'),
            subtitle: const Text('Scroll down to minimize tab bar'),
          );
        },
      ),
    );
  }
}
