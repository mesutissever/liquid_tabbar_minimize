import Flutter
import UIKit

// MARK: - Models

@available(iOS 14.0, *)
struct NativeTabItemData: Identifiable {
    let id: Int
    let title: String
    let symbol: String
}

// MARK: - Platform View

@available(iOS 14.0, *)
class SwiftUITabBarPlatformView: NSObject, FlutterPlatformView, UITabBarControllerDelegate {
    private let container: UIView
    private let eventChannel: FlutterMethodChannel
    private var scrollChannel: FlutterMethodChannel?
    private weak var tabBarController: UITabBarController?
    private var isMinimized = false
    private weak var tabBarWrapper: UIView?
    private var expandedConstraints: [NSLayoutConstraint] = []
    private var collapsedConstraints: [NSLayoutConstraint] = []
    private var baseConstraints: [NSLayoutConstraint] = []
    private var originalItemWidth: CGFloat?
    private var originalItemSpacing: CGFloat?
    private var originalItemPositioningRaw: Int?
    private var originalViewControllers: [UIViewController]?
    private var originalTitlesByTag: [Int: String?] = [:]
    private var originalTitleAttrsNormal: [NSAttributedString.Key: Any] = [:]
    private var originalTitleAttrsSelected: [NSAttributedString.Key: Any] = [:]
    private var originalAppearance: UITabBarAppearance?
    private weak var collapsedView: UIVisualEffectView?
    private weak var collapsedIconView: UIImageView?
    private var selectedTintColor: UIColor = .systemBlue
    private let collapsedSize: CGFloat = 105

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        container = UIView(frame: frame)
        container.backgroundColor = .clear

        eventChannel = FlutterMethodChannel(
            name: "liquid_tabbar_minimize/events",
            binaryMessenger: messenger
        )
        scrollChannel = FlutterMethodChannel(
            name: "liquid_tabbar_minimize/scroll_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        scrollChannel?.setMethodCallHandler { [weak self] call, result in
            guard
                call.method == "onScroll",
                let args = call.arguments as? [String: Any],
                let offset = args["offset"] as? Double,
                let delta = args["delta"] as? Double,
                let threshold = args["threshold"] as? Double
            else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.handleScroll(offset: offset, delta: delta, threshold: threshold)
            result(nil)
        }

        setupTabBar(args: args)
    }

    private func setupTabBar(args: Any?) {
        let items = Self.parseItems(args: args)
        let includeAction = Self.parseActionFlag(args: args)
        let actionSymbol = Self.parseActionSymbol(args: args)
        let selectedColor = Self.parseSelectedColor(args: args)
        selectedTintColor = selectedColor
        let initialIndex = (args as? [String: Any])?["initialIndex"] as? Int ?? 0

        let tabController = UITabBarController()
        tabController.delegate = self
        tabController.tabBar.tintColor = selectedColor

        var controllers: [UIViewController] = items.map { item in
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            vc.tabBarItem = UITabBarItem(
                title: item.title,
                image: UIImage(systemName: item.symbol),
                tag: item.id
            )
            return vc
        }

        if includeAction {
            let actionVC = UIViewController()
            actionVC.view.backgroundColor = .clear
            actionVC.tabBarItem = UITabBarItem(
                title: nil,
                image: UIImage(systemName: actionSymbol.isEmpty ? "magnifyingglass" : actionSymbol),
                tag: -1
            )
            controllers.append(actionVC)
        }

        tabController.viewControllers = controllers
        if initialIndex >= 0 && initialIndex < controllers.count {
            tabController.selectedIndex = initialIndex
        }
        originalViewControllers = controllers
        if let items = tabController.tabBar.items {
            for item in items {
                originalTitlesByTag[item.tag] = item.title
            }
        }

        let tabBar = tabController.tabBar
        tabBar.isTranslucent = true
        tabBar.backgroundColor = .clear
        tabBar.barTintColor = .clear
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterialDark)
            appearance.backgroundColor = UIColor.black.withAlphaComponent(0.15)
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }

        tabBar.layer.cornerRadius = 24
        tabBar.clipsToBounds = true
        // Kaybolan etiketleri geri getirebilmek için başlangıç title attr'larını sakla
        if #available(iOS 15.0, *) {
            let stacked = tabBar.standardAppearance.stackedLayoutAppearance
            originalTitleAttrsNormal = stacked.normal.titleTextAttributes
            originalTitleAttrsSelected = stacked.selected.titleTextAttributes
            originalAppearance = tabBar.standardAppearance.copy() as? UITabBarAppearance
        }

        tabController.view.translatesAutoresizingMaskIntoConstraints = false
        tabController.view.backgroundColor = .clear

        // ÖNCE tabController'ı hierarchy'ye ekle
        if let parent = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {

            parent.addChild(tabController)
            
            // Wrapper view for tab bar animation
            let wrapper = UIView()
            wrapper.backgroundColor = .clear
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(wrapper)
            wrapper.addSubview(tabController.view)
            
            let leading = wrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16)
            let trailing = wrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
            let bottom = wrapper.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -8)
            // Yükseklik collapsedSize ile eşitlenirse daraltmada gerçek bir daire korunur
            let height = wrapper.heightAnchor.constraint(equalToConstant: collapsedSize)
            let collapsedWidth = wrapper.widthAnchor.constraint(equalToConstant: collapsedSize)

            // Çökük durumda gösterilecek blur kapsül + ikon
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
            blur.translatesAutoresizingMaskIntoConstraints = false
            blur.layer.cornerRadius = collapsedSize / 2
            blur.clipsToBounds = true
            blur.isHidden = true
            blur.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            blur.layer.borderWidth = 1
            blur.layer.shadowColor = UIColor.black.cgColor
            blur.layer.shadowOpacity = 0.25
            blur.layer.shadowRadius = 8
            blur.layer.shadowOffset = CGSize(width: 0, height: 6)

            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .center
            iconView.tintColor = selectedTintColor
            blur.contentView.addSubview(iconView)

            wrapper.addSubview(blur)

            NSLayoutConstraint.activate([
                bottom,
                height,
                
                tabController.view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                tabController.view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                tabController.view.topAnchor.constraint(equalTo: wrapper.topAnchor),
                tabController.view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

                blur.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                blur.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                blur.widthAnchor.constraint(equalToConstant: collapsedSize),
                blur.heightAnchor.constraint(equalToConstant: collapsedSize),

                iconView.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
            ])
            
            tabBarWrapper = wrapper
            baseConstraints = [bottom, height]
            expandedConstraints = [leading, trailing]
            collapsedConstraints = [leading, collapsedWidth]
            collapsedView = blur
            collapsedIconView = iconView
            NSLayoutConstraint.activate(baseConstraints + expandedConstraints)
            tabController.didMove(toParent: parent)
        }

        self.tabBarController = tabController
        self.originalItemWidth = tabController.tabBar.itemWidth
        self.originalItemSpacing = tabController.tabBar.itemSpacing
        self.originalItemPositioningRaw = tabController.tabBar.itemPositioning.rawValue
    }

    func view() -> UIView { container }

    // Scroll'dan gelen manual minimize
    private func handleScroll(offset: Double, delta: Double, threshold: Double) {
        guard let wrapper = tabBarWrapper else { return }
        let pixelThreshold = threshold * 1000.0

        if offset <= 0 {
            expandTabBar(wrapper)
        } else if delta > 0 && offset > pixelThreshold && !isMinimized {
            collapseTabBar(wrapper)
        } else if delta < 0 && isMinimized {
            expandTabBar(wrapper)
        }
    }

    private func collapseTabBar(_ wrapper: UIView) {
        guard let tabBar = tabBarController?.tabBar else { return }
        isMinimized = true
        NSLayoutConstraint.deactivate(expandedConstraints)
        NSLayoutConstraint.activate(baseConstraints + collapsedConstraints)

        // Yalnızca seçili buton açık, diğerlerini gizle
        let selectedItem = tabBar.selectedItem ?? tabBarController?.selectedViewController?.tabBarItem
        let selectedTag = selectedItem?.tag
        // Tab bar controller'daki diğer VC'leri geçici kaldır
        if originalViewControllers == nil {
            originalViewControllers = tabBarController?.viewControllers
        }
        if let selectedVC = tabBarController?.selectedViewController {
            tabBarController?.viewControllers = [selectedVC]
        }

        var anyShown = false
        for subview in tabBar.subviews {
            guard let control = subview as? UIControl,
                  let item = control.value(forKey: "item") as? UITabBarItem else { continue }
            let isSelected = (selectedItem != nil && item === selectedItem) || (selectedTag != nil && item.tag == selectedTag)
            control.isHidden = !isSelected
            control.alpha = isSelected ? 1.0 : 0.0
            if isSelected {
                tabBar.bringSubviewToFront(control)
            }
            anyShown = anyShown || isSelected
        }
        if !anyShown {
            for subview in tabBar.subviews {
                if let control = subview as? UIControl {
                    control.isHidden = false
                    control.alpha = 1.0
                }
            }
        }

        // Başlıkları sakla ama görünür kalsın (etiketleri gizlemiyoruz)
        tabBar.items?.forEach { item in
            originalTitlesByTag[item.tag] = item.title
        }
        // Layout değerlerini değiştirme, native kalsın
        tabBar.isHidden = false
        tabBar.alpha = 1.0
        tabBar.isUserInteractionEnabled = true
        collapsedView?.isHidden = true
        collapsedView?.alpha = 0.0

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            wrapper.alpha = 0.9
            tabBar.layoutIfNeeded()
            self.container.layoutIfNeeded()
        }
    }

    private func expandTabBar(_ wrapper: UIView) {
        guard isMinimized, let tabBar = tabBarController?.tabBar else { return }
        isMinimized = false
        NSLayoutConstraint.deactivate(collapsedConstraints)
        NSLayoutConstraint.activate(baseConstraints + expandedConstraints)

        for subview in tabBar.subviews {
            if String(describing: type(of: subview)) == "UITabBarButton" {
                subview.isHidden = false
                subview.alpha = 1.0
            }
        }
        // Blur kapsülü gizle, tab bar'ı geri aç
        collapsedView?.isHidden = true
        collapsedView?.alpha = 0.0
        tabBar.isHidden = false
        tabBar.alpha = 1.0
        tabBar.isUserInteractionEnabled = true

        if let raw = originalItemPositioningRaw,
           let positioning = UITabBar.ItemPositioning(rawValue: raw) {
            tabBar.itemPositioning = positioning
        } else {
            tabBar.itemPositioning = .automatic
        }
        if let width = originalItemWidth { tabBar.itemWidth = width }
        if let spacing = originalItemSpacing { tabBar.itemSpacing = spacing }
        if let originals = originalViewControllers {
            tabBarController?.viewControllers = originals
        }
        restoreAppearance(on: tabBar)
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn]) {
            wrapper.alpha = 1.0
            tabBar.layoutIfNeeded()
            self.container.layoutIfNeeded()
        } completion: { _ in
            // Tüm item'ların başlıklarını geri yükle
            tabBar.items?.forEach { item in
                if let saved = self.originalTitlesByTag[item.tag] {
                    item.title = saved
                }
                item.titlePositionAdjustment = .zero
                item.setTitleTextAttributes(
                    self.originalTitleAttrsNormal.isEmpty ? [.foregroundColor: UIColor.label] : self.originalTitleAttrsNormal,
                    for: .normal
                )
                item.setTitleTextAttributes(
                    self.originalTitleAttrsSelected.isEmpty ? [.foregroundColor: self.selectedTintColor] : self.originalTitleAttrsSelected,
                    for: .selected
                )
            }
            tabBar.setNeedsLayout()
            tabBar.layoutIfNeeded()
        }
    }

    private func applyCollapsedAppearance(to tabBar: UITabBar) {
        if #available(iOS 15.0, *) {
            let appearance = tabBar.standardAppearance.copy() as! UITabBarAppearance
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
            appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 30)
            appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 30)
            appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
            appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        } else {
            tabBar.items?.forEach { item in
                item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 30)
                item.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .normal)
                item.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: .selected)
            }
        }
    }

    private func restoreAppearance(on tabBar: UITabBar) {
        if #available(iOS 15.0, *) {
            if let original = originalAppearance {
                tabBar.standardAppearance = original
                tabBar.scrollEdgeAppearance = original
            } else {
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                tabBar.standardAppearance = appearance
                tabBar.scrollEdgeAppearance = appearance
            }
        } else {
            tabBar.items?.forEach { item in
                if let saved = originalTitlesByTag[item.tag] {
                    item.title = saved
                }
                item.titlePositionAdjustment = .zero
                item.setTitleTextAttributes(originalTitleAttrsNormal.isEmpty ? [.foregroundColor: UIColor.label] : originalTitleAttrsNormal, for: .normal)
                item.setTitleTextAttributes(originalTitleAttrsSelected.isEmpty ? [.foregroundColor: selectedTintColor] : originalTitleAttrsSelected, for: .selected)
            }
        }
    }

    // Seçili tab ikonunu blur kapsüle kopyala
    private func updateCollapsedIcon() {
        guard let iconView = collapsedIconView else { return }
        let selectedItem = tabBarController?.tabBar.selectedItem ?? tabBarController?.selectedViewController?.tabBarItem
        iconView.image = selectedItem?.image?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = selectedTintColor
    }

    // Tab seçimlerini Flutter'a yansıt
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let tag = viewController.tabBarItem.tag
        if tag == -1 {
            eventChannel.invokeMethod("onActionTapped", arguments: nil)
            return false
        }
        eventChannel.invokeMethod("onTabChanged", arguments: tag)
        return true
    }

    deinit {
        scrollChannel?.setMethodCallHandler(nil)
        tabBarController?.willMove(toParent: nil)
        tabBarController?.removeFromParent()
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

    static func parseSelectedColor(args: Any?) -> UIColor {
        guard let dict = args as? [String: Any],
              let hexString = dict["selectedColorHex"] as? String else {
            return UIColor.systemBlue
        }
        var hex = hexString.replacingOccurrences(of: "#", with: "")
        if hex.count == 6 { hex = "FF" + hex }
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let a = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
        let r = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x000000FF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: max(a, 1.0))
    }

    static func parseLabelVisibility(args: Any?) -> String {
        (args as? [String: Any])?["labelVisibility"] as? String ?? "always"
    }

    static func defaultItems() -> [NativeTabItemData] {
        return [
            NativeTabItemData(id: 0, title: "Home", symbol: "house.fill"),
            NativeTabItemData(id: 1, title: "Explore", symbol: "globe"),
            NativeTabItemData(id: 2, title: "Settings", symbol: "gearshape.fill"),
        ]
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
        SwiftUITabBarPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
