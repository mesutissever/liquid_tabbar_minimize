# 1.0.6
* **iOS 26+ Fix**: Fixed native tab bar event channel issue when widget is recreated (e.g., after `Get.offAllNamed` navigation). Each platform view now uses a unique channel ID.
* Improved cleanup of old native views before creating new instances.

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
