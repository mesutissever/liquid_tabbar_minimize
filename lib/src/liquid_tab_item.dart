import 'package:flutter/widgets.dart';

/// Bir tab bar item'ını temsil eder.
class LiquidTabItem {
  /// iOS SF Symbol adı (örn: 'house.fill', 'globe', 'star')
  final String icon;

  /// Tab'in etiketi
  final String label;

  /// Tab'in içeriği (sayfa)
  final Widget child;

  /// iOS native view için custom data (opsiyonel)
  /// Her item { 'title': String, 'subtitle': String } formatında olmalı
  final List<Map<String, String>>? nativeData;

  const LiquidTabItem({
    required this.icon,
    required this.label,
    required this.child,
    this.nativeData,
  });
}
