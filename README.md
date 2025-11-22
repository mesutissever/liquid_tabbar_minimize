# Liquid TabBar Minimize

A beautiful, customizable Flutter tab bar with scroll-to-minimize behavior. Automatically detects iOS 26+ for native minimize support, with a stunning custom implementation for older iOS versions and Android.

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue)

## Features

✨ **Automatic Platform Detection**
- iOS 26+: Native SwiftUI tab bar with native minimize
- iOS <26 & Android: Beautiful custom implementation

🎨 **Customizable Design**
- Frosted glass effect with blur
- Adjustable colors, opacity, and borders
- Label visibility modes (always, selectedOnly, never)
- Optional action button (search, add, etc.)

📱 **Scroll-to-Minimize**
- Smooth collapse animation on scroll down
- Expand on scroll up
- Adjustable threshold

🚀 **Easy to Use**
- Simple API
- Minimal configuration
- Works with any Flutter app

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  liquid_tabbar_minimize: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Example

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
  pages: [
    HomePage(),
    SearchPage(),
    SettingsPage(),
  ],
)
```

### Advanced Example

```dart
LiquidBottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
    BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
  pages: [HomePage(), ExplorePage(), FavoritesPage(), SettingsPage()],
  
  // iOS 26+ native support
  itemCounts: const [10, 50, 50, 50], // Item counts for native iOS data
  sfSymbolMapper: (icon) {
    if (icon == Icons.home) return 'house.fill';
    if (icon == Icons.explore) return 'globe';
    return 'circle.fill';
  },
  
  // Customization
  selectedItemColor: Colors.blue,
  unselectedItemColor: Colors.grey,
  height: 68,
  labelVisibility: LabelVisibility.selectedOnly,
  
  // Optional action button
  showActionButton: true,
  actionIcon: (const Icon(Icons.add), 'plus'),
  onActionTap: () => print('Action tapped'),
  
  // Scroll minimize settings
  minimizeThreshold: 0.1, // 10% scroll threshold
  forceCustomBar: false, // Use custom bar even on iOS 26+
)
```

### Scroll Handling

For custom bar scroll minimize to work, pass scroll events:

```dart
class _PageState extends State<Page> {
  double _lastScrollOffset = 0;

  void _handleScroll(double offset, double delta) {
    final barState = LiquidBottomNavigationBar.barKey.currentState;
    barState?.handleScroll(offset, offset - _lastScrollOffset);
    _lastScrollOffset = offset;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _handleScroll(notification.metrics.pixels, notification.metrics.pixels);
        }
        return false;
      },
      child: ListView(...),
    );
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `currentIndex` | `int` | required | Currently selected tab index |
| `items` | `List<BottomNavigationBarItem>` | required | Tab items (2-5 items) |
| `pages` | `List<Widget>` | required | Page widgets for each tab |
| `onTap` | `ValueChanged<int>?` | null | Tab selection callback |
| `selectedItemColor` | `Color?` | primary | Color for selected tab |
| `unselectedItemColor` | `Color?` | grey | Color for unselected tabs |
| `height` | `double` | 68 | Tab bar height |
| `labelVisibility` | `LabelVisibility` | always | Label display mode |
| `showActionButton` | `bool` | false | Show optional action button |
| `actionIcon` | `(Icon, String)?` | null | Action button icon (Flutter icon, SF Symbol) |
| `onActionTap` | `VoidCallback?` | null | Action button callback |
| `itemCounts` | `List<int>?` | null | Item counts for iOS 26+ native data |
| `sfSymbolMapper` | `Function?` | null | Map IconData to SF Symbols |
| `minimizeThreshold` | `double` | 0.1 | Scroll threshold (0.0-1.0) |
| `forceCustomBar` | `bool` | false | Force custom bar on iOS 26+ |

## Label Visibility

```dart
enum LabelVisibility {
  always,        // Show all labels
  selectedOnly,  // Show only selected tab label
  never,         // Hide all labels
}
```

## iOS Native Support

For iOS 26+, the package automatically uses native SwiftUI tab bar with:
- Native minimize behavior
- SF Symbols support
- Native blur and styling

To provide data for native tabs, use `itemCounts` and optionally `sfSymbolMapper`.

## Platform Compatibility

- ✅ iOS 14+
- ✅ Android (API 21+)
- ✅ Native iOS 26+ minimize
- ✅ Custom minimize for iOS <26 & Android

## Example App

Check the [example](example/) folder for a complete demo app.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Created with ❤️ by the Flutter community

---

**Note:** iOS 26 native minimize requires iOS 26.0+ simulator/device. For testing on older iOS versions, set `forceCustomBar: true`.