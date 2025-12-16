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
- Animated pill indicator with adaptive tab widths so long labels stay readable
- Scroll-to-minimize with tunable threshold and start offset (or disable entirely)
- Configurable colors, height, label visibility, and optional action button
- SF Symbol mapping for native bar
- RTL aware: auto mirrors layout/semantics in both native and custom bars
- RTL-native animation/spacing: action pill and collapse direction swap correctly when RTL is active
- Android is fully Flutter-rendered (no native code required)

## Install

```yaml
dependencies:
  liquid_tabbar_minimize: ^1.0.9
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
  items: [
    LiquidTabItem(
      widget: Icon(Icons.home_outlined),
      selectedWidget: Icon(Icons.home),  // Optional: shown when selected
      sfSymbol: 'house',
      selectedSfSymbol: 'house.fill',    // Optional: native iOS selected
      label: 'Home',
    ),
    LiquidTabItem(
      widget: Icon(Icons.search),
      sfSymbol: 'magnifyingglass',
      label: 'Search',
    ),
    LiquidTabItem(
      widget: Icon(Icons.settings_outlined),
      selectedWidget: Icon(Icons.settings),
      sfSymbol: 'gearshape',
      selectedSfSymbol: 'gearshape.fill',
      label: 'Settings',
    ),
  ],
  showActionButton: true,
  actionButton: ActionButtonConfig(const Icon(Icons.add), 'plus'),
  onActionTap: () => debugPrint('Action tapped'),
  labelVisibility: LabelVisibility.always,
);
```

### Using Asset Images for Action Button
```dart
actionButton: ActionButtonConfig.asset('assets/search.png'),
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

### RTL support
No extra config: if your app runs with `TextDirection.rtl`/RTL locale, both native and custom bars mirror automatically (labels, icons, action pill, and animations stay aligned).

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

### Custom SF Symbols (iOS)
You can use custom SF Symbols created in Apple's SF Symbols app alongside system symbols.

**Step 1: Export from SF Symbols App**
1. Open SF Symbols app and create/customize your symbol
2. Select your symbol and go to **File → Export Symbol**
3. Export as **SVG** format

**Step 2: Add to Xcode Project**
1. In Xcode, open your iOS project's `Assets.xcassets`
2. Create a new folder with `.symbolset` extension (e.g., `myicon.symbolset`)
3. Add your exported SVG file and a `Contents.json`:

```
ios/Runner/Assets.xcassets/
└── myicon.symbolset/
    ├── Contents.json
    └── myicon.svg
```

**Contents.json:**
```json
{
  "info": { "author": "xcode", "version": 1 },
  "symbols": [{ "filename": "myicon.svg", "idiom": "universal" }]
}
```

**Step 3: Use in Flutter**
```dart
// For tab items
LiquidTabItem(
  widget: Icon(Icons.star),
  sfSymbol: 'myicon',  // Your custom symbol name
  label: 'Custom',
),

// For action button
actionButton: ActionButtonConfig(Icon(Icons.star), 'myicon'),
```

> **Note:** The plugin automatically tries system SF Symbol first, then falls back to your custom symbol from Assets.xcassets.

## Advanced Options
```dart
LiquidBottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  items: [
    LiquidTabItem(widget: Icon(Icons.home), sfSymbol: 'house.fill', label: 'Home'),
    LiquidTabItem(widget: Icon(Icons.explore), sfSymbol: 'globe', label: 'Explore'),
    LiquidTabItem(widget: Icon(Icons.star), sfSymbol: 'star.fill', label: 'Favorites'),
    LiquidTabItem(widget: Icon(Icons.settings), sfSymbol: 'gearshape.fill', label: 'Settings'),
  ],
  showActionButton: true,
  // Option 1: Widget + SF Symbol
  actionButton: ActionButtonConfig(const Icon(Icons.search), 'magnifyingglass'),
  // Option 2: Asset for both Flutter and native iOS
  // actionButton: ActionButtonConfig.asset('assets/custom_icon.png'),
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
| `items` | `List<LiquidTabItem>` | required | Tab items with widget, sfSymbol, and label |
| `onTap` | `ValueChanged<int>?` | null | Tab selection callback |
| `showActionButton` | `bool` | false | Show optional action button |
| `actionButton` | `ActionButtonConfig?` | null | Action button config - `ActionButtonConfig(Widget, sfSymbol)` or `.asset(path)` |
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
- Android (Flutter-rendered custom bar, declared as Dart-only plugin)

## Example App
See [`example/`](example/) for a runnable demo with multiple screens and scroll wiring.

## License
MIT — see [LICENSE](LICENSE).

## Support
If this package helps you, consider buying me a coffee: https://buymeacoffee.com/mesisse
