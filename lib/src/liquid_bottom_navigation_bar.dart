import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liquid_tab_item.dart';

/// Label visibility mode
enum LabelVisibility { selectedOnly, always, never }

/// iOS native tab bar with scroll-to-minimize behavior.
class LiquidBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<BottomNavigationBarItem> items;
  final List<Widget> pages;
  final List<int>? itemCounts;
  final bool showActionButton;
  final (Icon, String)? actionIcon;
  final VoidCallback? onActionTap;
  final double height;
  final String Function(IconData)? sfSymbolMapper;
  final ValueChanged<bool>? onNativeDetected;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final ValueChanged<double>? onScroll;
  final LabelVisibility labelVisibility;
  final double minimizeThreshold; // Scroll threshold (örn: 0.1 = %10)
  final bool forceCustomBar; // Native'i devre dışı bırak

  const LiquidBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.pages,
    this.itemCounts,
    this.onTap,
    this.showActionButton = false,
    this.actionIcon,
    this.onActionTap,
    this.height = 68,
    this.sfSymbolMapper,
    this.onNativeDetected,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.onScroll,
    this.labelVisibility = LabelVisibility.always,
    this.minimizeThreshold = 0.1, // Default %10
    this.forceCustomBar = false, // iOS 26'da bile custom bar kullan
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(items.length == pages.length),
       assert(itemCounts == null || itemCounts.length == pages.length);

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

    // Force custom bar veya iOS <26
    if (widget.forceCustomBar || !_useNative || !Platform.isIOS) {
      return _CustomLiquidBar(
        key: LiquidBottomNavigationBar.barKey,
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        items: widget.items,
        showActionButton: widget.showActionButton,
        actionIcon: widget.actionIcon?.$1,
        onActionTap: widget.onActionTap,
        height: widget.height,
        selectedItemColor: widget.selectedItemColor,
        unselectedItemColor: widget.unselectedItemColor,
        labelVisibility: widget.labelVisibility,
        minimizeThreshold: widget.minimizeThreshold,
      );
    }

    // iOS 26+ Native
    if (_useNative && Platform.isIOS) {
      final theme = Theme.of(context);
      final liquidItems = List.generate(widget.items.length, (i) {
        final item = widget.items[i];
        final iconData = (item.icon as Icon).icon!;
        final sfSymbol = widget.sfSymbolMapper?.call(iconData) ?? 'circle.fill';
        final count = widget.itemCounts?[i] ?? 50;
        final nativeData = List.generate(
          count,
          (j) => {
            'title': '${item.label ?? 'Item'} ${j + 1}',
            'subtitle': 'Scroll to see effect',
          },
        );

        return LiquidTabItem(
          icon: sfSymbol,
          label: item.label ?? '',
          child: widget.pages[i],
          nativeData: nativeData,
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
          'labelVisibility': widget.labelVisibility.name,
          'minimizeThreshold': widget.minimizeThreshold, // Swift'e gönder
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    // Fallback (aslında buraya hiç gelmez ama required için)
    return _CustomLiquidBar(
      key: LiquidBottomNavigationBar.barKey,
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: widget.items,
      showActionButton: widget.showActionButton,
      actionIcon: widget.actionIcon?.$1,
      onActionTap: widget.onActionTap,
      height: widget.height,
      selectedItemColor: widget.selectedItemColor,
      unselectedItemColor: widget.unselectedItemColor,
      labelVisibility: widget.labelVisibility,
      minimizeThreshold: widget.minimizeThreshold, // Eksik olan parametre
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
  final LabelVisibility labelVisibility;
  final double minimizeThreshold;

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
    required this.labelVisibility,
    required this.minimizeThreshold,
  });

  @override
  State<_CustomLiquidBar> createState() => _CustomLiquidBarState();
}

class _CustomLiquidBarState extends State<_CustomLiquidBar> {
  double _barOpacity = 1.0;
  bool _isCollapsed = false;

  void handleScroll(double offset, double delta) {
    final threshold = widget.minimizeThreshold * 1000; // 0.1 = 100px

    if (offset <= 50) {
      if (_isCollapsed) {
        setState(() {
          _isCollapsed = false;
          _barOpacity = 1.0;
        });
      }
      return;
    }

    if (delta.abs() < 3.0) return;

    // Threshold check
    if (offset > threshold && delta > 0 && !_isCollapsed) {
      setState(() {
        _isCollapsed = true;
        _barOpacity = 1.0;
      });
    } else if (delta < 0 && _isCollapsed) {
      setState(() {
        _isCollapsed = false;
        _barOpacity = 1.0;
      });
    }
  }

  bool _shouldShowLabel(bool isSelected) {
    switch (widget.labelVisibility) {
      case LabelVisibility.selectedOnly:
        return isSelected;
      case LabelVisibility.always:
        return true;
      case LabelVisibility.never:
        return false;
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
    final isActionSelected =
        widget.showActionButton && widget.currentIndex >= widget.items.length;

    return Transform.translate(
      offset: const Offset(0, 6),
      child: Container(
        height: widget.height + safeAreaBottom,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: safeAreaBottom),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: _isCollapsed
                      ? widget.height
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: List.generate(widget.items.length, (
                                  index,
                                ) {
                                  final item = widget.items[index];
                                  final isSelected =
                                      widget.currentIndex == index;
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
                                            if (item.label != null &&
                                                _shouldShowLabel(
                                                  isSelected,
                                                )) ...[
                                              const SizedBox(height: 3),
                                              Flexible(
                                                child: Text(
                                                  item.label!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                  ? selectedColor
                                  : (theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : Colors.black.withValues(alpha: 0.6)),
                            ),
                            child:
                                widget.actionIcon ?? const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
      onTap: () => setState(() => _isCollapsed = false),
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
