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
    let onActionTap: () -> Void
    let onTabChanged: (Int) -> Void
    @State private var selection: Int = 0
    @State private var lastNonActionSelection: Int = 0

    var body: some View {
        TabView(selection: $selection) {(selection: $selection) {
            ForEach(items) { item in
                Tab(value: item.id) {
                    navigationContainer {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {lignment: .leading, spacing: 12) {
                                ForEach(item.articles) { article in
                                    VStack(alignment: .leading, spacing: 6) {: 6) {
                                        Text(article.title).font(.headline)
                                        Text(article.subtitle).font(.subheadline).foregroundColor(.secondary)e).foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)ing(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)lignment: .leading)
                                }
                            }
                            .navigationTitle(item.title)ing(.bottom, 100) // Tab bar için boşluk
                        }
                    } label: {
                        Label(item.title, systemImage: item.symbol)
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
            .tint(selectedColor) // Seçili tab rengi
        }
        .modifier(MinimizeBehaviorModifier())
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
    }modifier(MinimizeBehaviorModifier())

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {    @ViewBuilder
        if #available(iOS 16.0, *) { navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            NavigationStack { content() }
        } else {t() }
            NavigationView { content() }
        }gationView { content() }
    }
}

@available(iOS 18.0, *)
private struct MinimizeBehaviorModifier: ViewModifier {@available(iOS 18.0, *)
    func body(content: Content) -> some View {BehaviorModifier: ViewModifier {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {havior(.onScrollDown)
            content
        }ent
    }
}

// MARK: - iOS 14-17 Fallback
// MARK: - iOS 14-17 Fallback
@available(iOS 14.0, *)
struct SwiftUITabBarFallback: View {@available(iOS 14.0, *)
    let items: [NativeTabItemData]lback: View {

    var body: some View {
        TabView {    var body: some View {
            ForEach(items) { item in
                navigationContainer {ch(items) { item in
                    ScrollView {{
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(item.articles) { article inck(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title).font(.headline)cing: 6) {
                                    Text(article.subtitle).font(.subheadline).foregroundColor(.secondary)
                                }dline).foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)16)
                            }y, alignment: .leading)
                        }
                    }
                    .navigationTitle(item.title)
                }navigationTitle(item.title)
                .tabItem {
                    Label(item.title, systemImage: item.symbol)tabItem {
                }item.title, systemImage: item.symbol)
                .tag(item.id)
            }tag(item.id)
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {    @ViewBuilder
        if #available(iOS 16.0, *) { navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            NavigationStack { content() }
        } else {t() }
            NavigationView { content() }
        }gationView { content() }
    }
}

// MARK: - Platform View
// MARK: - Platform View
@available(iOS 14.0, *)
class SwiftUITabBarPlatformView: NSObject, FlutterPlatformView {@available(iOS 14.0, *)
    private let container: UIViewformView: NSObject, FlutterPlatformView {
    private let messenger: FlutterBinaryMessenger
    private var eventChannel: FlutterMethodChannel?rBinaryMessenger
    private weak var hostingController: UIHostingController<AnyView>?l?
ntroller<AnyView>?
    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.container = UIView(frame: frame)    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()

        let items = SwiftUITabBarPlatformView.parseItems(args: args)
        let includeAction = SwiftUITabBarPlatformView.parseActionFlag(args: args)        let items = SwiftUITabBarPlatformView.parseItems(args: args)
        let actionSymbol = SwiftUITabBarPlatformView.parseActionSymbol(args: args)g(args: args)
        let selectedColor = SwiftUITabBarPlatformView.parseSelectedColor(args: args))
s)
        let channel = FlutterMethodChannel(
            name: "liquid_tabbar_minimize/events",        let channel = FlutterMethodChannel(
            binaryMessenger: messengervents",
        )
        self.eventChannel = channel
elf.eventChannel = channel
        let rootView: AnyView
        if #available(iOS 18.0, *) {        let rootView: AnyView
            rootView = AnyView(0, *) {
                SwiftUITabBarScaffold(
                    items: items,affold(
                    includeActionTab: includeAction,
                    actionSymbol: actionSymbol,Tab: includeAction,
                    selectedColor: selectedColor,
                    onActionTap: { [weak channel] inr,
                        channel?.invokeMethod("onActionTapped", arguments: nil) in
                    },ionTapped", arguments: nil)
                    onTabChanged: { [weak channel] index in
                        channel?.invokeMethod("onTabChanged", arguments: index)TabChanged: { [weak channel] index in
                    }", arguments: index)
                )
            )
        } else {
            rootView = AnyView(SwiftUITabBarFallback(items: items))e {
        }View = AnyView(SwiftUITabBarFallback(items: items))

        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear        let host = UIHostingController(rootView: rootView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = hostskIntoConstraints = false

        if let parentVC = UIApplication.shared.delegate?.window??.rootViewController {
            parentVC.addChild(host)        if let parentVC = UIApplication.shared.delegate?.window??.rootViewController {
        }

        container.addSubview(host.view)
        NSLayoutConstraint.activate([        container.addSubview(host.view)
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),onstraint(equalTo: container.leadingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])chor),

        if let parentVC = UIApplication.shared.delegate?.window??.rootViewController {
            host.didMove(toParent: parentVC)        if let parentVC = UIApplication.shared.delegate?.window??.rootViewController {
        }
    }

    func view() -> UIView {
        container    func view() -> UIView {
    }

    // MARK: - Helpers
    // MARK: - Helpers
    static func parseItems(args: Any?) -> [NativeTabItemData] {
        guard let dict = args as? [String: Any],    static func parseItems(args: Any?) -> [NativeTabItemData] {
              let labels = dict["labels"] as? [String],
              let symbols = dict["sfSymbols"] as? [String] else {tring],
            return SwiftUITabBarPlatformView.defaultItems()ng] else {
        }

        let count = min(labels.count, symbols.count)
        if count == 0 {        let count = min(labels.count, symbols.count)
            return SwiftUITabBarPlatformView.defaultItems()
        }tUITabBarPlatformView.defaultItems()

        let nativeDataArray = dict["nativeData"] as? [[Any]] ?? []
        let nativeDataArray = dict["nativeData"] as? [[Any]] ?? []
        var items: [NativeTabItemData] = []
        for i in 0..<count {        var items: [NativeTabItemData] = []
            let articles: [Article]
            rticle]
            // Flutter'dan gelen data varsa onu kullan
            if i < nativeDataArray.count && !nativeDataArray[i].isEmpty {// Flutter'dan gelen data varsa onu kullan
                articles = nativeDataArray[i].compactMap { item inaArray[i].isEmpty {
                    guard let itemDict = item as? [String: Any],
                          let title = itemDict["title"] as? String,
                          let subtitle = itemDict["subtitle"] as? String else {ng,
                        return niltring else {
                    }
                    return Article(title: title, subtitle: subtitle)
                }eturn Article(title: title, subtitle: subtitle)
            } else {
                // Fallback: sample datae {
                articles = SwiftUITabBarPlatformView.sampleArticles(prefix: labels[i])allback: sample data
            }PlatformView.sampleArticles(prefix: labels[i])
            
            let item = NativeTabItemData(id: i, title: labels[i], symbol: symbols[i], articles: articles)
            items.append(item)let item = NativeTabItemData(id: i, title: labels[i], symbol: symbols[i], articles: articles)
        }
        return items
    }eturn items

    static func parseActionFlag(args: Any?) -> Bool {
        guard let dict = args as? [String: Any],    static func parseActionFlag(args: Any?) -> Bool {
              let flag = dict["enableActionTab"] as? Bool else {
            return false as? Bool else {
        }
        return flag
    }eturn flag

    static func parseActionSymbol(args: Any?) -> String {
        guard let dict = args as? [String: Any],    static func parseActionSymbol(args: Any?) -> String {
              let symbol = dict["actionSymbol"] as? String else {
            return "magnifyingglass"as? String else {
        }
        return symbol
    }eturn symbol

    static func parseSelectedColor(args: Any?) -> Color {
        guard let dict = args as? [String: Any],    static func parseSelectedColor(args: Any?) -> Color {
              let hexString = dict["selectedColorHex"] as? String else {
            return Color.bluerHex"] as? String else {
        }
        
        let hex = hexString.replacingOccurrences(of: "#", with: "")
        var rgbValue: UInt64 = 0let hex = hexString.replacingOccurrences(of: "#", with: "")
        Scanner(string: hex).scanHexInt64(&rgbValue)
        nHexInt64(&rgbValue)
        let a = Double((rgbValue & 0xFF000000) >> 24) / 255.0
        let r = Double((rgbValue & 0x00FF0000) >> 16) / 255.0let a = Double((rgbValue & 0xFF000000) >> 24) / 255.0
        let g = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x000000FF) / 255.0
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }return Color(red: r, green: g, blue: b, opacity: a)

    static func defaultItems() -> [NativeTabItemData] {
        return [    static func defaultItems() -> [NativeTabItemData] {
            NativeTabItemData(
                id: 0,veTabItemData(
                title: "Home",
                symbol: "house.fill", "Home",
                articles: sampleArticles(prefix: "Appointment").fill",
            ),les(prefix: "Appointment")
            NativeTabItemData(
                id: 1,tiveTabItemData(
                title: "Explore",
                symbol: "globe", "Explore",
                articles: sampleArticles(prefix: "Guide")
            ),Articles(prefix: "Guide")
            NativeTabItemData(
                id: 2,tiveTabItemData(
                title: "Settings",
                symbol: "gearshape.fill", "Settings",
                articles: sampleArticles(prefix: "Setting").fill",
            ),prefix: "Setting")
        ]
    }

    static func sampleArticles(prefix: String) -> [Article] {
        return (1...50).map { idx in    static func sampleArticles(prefix: String) -> [Article] {
            Article(
                title: "\(prefix) \(idx)",
                subtitle: "Subtitle \(idx)"e: "\(prefix) \(idx)",
            )"
        }
    }
}

@available(iOS 14.0, *)
class SwiftUITabBarViewFactory: NSObject, FlutterPlatformViewFactory {@available(iOS 14.0, *)
    private let messenger: FlutterBinaryMessengerFactory: NSObject, FlutterPlatformViewFactory {

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger    init(messenger: FlutterBinaryMessenger) {
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return SwiftUITabBarPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    }
}
