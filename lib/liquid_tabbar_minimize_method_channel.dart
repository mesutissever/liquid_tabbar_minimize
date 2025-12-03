import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'liquid_tabbar_minimize_platform_interface.dart';

/// An implementation of [LiquidTabbarMinimizePlatform] that uses method channels.
class MethodChannelLiquidTabbarMinimize extends LiquidTabbarMinimizePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('liquid_tabbar_minimize');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
