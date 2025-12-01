import 'package:flutter/widgets.dart';

/// Paylaşımlı RouteObserver; MaterialApp.router kullanıyorsanız observers'a ekleyin.
class LiquidRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  LiquidRouteObserver._();
  static final LiquidRouteObserver instance = LiquidRouteObserver._();
}
