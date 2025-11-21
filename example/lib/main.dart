import 'package:flutter/material.dart';
import 'package:liquid_tabbar_minimize/liquid_tabbar_minimize.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        // scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // SwiftUI tab bar denemesi (iOS 18+). Android/platform dışı için altta fallback.
    const items = [
      NativeTabItem(sfSymbol: 'house.fill', label: 'Anasayfa'),
      NativeTabItem(sfSymbol: 'globe', label: 'Keşfet'),
      NativeTabItem(sfSymbol: 'gearshape.fill', label: 'Ayarlar'),
    ];

    if (Platform.isIOS) {
      return NativeSwiftUIFullScreen(
        items: items,
        enableActionTab: true,
        actionSymbol: 'magnifyingglass',
        actionLabel: '',
        onActionTap: () {
          debugPrint('Native action tab tapped');
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter fallback')),
      body: const Center(child: Text('SwiftUI tab bar sadece iOS\'ta çalışır')),
    );
  }
}

class DemoListPage extends StatelessWidget {
  final String title;
  const DemoListPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(title),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            IconButton(icon: const Icon(Icons.person), onPressed: () {}),
          ],
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              title: Text('$title item $index'),
              subtitle: const Text('Description text here'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            );
          }, childCount: 100),
        ),
      ],
    );
  }
}
