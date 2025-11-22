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
  final ValueChanged<double>? onScroll; // Scroll callback

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
    this.onScroll,
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(items.length == pages.length);

  // Scroll bilgisini bar'a iletmek için public key
  static final GlobalKey<_CustomLiquidBarState> barKey = GlobalKey();

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
      key: LiquidBottomNavigationBar.barKey,
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
    super.key,
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
  bool _isCollapsed = false;

  void handleScroll(double offset, double delta) {
    const threshold = 3.0;

    if (offset <= 50) {
      if (_isCollapsed) {
        setState(() {
          _isCollapsed = false;
          _barOpacity = 1.0;
        });
      }
      return;
    }

    if (delta.abs() < threshold) return;

    if (delta > 0 && !_isCollapsed) {
      // Yukarı scroll → COLLAPSE
      setState(() {
        _isCollapsed = true;
        _barOpacity = 1.0; // Opacity değişmez, sadece morph olur
      });
    } else if (delta < 0 && _isCollapsed) {
      // Aşağı scroll → EXPAND
      setState(() {
        _isCollapsed = false;
        _barOpacity = 1.0;
      });
    }
  }

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

    // Action button seçili mi kontrol et
    final isActionSelected =
        widget.showActionButton && widget.currentIndex >= widget.items.length;

    return Container(
      height: widget.height + safeAreaBottom,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: safeAreaBottom),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Main TabBar - Collapse/Expand animasyonlu
            Align(
              alignment: Alignment.bottomLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _isCollapsed
                    ? widget
                          .height // Action button ile aynı boyut (kare)
                    : (widget.showActionButton
                          ? MediaQuery.of(context).size.width -
                                32 -
                                widget.height -
                                10
                          : MediaQuery.of(context).size.width - 32),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isCollapsed
                          ? _buildCollapsedTab(
                              widget.currentIndex,
                              selectedColor,
                              unselectedColor,
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(widget.items.length, (
                                index,
                              ) {
                                final item = widget.items[index];
                                final isSelected = widget.currentIndex == index;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => widget.onTap?.call(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeInOut,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: isSelected ? 2 : 3,
                                        vertical: isSelected ? 6 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.08,
                                                    ))
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          isSelected ? 28 : 36,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
            ),

            // Action Button - SABİT
            if (widget.showActionButton)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: widget.onActionTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
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
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            size: 24,
                            color: isActionSelected
                                ? selectedColor // Seçiliyken primary color
                                : (theme.brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.black.withValues(alpha: 0.6)),
                          ),
                          child: widget.actionIcon ?? const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedTab(
    int currentIndex,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final item = widget.items[currentIndex];

    return GestureDetector(
      onTap: () {
        setState(() => _isCollapsed = false);
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: 24, color: selectedColor),
            child: item.icon,
          ),
        ),
      ),
    );
  }
}
