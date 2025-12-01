# Liquid TabBar Minimize

A polished Flutter bottom bar with scroll-to-minimize, native iOS 26+ support, and a frosted-glass custom bar for everything else (iOS <26 & Android).

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue) ![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue)

## Demos
- Custom bar (iOS <26 / Android)
  
  ![Custom Bar](assets/ios18.gif)

- Native bar (iOS 26+)
  
  ![Native Bar](assets/ios26.gif)

## Highlights
- Native SwiftUI tab bar on iOS 26+; custom glassmorphism bar on older iOS and Android
- Scroll-to-minimize with tunable threshold and start offset (or disable entirely)
- Configurable colors, height, label visibility, and optional action button
- SF Symbol mapping for native bar

## Install

```yaml
dependencies:
  liquid_tabbar_minimize: ^1.0.0
```
```bash
flutter pub get
```

## Quick Start

```dart
import 'package:liquid_tabbar_minimize/liquid_tabbar_minimize.dart';

LiquidBottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
  showActionButton: true,
  actionIcon: (const Icon(Icons.add), 'plus'),
  onActionTap: () => debugPrint('Action tapped'),
  labelVisibility: LabelVisibility.always,
);
```

### Navigation observers (for native bar + instant hide)
Add the provided `LiquidRouteObserver` to your app so the native tab bar hides immediately when a modal/page is pushed:
```dart
MaterialApp(
  navigatorObservers: [
    YourRouteObserver(),          // e.g., FirebaseAnalyticsObserver
    LiquidRouteObserver.instance, // required for instant hide
  ],
  home: const HomePage(),
);
```

### Scroll wiring (custom bar)
Forward scroll deltas so minimize/expand reacts:
```dart
double _lastScroll = 0;

NotificationListener<ScrollNotification>(
  onNotification: (n) {
    if (n is ScrollUpdateNotification) {
      final offset = n.metrics.pixels;
      final delta = offset - _lastScroll;
      LiquidBottomNavigationBar.handleScroll(offset, delta);
      _lastScroll = offset;
    }
    return false;
  },
  child: ListView(...),
);
```

## Advanced Options
```dart
LiquidBottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
    BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
  sfSymbolMapper: (icon) {
    if (icon == Icons.home) return 'house.fill';
    if (icon == Icons.explore) return 'globe';
    return 'circle.fill';
  },
  showActionButton: true,
  actionIcon: (const Icon(Icons.search), 'magnifyingglass'),
  onActionTap: () => debugPrint('Action'),
  selectedItemColor: Colors.blue,
  unselectedItemColor: Colors.grey,
  height: 68,
  bottomOffset: 8,
  labelVisibility: LabelVisibility.selectedOnly,
  // Minimize tuning
  enableMinimize: true,          // false keeps bar always expanded
  collapseStartOffset: 20,       // px before minimize kicks in (0 = immediate)
  forceCustomBar: false,         // true = always use custom bar
  animationDuration: Duration(milliseconds: 250), // minimize/expand anim
);
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `currentIndex` | `int` | required | Currently selected tab index |
| `items` | `List<BottomNavigationBarItem>` | required | Tab items (2-5) |
| `onTap` | `ValueChanged<int>?` | null | Tab selection callback |
| `showActionButton` | `bool` | false | Show optional action button |
| `actionIcon` | `(Icon, String)?` | null | Action icon (Flutter icon, SF Symbol for native) |
| `onActionTap` | `VoidCallback?` | null | Action button callback |
| `selectedItemColor` | `Color?` | theme primary | Color for selected tab/action |
| `unselectedItemColor` | `Color?` | auto | Color for unselected tabs/action |
| `height` | `double` | 68 | Tab bar height |
| `bottomOffset` | `double` | 0 | Lift bar above home indicator |
| `labelVisibility` | `LabelVisibility` | always | Label display mode |
| `sfSymbolMapper` | `Function?` | null | Map IconData to SF Symbols (native) |
| `collapseStartOffset` | `double` | 20.0 | Pixels before minimize applies (0 = immediate) |
| `animationDuration` | `Duration` | 250ms | Animation duration for minimize/expand |
| `forceCustomBar` | `bool` | false | Force custom bar on iOS 26+ |
| `enableMinimize` | `bool` | true | Keep bar expanded if false |

## Label Visibility
```dart
enum LabelVisibility { always, selectedOnly, never }
```
Supported in both custom and native bars.

## iOS Native (26+)
- Native minimize behavior and blur
- SF Symbols support via `sfSymbolMapper`
- Honors `labelVisibility`, colors, action button, minimize toggles

## Compatibility
- iOS 14+ (native minimize auto on 26+)
- Android (custom bar)

## Example App
See [`example/`](example/) for a runnable demo with multiple screens and scroll wiring.

## License
MIT — see [LICENSE](LICENSE).

## Support
If this package helps you, consider buying me a coffee: https://buymeacoffee.com/mesisse
