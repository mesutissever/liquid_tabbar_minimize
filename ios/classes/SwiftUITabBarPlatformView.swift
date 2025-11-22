import Flutter
import SwiftUI
import UIKit

// NOTE:
// iOS 18.6 çalışmaması iki sebepli:
// 1) Xcode'da iOS 18.6 runtime yüklü değil (Platform Runtimes bölümünden indirin, sonra yeni iPhone 16 iOS 18.6 simulator ekleyin).
// 2) presentSwiftUITabBar içinde (SwiftLiquidTabbarMinimizePlugin.swift) guard #available(iOS 26.0, *) kullanıldığı için iOS 18.x bloklanıyor.
//    O guard'ı şöyle değiştirin:
//    guard #available(iOS 18.0, *) else {
//        result(FlutterError(code: "unavailable", message: "Requires iOS 18+.", details: nil))
//        return
//    }
//    iOS 26 dışı sürümlerde minimize yok ama TabView normal çalışır.

// MARK: - Models

@available(iOS 14.0, *)
struct Article: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

@available(iOS 14.0, *)
struct NativeTabItemData: Identifiable {
    let id: Int
    let title: String
    let symbol: String
    let articles: [Article]
}

// MARK: - iOS 18+ Tab API Scaffold

@available(iOS 18.0, *)
struct SwiftUITabBarScaffold: View {
    let items: [NativeTabItemData]
    let includeActionTab: Bool
    let actionSymbol: String
    let selectedColor: Color
    let labelVisibility: String // "selectedOnly", "always", "never"
    let onActionTap: () -> Void
    let onTabChanged: (Int) -> Void
    let minimizeThreshold: Double // Son sırada
    @State private var selection: Int = 0
    @State private var lastNonActionSelection: Int = 0

    var body: some View {
        Group {
            TabView(selection: $selection) {
                ForEach(items) { item in
                    Tab(value: item.id) {
                        navigationContainer {
                            GeometryReader { geometry in
                                ScrollViewReader { scrollProxy in
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 12) {
                                            ForEach(item.articles) { article in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text(article.title).font(.headline)
                                                    Text(article.subtitle).font(.subheadline).foregroundColor(.secondary)
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 16)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        .background(GeometryReader { contentGeometry in
                                            Color.clear.preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: contentGeometry.frame(in: .named("scrollView")).minY
                                            )
                                        })
                                    }
                                    .coordinateSpace(name: "scrollView")
                                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                                        // Threshold kontrolü
                                        let contentHeight = Double(item.articles.count) * 50.0
                                        let scrollPercentage = abs(offset) / contentHeight
                                        
                                        if scrollPercentage > minimizeThreshold {
                                            // Minimize edilmeli
                                        }
                                    }
                                }
                            }
                            .navigationTitle(item.title)
                        }
                    } label: {
                        if shouldShowLabel(for: item.id) {
                            Label(item.title, systemImage: item.symbol)
                        } else {
                            Label {
                                Text("")
                            } icon: {
                                Image(systemName: item.symbol)
                            }
                        }
                    }
                }

                if includeActionTab {
                    let symbol = actionSymbol.isEmpty ? "magnifyingglass" : actionSymbol
                    Tab("", systemImage: symbol, value: -1, role: .search) {
                        VStack {
                            Text("Search")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .onAppear {
                let first = items.first?.id ?? 0
                selection = first
                lastNonActionSelection = first
            }
            .onChange(of: selection) { newValue in
                if includeActionTab && newValue == -1 {
                    // Search tab seçildi - callback çağır ama selection'ı değiştirme
                    onActionTap()
                    // Search tab seçili kalsın
                } else if newValue != -1 {
                    // Normal tab seçildi
                    lastNonActionSelection = newValue
                    onTabChanged(newValue)
                }
            }
            .tint(selectedColor) // Seçili tab rengi
        }
        .modifier(MinimizeBehaviorModifier())
    }

    private func shouldShowLabel(for itemId: Int) -> Bool {
        switch labelVisibility {
        case "selectedOnly":
            return selection == itemId
        case "never":
            return false
        default: // "always"
            return true
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
        }
    }
}

@available(iOS 18.0, *)
private struct MinimizeBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - iOS 14-17 Fallback

@available(iOS 14.0, *)
struct SwiftUITabBarFallback: View {
    let items: [NativeTabItemData]

    var body: some View {
        TabView {
            ForEach(items) { item in
                navigationContainer {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(item.articles) { article in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title).font(.headline)
                                    Text(article.subtitle).font(.subheadline).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .navigationTitle(item.title)
                }
                .tabItem {
                    Label(item.title, systemImage: item.symbol)
                }
                .tag(item.id)
            }
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
        }
    }
}

// MARK: - Platform View

@available(iOS 14.0, *)
class SwiftUITabBarPlatformView: NSObject, FlutterPlatformView {
    private let container: UIView
    private let messenger: FlutterBinaryMessenger
    private var eventChannel: FlutterMethodChannel?
    private weak var hostingController: UIHostingController<AnyView>?

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.container = UIView(frame: frame)
        self.messenger = messenger
        super.init()

        let items = SwiftUITabBarPlatformView.parseItems(args: args)
        let includeAction = SwiftUITabBarPlatformView.parseActionFlag(args: args)
        let actionSymbol = SwiftUITabBarPlatformView.parseActionSymbol(args: args)
        let selectedColor = SwiftUITabBarPlatformView.parseSelectedColor(args: args)
        let labelVisibility = SwiftUITabBarPlatformView.parseLabelVisibility(args: args)
        let minimizeThreshold = SwiftUITabBarPlatformView.parseMinimizeThreshold(args: args)

        let channel = FlutterMethodChannel(
            name: "liquid_tabbar_minimize/events",
            binaryMessenger: messenger
        )
        self.eventChannel = channel

        let rootView: AnyView
        if #available(iOS 18.0, *) {
            rootView = AnyView(
                SwiftUITabBarScaffold(
                    items: items,
                    includeActionTab: includeAction,
                    actionSymbol: actionSymbol,
                    selectedColor: selectedColor,
                    labelVisibility: labelVisibility,
                    onActionTap: { [weak channel] in
                        channel?.invokeMethod("onActionTapped", arguments: nil)
                    },
                    onTabChanged: { [weak channel] index in
                        channel?.invokeMethod("onTabChanged", arguments: index)
                    },
                    minimizeThreshold: minimizeThreshold // Son parametre
                )
            )
        } else {
            rootView = AnyView(SwiftUITabBarFallback(items: items))
        }

        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = host

        if let parentVC = UIApplication.shared.delegate?.window??.rootViewController {
            parentVC.addChild(host)
        }

        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if let parentVC = UIApplication.shared.delegate?.window??.rootViewController {
            host.didMove(toParent: parentVC)
        }
    }

    func view() -> UIView {
        container
    }

    // MARK: - Helpers

    static func parseItems(args: Any?) -> [NativeTabItemData] {
        guard let dict = args as? [String: Any],
              let labels = dict["labels"] as? [String],
              let symbols = dict["sfSymbols"] as? [String] else {
            return SwiftUITabBarPlatformView.defaultItems()
        }

        let count = min(labels.count, symbols.count)
        if count == 0 {
            return SwiftUITabBarPlatformView.defaultItems()
        }

        let nativeDataArray = dict["nativeData"] as? [[Any]] ?? []

        var items: [NativeTabItemData] = []
        for i in 0..<count {
            let articles: [Article]
            
            // Flutter'dan gelen data varsa onu kullan
            if i < nativeDataArray.count && !nativeDataArray[i].isEmpty {
                articles = nativeDataArray[i].compactMap { item in
                    guard let itemDict = item as? [String: Any],
                          let title = itemDict["title"] as? String,
                          let subtitle = itemDict["subtitle"] as? String else {
                        return nil
                    }
                    return Article(title: title, subtitle: subtitle)
                }
            } else {
                // Fallback: sample data
                articles = SwiftUITabBarPlatformView.sampleArticles(prefix: labels[i])
            }
            
            let item = NativeTabItemData(id: i, title: labels[i], symbol: symbols[i], articles: articles)
            items.append(item)
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
        
        let hex = hexString.replacingOccurrences(of: "#", with: "")
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        let a = Double((rgbValue & 0xFF000000) >> 24) / 255.0
        let r = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x000000FF) / 255.0
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    static func parseLabelVisibility(args: Any?) -> String {
        guard let dict = args as? [String: Any],
              let visibility = dict["labelVisibility"] as? String else {
            return "always"
        }
        return visibility
    }

    static func parseMinimizeThreshold(args: Any?) -> Double {
        guard let dict = args as? [String: Any],
              let threshold = dict["minimizeThreshold"] as? Double else {
            return 0.1 // Default %10
        }
        return threshold
    }

    static func defaultItems() -> [NativeTabItemData] {
        return [
            NativeTabItemData(
                id: 0,
                title: "Home",
                symbol: "house.fill",
                articles: sampleArticles(prefix: "Appointment")
            ),
            NativeTabItemData(
                id: 1,
                title: "Explore",
                symbol: "globe",
                articles: sampleArticles(prefix: "Guide")
            ),
            NativeTabItemData(
                id: 2,
                title: "Settings",
                symbol: "gearshape.fill",
                articles: sampleArticles(prefix: "Setting")
            ),
        ]
    }

    static func sampleArticles(prefix: String) -> [Article] {
        return (1...50).map { idx in
            Article(
                title: "\(prefix) \(idx)",
                subtitle: "Subtitle \(idx)"
            )
        }
    }
}

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
