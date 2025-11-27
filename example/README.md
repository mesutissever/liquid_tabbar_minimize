# Example App

This app showcases `liquid_tabbar_minimize` with:
- Custom vs native iOS tab bar (auto-detects iOS 26+)
- Action button that switches to a search tab
- Scroll-to-minimize with sample lists/grids
- Configurable colors, label visibility, and `enableMinimize` toggle

## Run

```bash
cd example
flutter run
```

Change the tab bar behavior in `example/lib/main.dart`:
- `enableMinimize: false` to keep the bar always expanded
- `forceCustomBar: true` to bypass native iOS bar (use custom everywhere)
- `selectedItemColor` / `unselectedItemColor` to recolor tabs and action button
