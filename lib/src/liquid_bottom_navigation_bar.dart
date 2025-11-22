import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liquid_tab_item.dart';

/// iOS native tab bar with scroll-to-minimize behavior.
/// Automatically detects iOS 26+ and uses native minimize.
class LiquidBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<BottomNavigationBarItem> items;
  final List<Widget> pages;
  final bool showActionButton;
  final (Icon, String)? actionIcon; // (Custom Icon, Native SF Symbol)
  final VoidCallback? onActionTap;
  final double height;
  final String Function(IconData)? sfSymbolMapper;
  final ValueChanged<bool>? onNativeDetected;
  final Color? selectedItemColor; // Seçili tab rengi
  final Color? unselectedItemColor; // Seçili olmayan tab rengi

  const LiquidBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.pages,
    this.onTap,
    this.showActionButton = false,
    this.actionIcon, // (Icon(Icons.search), 'magnifyingglass')
    this.onActionTap,
    this.height = 68,
    this.sfSymbolMapper,
    this.onNativeDetected,
    this.selectedItemColor, // null ise theme.colorScheme.primary
    this.unselectedItemColor, // null ise grey
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(items.length == pages.length);

  @override
  State<LiquidBottomNavigationBar> createState() =>
      _LiquidBottomNavigationBarState();
}

class _LiquidBottomNavigationBarState extends State<LiquidBottomNavigationBar> {
  bool _useNative = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkIOSVersion();
  }

  Future<void> _checkIOSVersion() async {
    if (Platform.isIOS) {
      try {
        final version = Platform.operatingSystemVersion;
        final match = RegExp(r'Version (\d+)\.').firstMatch(version);
        if (match != null) {
          final major = int.tryParse(match.group(1) ?? '0') ?? 0;
          setState(() {
            _useNative = major >= 26;
            _isChecking = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('iOS version check failed: $e');
      }
    }
    setState(() {
      _useNative = false;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const SizedBox.shrink();
    }

    // iOS 26+ Native
    if (_useNative && Platform.isIOS) {
      final theme = Theme.of(context);
      final liquidItems = List.generate(widget.items.length, (i) {
        final item = widget.items[i];
        final iconData = (item.icon as Icon).icon!;
        final sfSymbol = widget.sfSymbolMapper?.call(iconData) ?? 'circle.fill';

        return LiquidTabItem(
          icon: sfSymbol,
          label: item.label ?? '',
          child: widget.pages[i],
        );
      });

      final actionSFSymbol = widget.actionIcon?.$2 ?? 'magnifyingglass';
      final selectedColor =
          widget.selectedItemColor ?? theme.colorScheme.primary;

      return UiKitView(
        viewType: 'liquid_tabbar_minimize/swiftui_tabbar',
        creationParams: {
          'labels': liquidItems.map((e) => e.label).toList(),
          'sfSymbols': liquidItems.map((e) => e.icon).toList(),
          'initialIndex': 0,
          'enableActionTab': widget.showActionButton,
          'actionSymbol': actionSFSymbol,
          'nativeData': liquidItems.map((e) => e.nativeData ?? []).toList(),
          'selectedColorHex':
              '#${selectedColor.value.toRadixString(16).padLeft(8, '0')}',
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    // iOS <26 & Android Custom
    return _CustomLiquidBar(
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: widget.items,
      showActionButton: widget.showActionButton,
      actionIcon: widget.actionIcon?.$1, // Tuple'dan Icon çıkar
      onActionTap: widget.onActionTap,
      height: widget.height,
      selectedItemColor: widget.selectedItemColor,
      unselectedItemColor: widget.unselectedItemColor,
    );
  }
}

class _CustomLiquidBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<BottomNavigationBarItem> items;
  final bool showActionButton;
  final Icon? actionIcon;
  final VoidCallback? onActionTap;
  final double height;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const _CustomLiquidBar({
    required this.currentIndex,
    required this.items,
    this.onTap,
    required this.showActionButton,
    this.actionIcon,
    this.onActionTap,
    required this.height,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  @override
  State<_CustomLiquidBar> createState() => _CustomLiquidBarState();
}

class _CustomLiquidBarState extends State<_CustomLiquidBar> {
  double _barOpacity = 1.0;
  double _lastScrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final selectedColor = widget.selectedItemColor ?? theme.colorScheme.primary;
    final unselectedColor =
        widget.unselectedItemColor ??
        (theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.6));

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final offset = notification.metrics.pixels;
          final delta = offset - _lastScrollOffset;
          _handleScroll(offset, delta);
          _lastScrollOffset = offset;
        }
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: _barOpacity * (widget.height + safeAreaBottom),
        child: Transform.translate(
          offset: const Offset(0, 10),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: safeAreaBottom,
            ),
            child: Row(
              children: [
                // Main TabBar
                Expanded(
                  flex: widget.showActionButton ? 4 : 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        height: widget.height,
                        decoration: BoxDecoration(
                          color:
                              (theme.brightness == Brightness.dark
                                      ? Colors.black.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.7))
                                  .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(widget.items.length, (index) {
                            final item = widget.items[index];
                            final isSelected = widget.currentIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => widget.onTap?.call(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isSelected
                                        ? 2
                                        : 3, // Seçiliyken daha geniş
                                    vertical: isSelected
                                        ? 6
                                        : 8, // Seçiliyken daha yassı
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (theme.brightness == Brightness.dark
                                              ? Colors.white.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.08,
                                                ))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      isSelected
                                          ? 28
                                          : 36, // Seçiliyken daha az yuvarlak (geoid)
                                    ),
                                    border: isSelected
                                        ? Border.all(
                                            color:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.25,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.12,
                                                  ),
                                            width: 0.5,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconTheme(
                                        data: IconThemeData(
                                          size: isSelected ? 26 : 23,
                                          color: isSelected
                                              ? selectedColor
                                              : unselectedColor,
                                        ),
                                        child: item.icon,
                                      ),
                                      if (item.label != null) ...[
                                        const SizedBox(height: 3),
                                        Flexible(
                                          child: Text(
                                            item.label!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? selectedColor
                                                  : unselectedColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),

                // Action Button
                if (widget.showActionButton) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.onActionTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36), // Daha oval
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: widget.height,
                          height: widget.height,
                          decoration: BoxDecoration(
                            color:
                                (theme.brightness == Brightness.dark
                                        ? Colors.black.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.7))
                                    .withValues(alpha: 0.8),
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              size: 24,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.black.withValues(alpha: 0.6),
                            ),
                            child:
                                widget.actionIcon ?? const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleScroll(double offset, double delta) {
    const threshold = 5.0;
    if (offset <= 0) {
      if (_barOpacity != 1.0) {
        setState(() => _barOpacity = 1.0);
      }
    } else if (delta.abs() < threshold) {
      return;
    } else {
      final shouldShow = delta < 0;
      final newOpacity = shouldShow ? 1.0 : 0.0;
      if (_barOpacity != newOpacity) {
        setState(() => _barOpacity = newOpacity);
      }
    }
  }

  IconData _parseIcon(String name) {
    const mapping = {
      'home': Icons.home,
      'search': Icons.search,
      'settings': Icons.settings,
      'person': Icons.person,
      'favorite': Icons.favorite,
    };
    return mapping[name] ?? Icons.circle;
  }
}
