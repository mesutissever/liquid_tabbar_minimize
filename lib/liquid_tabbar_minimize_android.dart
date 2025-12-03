import 'liquid_tabbar_minimize_platform_interface.dart';

/// Dart-only Android implementation; the bar renders fully in Flutter on Android.
class LiquidTabbarMinimizeAndroid extends LiquidTabbarMinimizePlatform {
  /// Registers this class as the default instance for Android.
  static void registerWith() {
    LiquidTabbarMinimizePlatform.instance = LiquidTabbarMinimizeAndroid();
  }

  @override
  Future<String?> getPlatformVersion() async => null;
}
