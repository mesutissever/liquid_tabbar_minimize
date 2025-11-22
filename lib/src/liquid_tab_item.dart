import 'package:flutter/widgets.dart';

/// Represents a tab bar item.
class LiquidTabItem {
  /// iOS SF Symbol name (e.g. 'house.fill', 'globe', 'star')
  final String icon;

  /// Tab label
  final String label;

  /// Tab content (page widget)
  final Widget child;

  /// Custom data for iOS native view (optional)
  /// Each item should be in format { 'title': String, 'subtitle': String }
  final List<Map<String, String>>? nativeData;

  const LiquidTabItem({
    required this.icon,
    required this.label,
    required this.child,
    this.nativeData,
  });
}
