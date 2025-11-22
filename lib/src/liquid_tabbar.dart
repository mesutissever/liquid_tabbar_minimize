import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liquid_tab_item.dart';

class LiquidTabBar extends StatefulWidget {
  final List<LiquidTabItem> items;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;
  final bool showActionTab;
  final String actionIcon;
  final VoidCallback? onActionTap;
  final double bottomPadding;
  final double tabBarHeight;

  const LiquidTabBar({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onTabChanged,
    this.showActionTab = false,
    this.actionIcon = 'magnifyingglass',
    this.onActionTap,
    this.bottomPadding = 20,
    this.tabBarHeight = 70,
  }) : assert(items.length >= 2 && items.length <= 5);

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  late int _currentIndex;
  MethodChannel? _channel;
  bool _useNativeTabBar = false;
  bool _isCheckingVersion = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkIOSVersion();
  }

  Future<void> _checkIOSVersion() async {
    if (Platform.isIOS) {
      try {
        final version = Platform.operatingSystemVersion;
        final match = RegExp(r'Version (\d+)\.').firstMatch(version);
        if (match != null) {
          final major = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (major >= 26) {
            setState(() {
              _useNativeTabBar = true;
              _isCheckingVersion = false;
            });
            _channel = const MethodChannel('liquid_tabbar_minimize/events');
            _channel!.setMethodCallHandler(_handleMethodCall);
            return;
          }
        }
      } catch (e) {
        debugPrint('iOS version check failed: $e');
      }
    }
    setState(() {
      _useNativeTabBar = false;
      _isCheckingVersion = false;
    });
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
    if (_isCheckingVersion) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_useNativeTabBar) {
      return _buildIOSNative();
    }
    return _buildCustomTabBar();
  }

  Widget _buildIOSNative() {
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

  Widget _buildCustomTabBar() {
    return _CustomScrollMinimizeTabBar(
      items: widget.items,
      initialIndex: _currentIndex,
      showActionTab: widget.showActionTab,
      actionIcon: widget.actionIcon,
      bottomPadding: widget.bottomPadding,
      tabBarHeight: widget.tabBarHeight,
      onTabChanged: (index) {
        setState(() => _currentIndex = index);
        widget.onTabChanged?.call(index);
      },
      onActionTap: widget.onActionTap,
    );
  }
}

class _CustomScrollMinimizeTabBar extends StatefulWidget {
  final List<LiquidTabItem> items;
  final int initialIndex;
  final bool showActionTab;
  final String actionIcon;
  final ValueChanged<int> onTabChanged;
  final VoidCallback? onActionTap;
  final double bottomPadding;
  final double tabBarHeight;

  const _CustomScrollMinimizeTabBar({
    required this.items,
    required this.initialIndex,
    required this.showActionTab,
    required this.actionIcon,
    required this.onTabChanged,
    this.onActionTap,
    required this.bottomPadding,
    required this.tabBarHeight,
  });

  @override
  State<_CustomScrollMinimizeTabBar> createState() =>
      _CustomScrollMinimizeTabBarState();
}

class _CustomScrollMinimizeTabBarState
    extends State<_CustomScrollMinimizeTabBar> {
  late int _currentIndex;
  double _tabBarHeight = 1.0;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _handleScroll(double offset, double delta) {
    const threshold = 5.0;
    if (offset <= 0) {
      if (_tabBarHeight != 1.0) {
        setState(() => _tabBarHeight = 1.0);
      }
    } else if (delta.abs() < threshold) {
      return;
    } else {
      final shouldShow = delta < 0;
      final newHeight = shouldShow ? 1.0 : 0.0;
      if (_tabBarHeight != newHeight) {
        setState(() => _tabBarHeight = newHeight);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionItems = [...widget.items];
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final offset = notification.metrics.pixels;
            final delta = offset - _lastScrollOffset;
            _handleScroll(offset, delta);
            _lastScrollOffset = offset;
          }
          return false;
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [
            ...actionItems.map((item) => item.child),
            if (widget.showActionTab)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _mapIcon(widget.actionIcon),
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Search',
                      style: TextStyle(fontSize: 24, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height:
            _tabBarHeight *
            (widget.tabBarHeight + safeAreaBottom + widget.bottomPadding),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: safeAreaBottom + widget.bottomPadding,
          ),
          child: Row(
            children: [
              // Main TabBar
              Expanded(
                flex: widget.showActionTab ? 4 : 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: widget.tabBarHeight,
                      decoration: BoxDecoration(
                        color:
                            (theme.brightness == Brightness.dark
                                    ? Colors.black.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.7))
                                .withOpacity(0.8),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(widget.items.length, (index) {
                            final item = widget.items[index];
                            final isSelected = _currentIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  widget.onTabChanged(index);
                                  setState(() {
                                    _currentIndex = index;
                                    _tabBarHeight = 1.0;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (theme.brightness == Brightness.dark
                                              ? Colors.white.withOpacity(0.15)
                                              : Colors.black.withOpacity(0.08))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(18),
                                    border: isSelected
                                        ? Border.all(
                                            color:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white.withOpacity(0.25)
                                                : Colors.black.withOpacity(
                                                    0.12,
                                                  ),
                                            width: 0.5,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _mapIcon(item.icon),
                                        size: isSelected ? 26 : 23,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : (theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.white.withOpacity(
                                                      0.7,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.6,
                                                    )),
                                      ),
                                      if (item.label.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : (theme.brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                            .withOpacity(0.7)
                                                      : Colors.black
                                                            .withOpacity(0.6)),
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

              // Action Tab (Ayrı)
              if (widget.showActionTab) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    widget.onActionTap?.call();
                    setState(() {
                      _currentIndex = widget.items.length;
                      _tabBarHeight = 1.0;
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: widget.tabBarHeight,
                        height: widget.tabBarHeight,
                        decoration: BoxDecoration(
                          color: _currentIndex == widget.items.length
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : (theme.brightness == Brightness.dark
                                        ? Colors.black.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.7))
                                    .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: _currentIndex == widget.items.length
                                ? theme.colorScheme.primary.withOpacity(0.4)
                                : (theme.brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.08)),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _mapIcon(widget.actionIcon),
                          size: 24,
                          color: _currentIndex == widget.items.length
                              ? theme.colorScheme.primary
                              : (theme.brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.black.withOpacity(0.6)),
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
    );
  }

  IconData _mapIcon(String sfSymbol) {
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
      'magnifyingglass': Icons.search,
    };
    return mapping[sfSymbol] ?? Icons.circle;
  }
}
