import Flutter
import SwiftUI
import UIKit

// MARK: - Models

@available(iOS 14.0, *)
struct NativeTabItemData: Identifiable {
    let id: Int
    let title: String
    let symbol: String
}

// MARK: - SwiftUI Liquid Glass Action Button

@available(iOS 15.0, *)
struct LiquidGlassActionButton: View {
    let symbol: String
    let action: () -> Void
    let size: CGFloat
    let tint: Color
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundColor(tint.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
    }
}

// MARK: - Platform View

@available(iOS 14.0, *)
class SwiftUITabBarPlatformView: NSObject, FlutterPlatformView {
    private let container: UIView
    private let messenger: FlutterBinaryMessenger
    private var eventChannel: FlutterMethodChannel?
    private var tabBar: UITabBar?
    private var actionHosting: UIHostingController<LiquidGlassActionButton>?

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.container = UIView(frame: frame)
        self.messenger = messenger
        super.init()

        let items = SwiftUITabBarPlatformView.parseItems(args: args)
        let includeAction = SwiftUITabBarPlatformView.parseActionFlag(args: args)
        let actionSymbol = SwiftUITabBarPlatformView.parseActionSymbol(args: args)
        let selectedColor = SwiftUITabBarPlatformView.parseSelectedColor(args: args)

        let evtChannel = FlutterMethodChannel(
            name: "liquid_tabbar_minimize/events",
            binaryMessenger: messenger
        )
        self.eventChannel = evtChannel

        // --- Native UITabBar ---
        let nativeTabBar = UITabBar()
        nativeTabBar.translatesAutoresizingMaskIntoConstraints = false
        nativeTabBar.delegate = self
        nativeTabBar.tintColor = UIColor(selectedColor)
        nativeTabBar.unselectedItemTintColor = UIColor.gray
        nativeTabBar.isTranslucent = true

        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
            appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
            appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
            appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance
            nativeTabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                nativeTabBar.scrollEdgeAppearance = appearance
            }
        }

        var tabBarItems: [UITabBarItem] = []
        for item in items {
            let tabItem = UITabBarItem(
                title: item.title,
                image: UIImage(systemName: item.symbol),
                tag: item.id
            )
            tabBarItems.append(tabItem)
        }

        nativeTabBar.items = tabBarItems
        nativeTabBar.selectedItem = tabBarItems.first
        self.tabBar = nativeTabBar

        container.backgroundColor = .clear
        container.addSubview(nativeTabBar)

        NSLayoutConstraint.activate([
            nativeTabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nativeTabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nativeTabBar.topAnchor.constraint(equalTo: container.topAnchor),
            nativeTabBar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // --- Action button ---
        if includeAction, #available(iOS 15.0, *) {
            let buttonSize: CGFloat = 44
            let buttonView = LiquidGlassActionButton(
                symbol: actionSymbol,
                action: { [weak self] in
                    self?.eventChannel?.invokeMethod("onActionTapped", arguments: nil)
                },
                size: buttonSize,
                tint: selectedColor
            )

            let hosting = UIHostingController(rootView: buttonView)
            hosting.view.backgroundColor = .clear
            hosting.view.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(hosting.view)
            container.bringSubviewToFront(hosting.view)
            self.actionHosting = hosting

            NSLayoutConstraint.activate([
                hosting.view.widthAnchor.constraint(equalToConstant: buttonSize),
                hosting.view.heightAnchor.constraint(equalToConstant: buttonSize),
                hosting.view.trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                hosting.view.centerYAnchor.constraint(equalTo: nativeTabBar.centerYAnchor, constant: -8)
            ])
        }
    }

    func view() -> UIView {
        return container
    }

    // MARK: - Helpers

    static func parseItems(args: Any?) -> [NativeTabItemData] {
        guard let dict = args as? [String: Any],
              let labels = dict["labels"] as? [String],
              let symbols = dict["sfSymbols"] as? [String] else {
            return SwiftUITabBarPlatformView.defaultItems()
        }
        let count = min(labels.count, symbols.count)
        if count == 0 { return SwiftUITabBarPlatformView.defaultItems() }
        var items: [NativeTabItemData] = []
        for i in 0..<count {
            items.append(NativeTabItemData(id: i, title: labels[i], symbol: symbols[i]))
        }
        return items
    }

    static func parseActionFlag(args: Any?) -> Bool {
        guard let dict = args as? [String: Any],
              let flag = dict["enableActionTab"] as? Bool else {
            return false
        }
        return flag
    }

    static func parseActionSymbol(args: Any?) -> String {
        guard let dict = args as? [String: Any],
              let symbol = dict["actionSymbol"] as? String else {
            return "magnifyingglass"
        }
        return symbol
    }

    static func parseSelectedColor(args: Any?) -> Color {
        guard let dict = args as? [String: Any],
              let hexString = dict["selectedColorHex"] as? String else {
            return Color.blue
        }
        var hex = hexString.replacingOccurrences(of: "#", with: "")
        if hex.count == 6 { hex = "FF" + hex }
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let a = Double((rgbValue & 0xFF000000) >> 24) / 255.0
        let r = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x000000FF) / 255.0
        return Color(red: r, green: g, blue: b, opacity: max(a, 1.0))
    }

    static func defaultItems() -> [NativeTabItemData] {
        return [
            NativeTabItemData(id: 0, title: "Home", symbol: "house.fill"),
            NativeTabItemData(id: 1, title: "Explore", symbol: "globe"),
            NativeTabItemData(id: 2, title: "Settings", symbol: "gearshape.fill"),
        ]
    }
}

// MARK: - UITabBarDelegate

@available(iOS 14.0, *)
extension SwiftUITabBarPlatformView: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        eventChannel?.invokeMethod("onTabChanged", arguments: item.tag)
    }
}

// MARK: - Factory

@available(iOS 14.0, *)
class SwiftUITabBarViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return SwiftUITabBarPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
