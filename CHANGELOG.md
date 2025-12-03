# 1.0.3
* RTL support: custom and native bars mirror automatically based on `TextDirection`, including semantics on iOS.
* Native iOS view marked non-opaque and given RTL-aware semantic attributes.
* Docs updated (README) to note RTL and latest install version.

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
