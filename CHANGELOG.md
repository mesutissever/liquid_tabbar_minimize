# 1.0.9
* **BREAKING**: `LiquidTabItem` replaces `BottomNavigationBarItem` - each item now has `widget`, `sfSymbol`, and `label`
* **BREAKING**: `sfSymbolMapper` parameter removed - SF Symbol is now part of `LiquidTabItem`
* **Custom SF Symbols Support**: Added support for custom SF Symbols created in SF Symbols app
  * Both tab items and action button now support custom SF Symbols from Assets.xcassets
  * If system SF Symbol not found, automatically loads custom symbol from app bundle
* **ActionButtonConfig**: New class with cleaner API:
  * `ActionButtonConfig(Widget, String)` - Any widget + SF Symbol for native iOS
  * `ActionButtonConfig.asset(String)` - Single asset path for both Flutter and native iOS
* **Template Rendering**: Action button asset images support `useTemplateRendering` option for tint color matching
* **Removed**: Old `LiquidTabBar` widget removed - use `LiquidBottomNavigationBar` instead

# 1.0.8
* **Navigation Fix**: Fixed scroll-to-minimize not working after navigating to another page and back. Uses `Visibility` widget to preserve native UiKitView state during route transitions.
* **Initial Render Fix**: Removed async iOS version check delay - tab bar now renders immediately on first frame.
* **Label Timing Fix**: Applied title text attributes immediately when creating UITabBarItem to prevent label flash on initial render.
* **Layout Fix**: Set `itemPositioning = .fill` for consistent tab widths and prevent label truncation.

# 1.0.7
* **Hot Restart Fix**: Fixed scroll-to-minimize not working after hot restart in development. Each widget instance now uses a unique timestamp-based ID for channel communication.

# 1.0.6
* **iOS 26+ Fix**: Fixed native tab bar event channel issue when widget is disposed and recreated during route transitions (e.g., route replacement, logout/login flows). Each platform view now uses a unique channel ID to ensure reliable communication.
* **Locale Support**: Fixed issue where tab bar labels did not update when the app locale changed. Labels now dynamically update via MethodChannel when locale or translations change.
* Improved cleanup of previous native view instances when the widget is rebuilt.

# 1.0.5
* Fix RTL native layout/taps: action pill and main bar swap sides correctly; taps routed to correct targets in RTL minimize state.

# 1.0.4
* Custom bar rebuilt with a sliding pill background and adaptive tab widths so long labels stay readable while the selected tab gets breathing room.
* Action button/icon sizing refined to better match the condensed pill layout; overall spacing is smoother across tabs.
* RTL support: custom and native bars mirror automatically based on `TextDirection`; native action pill + main bar swap sides with RTL spacing.
* Native view marked non-opaque and RTL-aware semantics; Android declared as Dart-only plugin; removed noisy native version debug print.

# 1.0.3
* Added `LiquidRouteObserver` and `RouteAware` so the native tab bar hides instantly during pushes/modals.
* Example wires both app-level and Liquid observers.
* Fixed duplicate `dispose` and cleaned comments/imports.

## 1.0.2
* Added `LiquidRouteObserver` and `RouteAware` so the native tab bar hides instantly during pushes/modals.
* Example wires both app-level and Liquid observers.
* Fixed duplicate `dispose` and cleaned comments/imports.

## 1.0.1
* Bug fix


## 1.0.0

* Initial release
* iOS 26+ native tab bar support with minimize behavior
* Custom tab bar for iOS <26 and Android
* Scroll-to-minimize with adjustable threshold
* Frosted glass effect with blur
* Label visibility modes (always, selectedOnly, never)
* Optional action button
* Customizable colors and styling
* SF Symbols support for iOS
