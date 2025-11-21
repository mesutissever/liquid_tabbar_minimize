import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'liquid_tabbar_minimize_method_channel.dart';

abstract class LiquidTabbarMinimizePlatform extends PlatformInterface {
  /// Constructs a LiquidTabbarMinimizePlatform.
  LiquidTabbarMinimizePlatform() : super(token: _token);

  static final Object _token = Object();

  static LiquidTabbarMinimizePlatform _instance = MethodChannelLiquidTabbarMinimize();

  /// The default instance of [LiquidTabbarMinimizePlatform] to use.
  ///
  /// Defaults to [MethodChannelLiquidTabbarMinimize].
  static LiquidTabbarMinimizePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LiquidTabbarMinimizePlatform] when
  /// they register themselves.
  static set instance(LiquidTabbarMinimizePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
