import 'dart:io';
import 'dart:math' as math;
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
  final double minimizeThreshold; // Scroll threshold (e.g. 0.1 = 10%)
  final bool forceCustomBar; // Force the custom bar instead of native
  /// Bottom offset to lift bar from home indicator. 0 = flush.
  final double bottomOffset;
  /// Enable/disable scroll-based minimize/expand behavior.
  final bool enableMinimize;
  /// Offset (px) after which minimize/expand logic is allowed. Set 0 for immediate.
  final double collapseStartOffset;
  /// Animation duration for minimize/expand and item transitions.
  final Duration animationDuration;

  LiquidBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
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
    this.minimizeThreshold = 0.1, // Default 10%
    this.forceCustomBar = false, // Use custom bar even on iOS 26+
    this.bottomOffset = 0,
    this.enableMinimize = true,
    this.collapseStartOffset = 20.0,
    this.animationDuration = const Duration(milliseconds: 250),
  }) : assert(items.length >= 2 && items.length <= 5),
       assert(itemCounts == null || itemCounts.length == items.length);

  static final GlobalKey<_CustomLiquidBarState> barKey = GlobalKey();
  static _LiquidBottomNavigationBarState? _nativeState;

  static void handleScroll(double offset, double delta) {
    final customState = barKey.currentState;
    if (customState != null) {
      customState.handleScroll(offset, delta);
      return;
    }

    _nativeState?._sendScrollToNative(offset, delta);
  }

  @override
  State<LiquidBottomNavigationBar> createState() =>
      _LiquidBottomNavigationBarState();
}

class _LiquidBottomNavigationBarState extends State<LiquidBottomNavigationBar> {
  bool _useNative = false;
  bool _isChecking = true;
  MethodChannel? _eventChannel;
  MethodChannel? _scrollChannel;
  int? _platformViewId;
  double _lastScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    LiquidBottomNavigationBar._nativeState = this;
    _checkIOSVersion();
    _setupEventChannel();
  }

  void _setupEventChannel() {
    _eventChannel = const MethodChannel('liquid_tabbar_minimize/events');
    _eventChannel!.setMethodCallHandler(_handleNativeEvents);
  }

  Future<void> _handleNativeEvents(MethodCall call) async {
    if (call.method == 'onTabChanged') {
      final index = call.arguments as int;
      if (index >= 0 && index < widget.items.length) {
        widget.onTap?.call(index);
      }
    } else if (call.method == 'onActionTapped') {
      widget.onActionTap?.call();
    }
  }

  @override
  void dispose() {
    if (LiquidBottomNavigationBar._nativeState == this) {
      LiquidBottomNavigationBar._nativeState = null;
    }
    _eventChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _checkIOSVersion() async {
    // iOS 26+ uses native; others fall back to custom unless forceCustomBar is set.
    if (widget.forceCustomBar) {
      setState(() {
        _useNative = false;
        _isChecking = false;
      });
      widget.onNativeDetected?.call(false);
      return;
    }

    // Parse major iOS version (e.g., "Version 18.0.1" -> 18)
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    final major = match != null ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
    final canUseNative = Platform.isIOS && major >= 26;

    setState(() {
      _useNative = canUseNative;
      _isChecking = false;
    });
    widget.onNativeDetected?.call(canUseNative);
    debugPrint('iOS version: $major, native tabbar: $canUseNative');
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const SizedBox.shrink();
    }

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
        bottomOffset: widget.bottomOffset,
        enableMinimize: widget.enableMinimize,
        collapseStartOffset: widget.collapseStartOffset,
        animationDuration: widget.animationDuration,
      );
    }

    if (_useNative && Theme.of(context).platform == TargetPlatform.iOS) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final actionSFSymbol = widget.actionIcon?.$2 ?? 'magnifyingglass';
      final selectedColor =
          widget.selectedItemColor ?? theme.colorScheme.primary;
      final unselectedColor =
          widget.unselectedItemColor ??
          (isDark
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.5));

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final current = notification.metrics.pixels;
            final delta = current - _lastScrollOffset;
            _lastScrollOffset = current;
            _sendScrollToNative(current, delta);
          }
          return false;
        },
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.transparent,
                // Native view already respects safe area; add bottomOffset for parity with custom bar.
                height: widget.height + widget.bottomOffset,
                child: UiKitView(
                  viewType: 'liquid_tabbar_minimize/swiftui_tabbar',
                  onPlatformViewCreated: (id) {
                    _platformViewId = id;
                    _scrollChannel = MethodChannel(
                      'liquid_tabbar_minimize/scroll_$id',
                    );
                  },
                  creationParams: {
                    'labels': widget.items.map((e) => e.label ?? '').toList(),
                    'sfSymbols': widget.items.map((e) {
                      final iconData = (e.icon as Icon).icon!;
                      return widget.sfSymbolMapper?.call(iconData) ??
                          'circle.fill';
                    }).toList(),
                    'initialIndex': widget.currentIndex,
                    'enableActionTab': widget.showActionButton,
                    'actionSymbol': actionSFSymbol,
                    'selectedColorHex':
                        '#${selectedColor.value.toRadixString(16).padLeft(8, '0')}',
                    'unselectedColorHex':
                        '#${unselectedColor.value.toRadixString(16).padLeft(8, '0')}',
                    'enableMinimize': widget.enableMinimize,
                    'labelVisibility': widget.labelVisibility.name,
                    'bottomOffset': widget.bottomOffset,
                    'collapseStartOffset': widget.collapseStartOffset,
                    'animationDurationMs': widget.animationDuration.inMilliseconds,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
      bottomOffset: widget.bottomOffset,
      enableMinimize: widget.enableMinimize,
      collapseStartOffset: widget.collapseStartOffset,
      animationDuration: widget.animationDuration,
    );
  }

  void _sendScrollToNative(double offset, double delta) {
    if (_scrollChannel == null || !widget.enableMinimize) {
      debugPrint('⚠️ Scroll channel not ready yet');
      return;
    }
    _scrollChannel!
        .invokeMethod('onScroll', {
          'offset': offset,
          'delta': delta,
        })
        .catchError((error) {
          debugPrint('❌ Send scroll error: $error');
        });
  }
}

// Custom liquid tab bar (iOS < 26 veya forceCustomBar: true)
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
  final double bottomOffset;
  final bool enableMinimize;
  final double collapseStartOffset;
  final Duration animationDuration;

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
    required this.bottomOffset,
    required this.enableMinimize,
    required this.collapseStartOffset,
    required this.animationDuration,
  });

  @override
  State<_CustomLiquidBar> createState() => _CustomLiquidBarState();
}

class _CustomLiquidBarState extends State<_CustomLiquidBar> {
  double _barOpacity = 1.0;
  bool _isCollapsed = false;
  MethodChannel? _nativeChannel;
  int? _viewId;
  DateTime _ignoreScrollUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _expandedLockUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initNativeChannel();
  }

  @override
  void didUpdateWidget(covariant _CustomLiquidBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enableMinimize && _isCollapsed) {
      setState(() {
        _isCollapsed = false;
      });
    }
  }

  void _initNativeChannel() {
    _viewId = DateTime.now().millisecondsSinceEpoch;
    _nativeChannel = MethodChannel('liquid_tabbar_minimize/methods_$_viewId');
  }

  void _pauseScrollHandling(Duration duration) {
    _ignoreScrollUntil = DateTime.now().add(duration);
  }

  void _lockExpanded(Duration duration) {
    _expandedLockUntil = DateTime.now().add(duration);
  }

  void handleScroll(double offset, double delta) {
    if (!widget.enableMinimize) return;
    if (DateTime.now().isBefore(_ignoreScrollUntil)) return;
    if (!_isCollapsed && DateTime.now().isBefore(_expandedLockUntil)) return;
    final double topSnapOffset =
        widget.collapseStartOffset.clamp(0, double.infinity);
    final double pixelThreshold = topSnapOffset;

    // Ignore sudden large jumps (e.g., after tab switch)
    if (delta.abs() > 120) return;

    // Collapse after threshold on downward scroll
    if (!_isCollapsed && delta > 4 && offset > pixelThreshold) {
      setState(() {
        _isCollapsed = true;
        _barOpacity = 1.0;
      });
      return;
    }

    // Expand only when we return to the top area
    if (_isCollapsed && offset <= topSnapOffset) {
      setState(() {
        _isCollapsed = false;
        _barOpacity = 1.0;
      });
    }
  }

  void sendScrollToNative(double offset) {
    if (Platform.isIOS && _nativeChannel != null) {
      _nativeChannel!
          .invokeMethod('updateScrollOffset', {'offset': offset})
          .catchError((error) {
            debugPrint('sendScrollToNative error: $error');
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
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor = widget.selectedItemColor ?? theme.colorScheme.primary;
    final unselectedColor =
        widget.unselectedItemColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.5));
    final isActionSelected =
        widget.showActionButton && widget.currentIndex >= widget.items.length;

    // Custom bar spacing: small positive gap so action pill is separated but close.
    final double actionSpacing = widget.showActionButton ? 8.0 : 0.0;
    final double fullWidth = MediaQuery.of(context).size.width;
    final double barWidth = widget.showActionButton
        ? fullWidth - 32 - widget.height - actionSpacing
        : fullWidth - 32;
    final double barWidthClamped = math.max(barWidth, widget.height);
    final double bottomGap =
        widget.bottomOffset + 16; // lift both slightly from home indicator

    return Container(
      height: widget.height + bottomGap,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomGap),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: AnimatedContainer(
                duration: widget.animationDuration,
                curve: Curves.easeInOut,
                width: _isCollapsed ? widget.height : barWidthClamped,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.10)
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.07),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isCollapsed
                          ? _buildCollapsedTab(
                              widget.currentIndex,
                              selectedColor,
                              unselectedColor,
                              isDark,
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
                                    onTap: () {
                                      _pauseScrollHandling(
                                        const Duration(milliseconds: 1200),
                                      );
                                      _lockExpanded(const Duration(milliseconds: 1200));
                                      widget.onTap?.call(index);
                                    },
                                    child: AnimatedContainer(
                                      duration: widget.animationDuration,
                                      curve: Curves.easeInOut,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: isSelected ? 8 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: isDark
                                                    ? [
                                                        Colors.white.withValues(
                                                          alpha: 0.18,
                                                        ),
                                                        Colors.white.withValues(
                                                          alpha: 0.12,
                                                        ),
                                                      ]
                                                    : [
                                                        Colors.black.withValues(
                                                          alpha: 0.12,
                                                        ),
                                                        Colors.black.withValues(
                                                          alpha: 0.08,
                                                        ),
                                                      ],
                                              )
                                            : null,
                                        borderRadius: BorderRadius.circular(26),
                                        border: isSelected
                                            ? Border.all(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.3,
                                                      )
                                                    : Colors.black.withValues(
                                                        alpha: 0.15,
                                                      ),
                                                width: 0.5,
                                              )
                                            : null,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.05,
                                                        ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AnimatedScale(
                                            scale: isSelected ? 1.05 : 1.0,
                                            duration: widget.animationDuration,
                                            curve: Curves.easeInOut,
                                            child: IconTheme(
                                              data: IconThemeData(
                                                size: isSelected ? 26 : 24,
                                                color: isSelected
                                                    ? selectedColor
                                                    : unselectedColor,
                                              ),
                                              child: item.icon,
                                            ),
                                          ),
                                          if (item.label != null &&
                                              _shouldShowLabel(isSelected)) ...[
                                            const SizedBox(height: 4),
                                            Flexible(
                                              child: Text(
                                                item.label!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? selectedColor
                                                      : unselectedColor,
                                                  letterSpacing: 0.2,
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
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () {
                    _pauseScrollHandling(const Duration(milliseconds: 1200));
                    _lockExpanded(const Duration(milliseconds: 1200));
                    widget.onActionTap?.call();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        width: widget.height,
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.07),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedScale(
                            scale: isActionSelected ? 1.05 : 1.0,
                            duration: widget.animationDuration,
                            curve: Curves.easeInOut,
                            child: IconTheme(
                              data: IconThemeData(
                                size: 40,
                                color: isActionSelected
                                    ? selectedColor
                                    : unselectedColor,
                              ),
                              child:
                                  widget.actionIcon ??
                                  Icon(Icons.search, color: selectedColor),
                            ),
                          ),
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
    bool isDark,
  ) {
    final item = widget.items[currentIndex];
    return GestureDetector(
      onTap: () => setState(() => _isCollapsed = false),
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.12),
                  ]
                : [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.08),
                  ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: 26, color: selectedColor),
            child: item.icon,
          ),
        ),
      ),
    );
  }
}
