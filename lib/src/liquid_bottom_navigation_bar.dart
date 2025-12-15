import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liquid_route_observer.dart';

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

  const LiquidBottomNavigationBar({
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

  static _LiquidBottomNavigationBarState? _nativeState;
  static _CustomLiquidBarState? _customState;

  /// Unique instance ID to avoid platform view collisions on hot restart
  static int _instanceCounter = 0;
  static int get _nextInstanceId {
    _instanceCounter++;
    return DateTime.now().millisecondsSinceEpoch + _instanceCounter;
  }

  static void handleScroll(double offset, double delta) {
    // Use direct state reference instead of GlobalKey to avoid hot-reload issues
    if (_customState != null) {
      _customState!.handleScroll(offset, delta);
      return;
    }

    if (_nativeState == null) return;
    _nativeState?._sendScrollToNative(offset, delta);
  }

  @override
  State<LiquidBottomNavigationBar> createState() =>
      _LiquidBottomNavigationBarState();
}

class _LiquidBottomNavigationBarState extends State<LiquidBottomNavigationBar>
    with RouteAware {
  late bool _useNative;
  bool isChecking = false; // No longer need async checking
  MethodChannel? _eventChannel;
  MethodChannel? _scrollChannel;
  double _lastScrollOffset = 0.0;
  bool _isTopRoute = true;
  int? _currentViewId; // Track the current native view ID
  late int _instanceId; // Unique ID for hot restart support

  @override
  void initState() {
    super.initState();
    _instanceId = LiquidBottomNavigationBar._nextInstanceId;
    // Check iOS version synchronously - no need for async
    _useNative = _determineNativeSupport();
    // Set _nativeState immediately so handleScroll can find us
    LiquidBottomNavigationBar._nativeState = this;
    // Notify callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNativeDetected?.call(_useNative);
    });
    // Event and scroll channels will be setup after platform view is created
  }

  bool _determineNativeSupport() {
    if (widget.forceCustomBar) return false;
    if (!Platform.isIOS) return false;
    // Parse major iOS version (e.g., "Version 18.0.1" -> 18)
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    final major = match != null ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
    return major >= 26;
  }

  void _setupEventChannel(int viewId) {
    // Clear old handler if exists
    _eventChannel?.setMethodCallHandler(null);
    // Create unique event channel per viewId
    _eventChannel = MethodChannel('liquid_tabbar_minimize/events_$viewId');
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
  void didUpdateWidget(covariant LiquidBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update native labels when locale changes (only if native view is ready)
    if (_useNative && _scrollChannel != null && _currentViewId != null) {
      final oldLabels = oldWidget.items.map((e) => e.label ?? '').toList();
      final newLabels = widget.items.map((e) => e.label ?? '').toList();

      if (!_listEquals(oldLabels, newLabels)) {
        _scrollChannel!
            .invokeMethod('updateLabels', {'labels': newLabels})
            .catchError((error) {
              // Silently ignore - native view may have been recreated
            });
      }
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    if (LiquidBottomNavigationBar._nativeState == this) {
      LiquidBottomNavigationBar._nativeState = null;
    }
    _currentViewId = null;
    _eventChannel?.setMethodCallHandler(null);
    LiquidRouteObserver.instance.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final primaryAnim = route?.animation ?? kAlwaysCompleteAnimation;
    final secondaryAnim =
        route?.secondaryAnimation ?? kAlwaysDismissedAnimation;

    // Listen to route animations so we can hide/show instantly during transitions
    return AnimatedBuilder(
      animation: Listenable.merge([primaryAnim, secondaryAnim]),
      builder: (context, child) {
        final shouldHide = _shouldHideForRoute(route);
        // Use Visibility to hide bar instead of removing from tree
        // This preserves native UiKitView state during navigation
        return Visibility(
          visible: !shouldHide,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: false,
          child: _buildBar(context),
        );
      },
    );
  }

  bool _shouldHideForRoute(ModalRoute<dynamic>? route) {
    if (route == null) return false;

    if (!_isTopRoute) return true;
    if (!route.isCurrent) return true;
    if ((route.animation?.value ?? 1) < 1) return true;
    if ((route.secondaryAnimation?.value ?? 0) > 0.01) return true;
    return false;
  }

  Widget _buildBar(BuildContext context) {
    if (isChecking) {
      return const SizedBox.shrink();
    }
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    if (widget.forceCustomBar || !_useNative || !Platform.isIOS) {
      return _CustomLiquidBar(
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
        isRtl: isRtl,
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
      String toHex(Color c) {
        // ignore: deprecated_member_use
        final hex = c.value.toRadixString(16).padLeft(8, '0');
        return '#$hex';
      }

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
                    _currentViewId = id;
                    // Use _instanceId for channels to match native side
                    _scrollChannel = MethodChannel(
                      'liquid_tabbar_minimize/scroll_$_instanceId',
                    );
                    _setupEventChannel(_instanceId);
                    LiquidBottomNavigationBar._nativeState = this;
                  },
                  creationParams: {
                    'instanceId': _instanceId,
                    'labels': widget.items.map((e) => e.label ?? '').toList(),
                    'sfSymbols': widget.items.map((e) {
                      final iconData = (e.icon as Icon).icon!;
                      return widget.sfSymbolMapper?.call(iconData) ??
                          'circle.fill';
                    }).toList(),
                    'initialIndex': widget.currentIndex,
                    'enableActionTab': widget.showActionButton,
                    'actionSymbol': actionSFSymbol,
                    'selectedColorHex': toHex(selectedColor),
                    'unselectedColorHex': toHex(unselectedColor),
                    'enableMinimize': widget.enableMinimize,
                    'labelVisibility': widget.labelVisibility.name,
                    'bottomOffset': widget.bottomOffset,
                    'collapseStartOffset': widget.collapseStartOffset,
                    'animationDurationMs':
                        widget.animationDuration.inMilliseconds,
                    'isRtl': isRtl,
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
      isRtl: isRtl,
    );
  }

  void _sendScrollToNative(double offset, double delta) {
    if (_scrollChannel == null || !widget.enableMinimize) return;
    _scrollChannel!
        .invokeMethod('onScroll', {'offset': offset, 'delta': delta})
        .catchError((error) {});
  }

  // ----- RouteAware -----
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      LiquidRouteObserver.instance.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    _setTopRoute(true);
  }

  @override
  void didPopNext() {
    _setTopRoute(true);
  }

  @override
  void didPushNext() {
    _setTopRoute(false);
  }

  @override
  void didPop() {
    _setTopRoute(false);
  }

  void _setTopRoute(bool value) {
    if (_isTopRoute != value) {
      setState(() => _isTopRoute = value);
    }
  }
}

// Custom liquid tab bar (iOS < 26 or forceCustomBar: true)
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
  final bool isRtl;

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
    required this.isRtl,
  });

  @override
  State<_CustomLiquidBar> createState() => _CustomLiquidBarState();
}

class _CustomLiquidBarState extends State<_CustomLiquidBar> {
  bool _isCollapsed = false;
  MethodChannel? _nativeChannel;
  int? _viewId;
  DateTime _ignoreScrollUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _expandedLockUntil = DateTime.fromMillisecondsSinceEpoch(0);

  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    LiquidBottomNavigationBar._customState = this;
    _initNativeChannel();
    _initItemKeys();
  }

  @override
  void dispose() {
    if (LiquidBottomNavigationBar._customState == this) {
      LiquidBottomNavigationBar._customState = null;
    }
    super.dispose();
  }

  void _initItemKeys() {
    _itemKeys.clear();
    for (int i = 0; i < widget.items.length; i++) {
      _itemKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(covariant _CustomLiquidBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enableMinimize && _isCollapsed) {
      setState(() {
        _isCollapsed = false;
      });
    }
    if (widget.items.length != oldWidget.items.length) {
      _initItemKeys();
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
    final double topSnapOffset = widget.collapseStartOffset.clamp(
      0,
      double.infinity,
    );
    final double pixelThreshold = topSnapOffset;

    // Ignore sudden large jumps (e.g., after tab switch)
    if (delta.abs() > 120) return;

    // Collapse after threshold on downward scroll
    if (!_isCollapsed && delta > 4 && offset > pixelThreshold) {
      setState(() {
        _isCollapsed = true;
      });
      return;
    }

    // Expand only when we return to the top area
    if (_isCollapsed && offset <= topSnapOffset) {
      setState(() {
        _isCollapsed = false;
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
    final bool isRtl = widget.isRtl;

    // Custom bar spacing: small positive gap so action pill is separated but close.
    final double actionSpacing = widget.showActionButton ? 8.0 : 0.0;
    final double fullWidth = MediaQuery.of(context).size.width;
    final double barWidth = widget.showActionButton
        ? fullWidth - 32 - widget.height - actionSpacing
        : fullWidth - 32;
    final double barWidthClamped = math.max(barWidth, widget.height);
    final double bottomGap =
        widget.bottomOffset + 16; // lift both slightly from home indicator

    return SizedBox(
      height: widget.height + bottomGap,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomGap),
        child: Stack(
          alignment: isRtl ? Alignment.bottomLeft : Alignment.bottomRight,
          children: [
            Align(
              alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft,
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
                          : _buildExpandedTabBar(
                              isDark,
                              selectedColor,
                              unselectedColor,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showActionButton)
              Align(
                alignment: isRtl ? Alignment.bottomLeft : Alignment.bottomRight,
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
                                size: 30,
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

  Widget _buildExpandedTabBar(
    bool isDark,
    Color selectedColor,
    Color unselectedColor,
  ) {
    // Her item için flex hesapla
    List<int> flexValues = [];
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final isSelected = widget.currentIndex == i;
      final showLabel = item.label != null && _shouldShowLabel(isSelected);
      final int labelLength = item.label?.length ?? 0;
      final int extraFlex = showLabel ? (labelLength > 6 ? 2 : 1) : 0;
      flexValues.add(10 + (isSelected ? extraFlex : 0));
    }

    final totalFlex = flexValues.reduce((a, b) => a + b);
    final bool isRtl = widget.isRtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

          // Seçili item'ın pozisyonunu ve genişliğini hesapla
          double selectedLeft = 0;
          double selectedWidth = 0;

          for (int i = 0; i < widget.items.length; i++) {
            final itemWidth = (availableWidth * flexValues[i]) / totalFlex;
            if (i < widget.currentIndex) {
              selectedLeft += itemWidth;
            }
            if (i == widget.currentIndex) {
              selectedWidth = itemWidth;
            }
          }

          // RTL için pozisyonu ters çevir
          final double pillLeft = isRtl
              ? availableWidth - selectedLeft - selectedWidth + 2
              : selectedLeft + 2;

          return Stack(
            children: [
              // Sliding pill background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: pillLeft,
                top: 0,
                bottom: 0,
                width: selectedWidth - 4,
                child: Container(
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
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              // Tab items - RTL için Directionality ile sarmalıyoruz
              Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Row(
                  children: List.generate(widget.items.length, (index) {
                    final item = widget.items[index];
                    final isSelected = widget.currentIndex == index;
                    final showLabel =
                        item.label != null && _shouldShowLabel(isSelected);

                    return Expanded(
                      flex: flexValues[index],
                      child: GestureDetector(
                        onTap: () {
                          _pauseScrollHandling(
                            const Duration(milliseconds: 1200),
                          );
                          _lockExpanded(const Duration(milliseconds: 1200));
                          widget.onTap?.call(index);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: isSelected ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child: IconTheme(
                                  data: IconThemeData(
                                    size: 22,
                                    color: isSelected
                                        ? selectedColor
                                        : unselectedColor,
                                  ),
                                  child: item.icon,
                                ),
                              ),
                              if (showLabel) ...[
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? selectedColor
                                        : unselectedColor,
                                    letterSpacing: 0.1,
                                  ),
                                  child: Text(
                                    item.label!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
            ],
          );
        },
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
