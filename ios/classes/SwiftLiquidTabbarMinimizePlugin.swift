import Flutter
import UIKit
import SwiftUI

public class SwiftLiquidTabbarMinimizePlugin: NSObject, FlutterPlugin {
  private var presentedSwiftUITabVC: UIViewController?
  private var overlayWindow: UIWindow?
  private weak var previousKeyWindow: UIWindow?
  private var eventChannel: FlutterMethodChannel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    // SwiftUI-based tab bar (iOS 14+)
    if #available(iOS 14.0, *) {
      let swiftUIFactory = SwiftUITabBarViewFactory(messenger: registrar.messenger())
      registrar.register(swiftUIFactory, withId: "liquid_tabbar_minimize/swiftui_tabbar")
    }

    // Global method channel
    let channel = FlutterMethodChannel(
      name: "liquid_tabbar_minimize/swiftui_presenter",
      binaryMessenger: registrar.messenger()
    )
    let instance = SwiftLiquidTabbarMinimizePlugin()
    instance.eventChannel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "presentSwiftUITabBar":
      presentSwiftUITabBar(args: call.arguments, result: result)
    case "dismissSwiftUITabBar":
      dismissSwiftUITabBar(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentSwiftUITabBar(args: Any?, result: @escaping FlutterResult) {
    // iOS 14+ için basic support
    guard #available(iOS 14.0, *) else {
      result(FlutterError(code: "unavailable", message: "Requires iOS 14+.", details: nil))
      return
    }
    
    result(FlutterError(code: "not_implemented", message: "Use platform view instead", details: nil))
  }

  private func dismissSwiftUITabBar(result: @escaping FlutterResult) {
    guard let presented = presentedSwiftUITabVC else {
      result(nil)
      return
    }
    if let overlay = overlayWindow {
      overlay.isHidden = true
      overlay.windowLevel = .normal
      overlay.rootViewController = nil
      overlayWindow = nil
      presentedSwiftUITabVC = nil
      previousKeyWindow?.makeKeyAndVisible()
      previousKeyWindow = nil
      result(nil)
    } else {
      presented.dismiss(animated: true) {
        result(nil)
      }
      presentedSwiftUITabVC = nil
    }
  }
}
