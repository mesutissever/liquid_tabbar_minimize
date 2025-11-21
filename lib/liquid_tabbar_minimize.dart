library liquid_tabbar_minimize;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _swiftUIPresenterChannel = MethodChannel(
  'liquid_tabbar_minimize/swiftui_presenter',
);

/// iOS native tab bar item modeli (SF Symbol + label)
class NativeTabItem {
  final String sfSymbol;
  final String label;

  const NativeTabItem({required this.sfSymbol, required this.label});
}

/// iOS’ta: native UITabBar + minimize animasyonu (tamamen Swift’te)
/// Diğer platformlarda: normal BottomNavigationBar
class NativeMinimizingTabScaffold extends StatefulWidget {
  const NativeMinimizingTabScaffold({
    super.key,
    required this.items,
    required this.pages,
    this.initialIndex = 0,
  }) : assert(items.length == pages.length);

  final List<NativeTabItem> items;
  final List<Widget> pages;
  final int initialIndex;

  @override
  State<NativeMinimizingTabScaffold> createState() =>
      _NativeMinimizingTabScaffoldState();
}

class _NativeMinimizingTabScaffoldState
    extends State<NativeMinimizingTabScaffold> {
  static const String _viewType = 'liquid_tabbar_minimize/native_tabbar';

  MethodChannel? _channel;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('liquid_tabbar_minimize/tabbar_$id');

    // iOS tarafında tab bar itemlarını kur
    _channel?.invokeMethod('setItems', {
      'labels': widget.items.map((e) => e.label).toList(),
      'sfSymbols': widget.items.map((e) => e.sfSymbol).toList(),
      'selectedIndex': _index,
    });

    // iOS’ta tab seçilince Flutter’a haber ver
    _channel?.setMethodCallHandler((call) async {
      if (call.method == 'onTabSelected') {
        final int newIndex = (call.arguments['index'] as int?) ?? 0;
        if (!mounted) return;
        setState(() {
          _index = newIndex;
        });
      }
    });
  }

  /// Tüm scroll’ları dinleyip sadece offset’i Swift’e forward ediyoruz.
  bool _onScrollNotification(ScrollNotification notification) {
    if (!Platform.isIOS) return false;
    if (_channel == null) return false;

    final offset = notification.metrics.pixels;
    _channel?.invokeMethod('setScrollOffset', {'offset': offset});

    return false; // scroll olayı normal devam etsin
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = widget.pages[_index];

    // iOS dışı platformlarda: normal bottom nav
    if (!Platform.isIOS) {
      return Scaffold(
        body: currentPage,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: widget.items
              .map(
                (e) => BottomNavigationBarItem(
                  icon: const Icon(Icons.circle),
                  label: e.label,
                ),
              )
              .toList(),
        ),
      );
    }

    // iOS: native tabbar + minimize (animasyon tamamen Swift’te)
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: currentPage,
      ),
      bottomNavigationBar: SizedBox(
        height: 64,
        child: UiKitView(
          viewType: _viewType,
          onPlatformViewCreated: _onPlatformViewCreated,
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: {
            'labels': widget.items.map((e) => e.label).toList(),
            'sfSymbols': widget.items.map((e) => e.sfSymbol).toList(),
            'selectedIndex': _index,
          },
        ),
      ),
    );
  }
}

/// SwiftUI tab bar denemesi (tamamen native SwiftUI TabView + minimize behavior).
/// Flutter tarafı sadece host ediyor; içerik SwiftUI listeleri.
class NativeSwiftUITabScaffold extends StatelessWidget {
  const NativeSwiftUITabScaffold({
    super.key,
    required this.items,
    this.enableActionTab = false,
    this.actionSymbol = 'magnifyingglass',
    this.actionLabel = '',
    this.onActionTap,
  });

  final List<NativeTabItem> items;
  final bool enableActionTab;
  final String actionSymbol;
  final String actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const Center(child: Text('SwiftUI tab bar only runs on iOS 18+'));
    }

    return UiKitView(
      viewType: 'liquid_tabbar_minimize/swiftui_tabbar',
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: {
        'labels': items.map((e) => e.label).toList(),
        'sfSymbols': items.map((e) => e.sfSymbol).toList(),
        'enableActionTab': enableActionTab,
        'actionSymbol': actionSymbol,
        'actionLabel': actionLabel,
      },
      onPlatformViewCreated: (_) {
        // Listen for search tap events on the shared channel
        _swiftUIPresenterChannel.setMethodCallHandler((call) async {
          if (call.method == 'onActionTapped') {
            onActionTap?.call();
          }
          return null;
        });
      },
    );
  }
}

/// Tam ekran SwiftUI tab bar’ı modally sunar; içerik tamamen native.
class NativeSwiftUIFullScreen extends StatefulWidget {
  const NativeSwiftUIFullScreen({
    super.key,
    required this.items,
    this.enableActionTab = false,
    this.actionSymbol = 'magnifyingglass',
    this.actionLabel = '',
    this.onActionTap,
  });
  final List<NativeTabItem> items;
  final bool enableActionTab;
  final String actionSymbol;
  final String actionLabel;
  final VoidCallback? onActionTap;

  @override
  State<NativeSwiftUIFullScreen> createState() =>
      _NativeSwiftUIFullScreenState();
}

class _NativeSwiftUIFullScreenState extends State<NativeSwiftUIFullScreen> {
  bool _presented = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _attachHandler();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _present();
      });
    }
  }

  void _attachHandler() {
    _swiftUIPresenterChannel.setMethodCallHandler((call) async {
      if (call.method == 'onActionTapped') {
        widget.onActionTap?.call();
      }
      return null;
    });
  }

  Future<void> _present() async {
    if (_presented) return;
    _presented = true;
    try {
      await _swiftUIPresenterChannel.invokeMethod('presentSwiftUITabBar', {
        'labels': widget.items.map((e) => e.label).toList(),
        'sfSymbols': widget.items.map((e) => e.sfSymbol).toList(),
        'enableActionTab': widget.enableActionTab,
        'actionSymbol': widget.actionSymbol,
        'actionLabel': widget.actionLabel,
      });
    } catch (_) {
      // Ignore errors; keep Flutter UI visible
    }
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      _swiftUIPresenterChannel.invokeMethod('dismissSwiftUITabBar');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const Center(
        child: Text('SwiftUI full-screen tab bar only runs on iOS'),
      );
    }
    // Flutter tarafı boş bir container; içerik native modally gösteriliyor.
    return const SizedBox.shrink();
  }
}
