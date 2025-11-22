import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liquid_tab_item.dart';

/// iOS scroll-to-minimize özellikli native tab bar.
///
/// iOS 18+ cihazlarda SwiftUI TabView kullanır ve scroll sırasında
/// tab bar minimize olur. Android ve diğer platformlarda Material
/// BottomNavigationBar kullanır.
class LiquidTabBar extends StatefulWidget {
  /// Tab bar item'ları
  final List<LiquidTabItem> items;

  /// Başlangıç seçili index
  final int initialIndex;

  /// Tab değiştiğinde çağrılır
  final ValueChanged<int>? onTabChanged;

  /// Action tab (arama gibi) gösterilsin mi?
  final bool showActionTab;

  /// Action tab icon'u (SF Symbol)
  final String actionIcon;

  /// Action tab tıklandığında
  final VoidCallback? onActionTap;

  const LiquidTabBar({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onTabChanged,
    this.showActionTab = false,
    this.actionIcon = 'magnifyingglass',
    this.onActionTap,
  }) : assert(
         items.length >= 2 && items.length <= 5,
         'Tab bar 2-5 arası item içermelidir',
       );

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  late int _currentIndex;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (Platform.isIOS) {
      _channel = const MethodChannel('liquid_tabbar_minimize/events');
      _channel!.setMethodCallHandler(_handleMethodCall);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onTabChanged') {
      final index = call.arguments as int;
      if (index >= 0 && index < widget.items.length) {
        setState(() => _currentIndex = index);
        widget.onTabChanged?.call(index);
      }
    } else if (call.method == 'onActionTapped') {
      widget.onActionTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSNative();
    }
    return _buildMaterialFallback();
  }

  Widget _buildIOSNative() {
    // iOS native tab bar sadece tab structure'ı sağlıyor
    // İçerik Flutter widget'ları olarak gösteriliyor
    return UiKitView(
      viewType: 'liquid_tabbar_minimize/swiftui_tabbar',
      creationParams: {
        'labels': widget.items.map((e) => e.label).toList(),
        'sfSymbols': widget.items.map((e) => e.icon).toList(),
        'initialIndex': _currentIndex,
        'enableActionTab': widget.showActionTab,
        'actionSymbol': widget.actionIcon,
        'nativeData': widget.items.map((e) => e.nativeData ?? []).toList(),
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  Widget _buildMaterialFallback() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: widget.items.map((item) => item.child).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          widget.onTabChanged?.call(index);
        },
        type: BottomNavigationBarType.fixed,
        items: widget.items.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(_mapSFSymbolToMaterial(item.icon)),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  IconData _mapSFSymbolToMaterial(String sfSymbol) {
    // SF Symbol -> Material Icon mapping
    const mapping = {
      'house.fill': Icons.home,
      'house': Icons.home_outlined,
      'globe': Icons.public,
      'star.fill': Icons.star,
      'star': Icons.star_outline,
      'gearshape.fill': Icons.settings,
      'gearshape': Icons.settings_outlined,
      'person.fill': Icons.person,
      'person': Icons.person_outline,
      'heart.fill': Icons.favorite,
      'heart': Icons.favorite_border,
      'magnifyingglass': Icons.search,
    };
    return mapping[sfSymbol] ?? Icons.circle;
  }
}
