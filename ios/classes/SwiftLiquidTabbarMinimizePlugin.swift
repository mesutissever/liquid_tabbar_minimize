import Flutter
import UIKit
import SwiftUI

public class SwiftLiquidTabbarMinimizePlugin: NSObject, FlutterPlugin {
  private var presentedSwiftUITabVC: UIViewController?
  private var overlayWindow: UIWindow?
  private weak var previousKeyWindow: UIWindow?
  private var eventChannel: FlutterMethodChannel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = LiquidTabBarViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "liquid_tabbar_minimize/native_tabbar")

    // SwiftUI-based tab bar with Apple's minimize behavior (iOS 18+)
    if #available(iOS 14.0, *) {
      let swiftUIFactory = SwiftUITabBarViewFactory(messenger: registrar.messenger())
      registrar.register(swiftUIFactory, withId: "liquid_tabbar_minimize/swiftui_tabbar")
    }

    // Global method channel for full-screen SwiftUI presentation
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
    // iOS 26 öncesinde de izin ver (minimize yok)
    guard #available(iOS 18.0, *) else {
      result(FlutterError(code: "unavailable", message: "Requires iOS 18+.", details: nil))
      return
    }
    let windowScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    let delegateWindow = UIApplication.shared.delegate?.window ?? nil
    let rootWindow: UIWindow? = windowScene?.windows.first ?? delegateWindow ?? nil
    let items = SwiftUITabBarPlatformView.parseItems(args: args)
    let includeAction = SwiftUITabBarPlatformView.parseActionFlag(args: args)
    let actionSymbol = SwiftUITabBarPlatformView.parseActionSymbol(args: args)
    let selectedColor = SwiftUITabBarPlatformView.parseSelectedColor(args: args)
    let labelVisibility = SwiftUITabBarPlatformView.parseLabelVisibility(args: args)
    
    let rootView = SwiftUITabBarScaffold(
      items: items,
      includeActionTab: includeAction,
      actionSymbol: actionSymbol,
      selectedColor: selectedColor,
      labelVisibility: labelVisibility,
      onActionTap: { [weak self] in
        self?.eventChannel?.invokeMethod("onActionTapped", arguments: nil)
      },
      onTabChanged: { [weak self] index in
        self?.eventChannel?.invokeMethod("onTabChanged", arguments: index)
      }
    )
    let hostVC = UIHostingController(rootView: rootView)
    hostVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
    presentedSwiftUITabVC = hostVC

    if #available(iOS 26.0, *) {
      // minimize animasyonu için overlay window
      if let scene = rootWindow?.windowScene ?? windowScene {
        previousKeyWindow = rootWindow
        let newWindow = UIWindow(windowScene: scene)
        newWindow.rootViewController = hostVC
        newWindow.windowLevel = .normal
        newWindow.makeKeyAndVisible()
        overlayWindow = newWindow
        print("[SwiftUITabBar] overlay (iOS 26+) aktif")
        result(nil)
        return
      }
    }

    // iOS 18–25 veya overlay başarısız
    if let rootVC = rootWindow?.rootViewController {
      rootVC.present(hostVC, animated: true) { result(nil) }
    } else {
      result(FlutterError(code: "no_root_vc", message: "Root view controller not found", details: nil))
    }
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
