import 'package:flutter/widgets.dart';

/// Shared RouteObserver; add to `navigatorObservers` (including MaterialApp.router).
class LiquidRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  LiquidRouteObserver._();
  static final LiquidRouteObserver instance = LiquidRouteObserver._();
}
