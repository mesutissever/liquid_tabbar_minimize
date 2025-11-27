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
class SwiftUITabBarPlatformView: NSObject, FlutterPlatformView, UITabBarControllerDelegate, UITabBarDelegate {
    private let container: UIView
    private let eventChannel: FlutterMethodChannel
    private var scrollChannel: FlutterMethodChannel?
    private weak var tabBarController: UITabBarController?
    private var isMinimized = false
    private var bottomOffset: CGFloat = 0

    // Separate action tab bar
    private weak var actionButtonContainer: UIView?
    private weak var actionTabBar: UITabBar?
    private var actionButtonTrailing: NSLayoutConstraint?
    private var actionButtonBottom: NSLayoutConstraint?
    private var actionButtonSize: CGFloat = 0
    private var actionButtonSpacing: CGFloat = 0

    // Ana wrapper
    private weak var tabBarWrapper: UIView?

    // Base constraints
    private var baseConstraints: [NSLayoutConstraint] = []

    // Keep leading/trailing constraints separately so we can switch layouts.
    private var expandedLeading: NSLayoutConstraint?
    private var expandedTrailing: NSLayoutConstraint?
    private var collapsedLeading: NSLayoutConstraint?
    private var collapsedTrailing: NSLayoutConstraint?

    // TabBarController.view constraints
    private var tabViewLeading: NSLayoutConstraint?
    private var tabViewTrailing: NSLayoutConstraint?
    private var tabViewTop: NSLayoutConstraint?
    private var tabViewBottom: NSLayoutConstraint?
    private var tabViewCollapsedWidth: NSLayoutConstraint?

    // Original UITabBar settings
    private var originalItemWidth: CGFloat?
    private var originalItemSpacing: CGFloat?
    private var originalItemPositioningRaw: Int?

    // Orijinal durum
    private var originalViewControllers: [UIViewController]?
    private var originalTitlesByTag: [Int: String?] = [:]
    private var originalTitleAttrsNormal: [NSAttributedString.Key: Any] = [:]
    private var originalTitleAttrsSelected: [NSAttributedString.Key: Any] = [:]
    private var originalAppearance: UITabBarAppearance?
    private var selectedTintColor: UIColor = .systemBlue
    private var unselectedTintColor: UIColor = UIColor.label.withAlphaComponent(0.7)
    private var savedSelectedTag: Int?
    private var expandTapRecognizer: UITapGestureRecognizer?
    private var isTransitioning = false
    private var lastToggleDate: Date = .distantPast
    private var ignoreScrollUntil: Date = .distantPast
    private var expandedLockUntil: Date = .distantPast
    private var enableMinimize: Bool = true

    private var originalTabBarItems: [UITabBarItem]?

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
            print("SCROLL iOS offset=\(offset) delta=\(delta) thr=\(threshold) isMin=\(self?.isMinimized ?? false)")
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
        let unselectedColor = Self.parseUnselectedColor(args: args)
        enableMinimize = Self.parseEnableMinimize(args: args)
        let bottomOffsetArg = Self.parseBottomOffset(args: args)
        selectedTintColor = selectedColor
        unselectedTintColor = unselectedColor
        let initialIndex = (args as? [String: Any])?["initialIndex"] as? Int ?? 0
        actionButtonSize = max(64, UITabBar().sizeThatFits(.zero).height)
        let pillWidth = includeAction ? (actionButtonSize + 20) : 0
        if includeAction {
            // Scale spacing with pill width but clamp so small devices don't overlap too much
            let desiredSpacing = -(min(pillWidth * 0.38, 58))
            actionButtonSpacing = desiredSpacing
        }
        bottomOffset = CGFloat(bottomOffsetArg)

        let tabController = UITabBarController()
        tabController.delegate = self
        tabController.tabBar.tintColor = selectedColor

        if #available(iOS 13.0, *) {
            tabController.tabBar.unselectedItemTintColor = unselectedColor
        }

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

        tabController.viewControllers = controllers
        if initialIndex >= 0 && initialIndex < controllers.count {
            tabController.selectedIndex = initialIndex
        }
        tabController.additionalSafeAreaInsets.bottom = 0
        originalViewControllers = controllers
        if let items = tabController.tabBar.items {
            for item in items { originalTitlesByTag[item.tag] = item.title }
        }

        let tabBar = tabController.tabBar
        tabBar.isTranslucent = true
        tabBar.insetsLayoutMarginsFromSafeArea = false
        tabBar.backgroundColor = .clear
        tabBar.barTintColor = .clear
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        if #available(iOS 13.0, *) {
            tabBar.unselectedItemTintColor = unselectedColor
        }

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterialDark)
            appearance.backgroundColor = UIColor.black.withAlphaComponent(0.15)
            var normalAttrs = appearance.stackedLayoutAppearance.normal.titleTextAttributes
            var selectedAttrs = appearance.stackedLayoutAppearance.selected.titleTextAttributes
            normalAttrs[.foregroundColor] = unselectedColor
            selectedAttrs[.foregroundColor] = selectedColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
            appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
            appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
            appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
            appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance
            let stacked = appearance.stackedLayoutAppearance
            originalTitleAttrsNormal = stacked.normal.titleTextAttributes
            originalTitleAttrsSelected = stacked.selected.titleTextAttributes
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
            originalAppearance = appearance.copy() as? UITabBarAppearance
        } else {
            tabBar.items?.forEach { item in
                item.setTitleTextAttributes([.foregroundColor: unselectedColor], for: .normal)
                item.setTitleTextAttributes([.foregroundColor: selectedColor], for: .selected)
            }
        }

        tabBar.layer.cornerRadius = 24
        tabBar.clipsToBounds = true

        tabController.view.translatesAutoresizingMaskIntoConstraints = false
        tabController.view.backgroundColor = .clear

        if let parent = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {

            parent.addChild(tabController)

            // Main wrapper
            let wrapper = UIView()
            wrapper.backgroundColor = .clear
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(wrapper)
            tabBarWrapper = wrapper

            // Add tab bar view to wrapper at full width initially
            wrapper.addSubview(tabController.view)

            // Leave room for the action pill so it visually connects with the main bar
            let trailingOffsetBase = includeAction ? (pillWidth + actionButtonSpacing) : 0
            let trailingOffset = max(trailingOffsetBase, 4) // keep at least 4px gap

            // Expanded (normal) insets: 2px left, 2px + action gap on the right
            let leadExp = wrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2)
            let trailExp = wrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(2 + trailingOffset))
            // Collapsed (minimized) insets: 2px left, 2px + action gap on the right
            let leadCol = wrapper.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2)
            let trailCol = wrapper.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(2 + trailingOffset))

            let bottom = wrapper.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottomOffset)
            let height = wrapper.heightAnchor.constraint(equalTo: tabController.tabBar.heightAnchor)

            // TabController.view constraints
            let tabLead = tabController.view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor)
            let tabTrail = tabController.view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
            let tabTop   = tabController.view.topAnchor.constraint(equalTo: wrapper.topAnchor)
            let tabBot   = tabController.view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)

            NSLayoutConstraint.activate([
                bottom,
                height,
                tabLead, tabTrail, tabTop, tabBot
            ])

            baseConstraints = [bottom, height]
            expandedLeading = leadExp
            expandedTrailing = trailExp
            collapsedLeading = leadCol
            collapsedTrailing = trailCol

            tabViewLeading = tabLead
            tabViewTrailing = tabTrail
            tabViewTop = tabTop
            tabViewBottom = tabBot

            // Start in expanded mode
            NSLayoutConstraint.activate(baseConstraints + [leadExp, trailExp])

            tabController.didMove(toParent: parent)
        }

        // Separate action tab bar: sits to the right of the main bar, round and label-less
        if includeAction {
            let actionBar = UITabBar(frame: .zero)
            actionBar.translatesAutoresizingMaskIntoConstraints = false
            actionBar.delegate = self
            actionBar.isTranslucent = true
            actionBar.insetsLayoutMarginsFromSafeArea = false
            actionBar.backgroundImage = UIImage()
            actionBar.shadowImage = UIImage()
            actionBar.tintColor = selectedColor
            if #available(iOS 13.0, *) {
                actionBar.unselectedItemTintColor = unselectedColor
            }
            actionBar.items = [
                UITabBarItem(
                    title: nil,
                    image: UIImage(systemName: actionSymbol.isEmpty ? "magnifyingglass" : actionSymbol),
                    tag: -1
                )
            ]
            actionBar.itemPositioning = .automatic
            actionBar.itemWidth = 0
            actionBar.itemSpacing = 0
            actionBar.layer.cornerRadius = pillWidth / 2
            actionBar.clipsToBounds = true

            if #available(iOS 15.0, *) {
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundEffect = UIBlurEffect(style: .systemMaterialDark)
                appearance.backgroundColor = UIColor.black.withAlphaComponent(0.22)
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
                appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
                appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance
                actionBar.standardAppearance = appearance
                actionBar.scrollEdgeAppearance = appearance
            }

            container.addSubview(actionBar)
            actionButtonContainer = actionBar
            actionTabBar = actionBar

            let bottomConst = actionBar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottomOffset)
            let trailingConst = actionBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0)

            NSLayoutConstraint.activate([
                bottomConst,
                trailingConst,
                actionBar.widthAnchor.constraint(equalToConstant: pillWidth),
                actionBar.heightAnchor.constraint(equalToConstant: actionButtonSize)
            ])

            actionButtonBottom = bottomConst
            actionButtonTrailing = trailingConst
        }

        self.tabBarController = tabController
        self.originalItemWidth = tabController.tabBar.itemWidth
        self.originalItemSpacing = tabController.tabBar.itemSpacing
        self.originalItemPositioningRaw = tabController.tabBar.itemPositioning.rawValue
        self.originalTabBarItems = tabController.tabBar.items
    }

    func view() -> UIView { container }

    private func handleScroll(offset: Double, delta: Double, threshold: Double) {
        guard enableMinimize else { return }
        guard let wrapper = tabBarWrapper, !isTransitioning else { return }
        if Date().timeIntervalSince(ignoreScrollUntil) < 0 { return }
        if !isMinimized && Date().timeIntervalSince(expandedLockUntil) < 0 { return }
        let pixelThreshold = threshold * 1000.0
        let topSnapOffset: Double = 20.0

        // Only expand near the very top; avoid reopening near the bottom
        if offset <= topSnapOffset {
            expandTabBar(wrapper)
        } else if delta > 0 && offset > pixelThreshold && !isMinimized {
            collapseTabBar(wrapper)
        } else if delta < 0 && isMinimized && offset <= topSnapOffset {
            expandTabBar(wrapper)
        }
    }

    private func collapseTabBar(_ wrapper: UIView) {
        guard enableMinimize else { return }
        guard !isMinimized, let tbc = tabBarController, let wrapperView = tabBarWrapper else { return }
        if isTransitioning || Date().timeIntervalSince(lastToggleDate) < 0.2 { return }
        isTransitioning = true
        lastToggleDate = Date()
        print("COLLAPSE iOS")
        isMinimized = true

        // Switch insets to collapsed mode
        if let leadExp = expandedLeading, let trailExp = expandedTrailing,
           let leadCol = collapsedLeading, let trailCol = collapsedTrailing {
            NSLayoutConstraint.deactivate([leadExp, trailExp])
            NSLayoutConstraint.activate(baseConstraints + [leadCol, trailCol])
        }

        applyCollapsedAppearance(to: tbc.tabBar)

        // Remember selected tag
        let currentTag = tbc.selectedViewController?.tabBarItem.tag
        savedSelectedTag = currentTag

        // Keep only the selected VC
        if let list = originalViewControllers, let tag = currentTag,
           let selIndex = list.firstIndex(where: { $0.tabBarItem.tag == tag }) {
            let selectedVC = list[selIndex]
            tbc.setViewControllers([selectedVC], animated: false)
            tbc.selectedIndex = 0
        }

        // Shrink tab bar inside the same wrapper
        tabViewTrailing?.isActive = false
        if tabViewCollapsedWidth == nil {
            // Narrow the width (76 -> 64)
            tabViewCollapsedWidth = tbc.view.widthAnchor.constraint(equalToConstant: 105)
        }
        tabViewCollapsedWidth?.isActive = true

        // Single centered icon layout
        tbc.tabBar.itemPositioning = .centered
        tbc.tabBar.itemWidth = 0
        tbc.tabBar.itemSpacing = 0

        tbc.tabBar.setNeedsUpdateConstraints()
        tbc.tabBar.setNeedsLayout()
        tbc.tabBar.layoutIfNeeded()
        wrapperView.setNeedsLayout()
        container.setNeedsLayout()

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            // Rounded corners to half the height (capsule)
            tbc.tabBar.layer.cornerRadius = tbc.tabBar.bounds.height / 2
            wrapperView.alpha = 1.0
            wrapperView.layoutIfNeeded()
            self.container.layoutIfNeeded()
        } completion: { _ in
            self.isTransitioning = false
        }

        // Add tap recognizer so tapping collapsed bar expands it
        if expandTapRecognizer == nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleCollapsedTap))
            tap.cancelsTouchesInView = false
            wrapper.addGestureRecognizer(tap)
            expandTapRecognizer = tap
        }
    }

    private func expandTabBar(_ wrapper: UIView) {
        guard enableMinimize else { return }
        guard isMinimized, let tbc = tabBarController, let wrapperView = tabBarWrapper else { return }
        if isTransitioning || Date().timeIntervalSince(lastToggleDate) < 0.2 { return }
        isTransitioning = true
        lastToggleDate = Date()
        print("EXPAND iOS")
        isMinimized = false

        // Remove tap recognizer once expanded
        if let tap = expandTapRecognizer {
            wrapper.removeGestureRecognizer(tap)
            expandTapRecognizer = nil
        }

        // Restore expanded insets
        if let leadExp = expandedLeading, let trailExp = expandedTrailing,
           let leadCol = collapsedLeading, let trailCol = collapsedTrailing {
            NSLayoutConstraint.deactivate([leadCol, trailCol])
            NSLayoutConstraint.activate(baseConstraints + [leadExp, trailExp])
        }

        // Re-apply full width to the wrapper
        tabViewCollapsedWidth?.isActive = false
        tabViewTrailing?.isActive = true

        // Restore all VCs (full reset by clearing then re-adding)
        if let original = originalViewControllers {
            tbc.setViewControllers([], animated: false)
            tbc.setViewControllers(original, animated: false)
        }

        if let tag = savedSelectedTag, let list = tbc.viewControllers,
           let idx = list.firstIndex(where: { $0.tabBarItem.tag == tag }) {
            tbc.selectedIndex = idx
        }

        // Return positioning to automatic
        tbc.tabBar.itemPositioning = .automatic
        tbc.tabBar.itemWidth = 0
        tbc.tabBar.itemSpacing = 0

        // Restore appearance (make titles visible again)
        restoreAppearance(on: tbc.tabBar)

        // Safety: reset title positions/text
        tbc.tabBar.items?.forEach { item in
            item.titlePositionAdjustment = .zero
            if let saved = originalTitlesByTag[item.tag] {
                item.title = saved
            }
        }

        // Trigger layout before animating
        tbc.tabBar.setNeedsUpdateConstraints()
        tbc.tabBar.setNeedsLayout()
        tbc.tabBar.layoutIfNeeded()
        wrapperView.setNeedsLayout()
        container.setNeedsLayout()

        // Animate expansion visuals first
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn], animations: {
            tbc.tabBar.layer.cornerRadius = 24
            wrapperView.alpha = 1.0
            wrapperView.layoutIfNeeded()
            self.container.layoutIfNeeded()
        }, completion: { _ in
            self.isTransitioning = false
                // After animation finishes, force re-selection/layout
            if let vcs = tbc.viewControllers {
                let savedIdx = tbc.selectedIndex
                let savedDelegate = tbc.delegate
                tbc.delegate = nil
                for i in 0..<vcs.count {
                    tbc.selectedIndex = i
                }
                tbc.selectedIndex = savedIdx
                tbc.delegate = savedDelegate
            }

            DispatchQueue.main.async {
                tbc.tabBar.itemPositioning = .automatic
                tbc.tabBar.itemWidth = 0
                tbc.tabBar.itemSpacing = 0
                tbc.tabBar.setNeedsLayout()
                tbc.tabBar.layoutIfNeeded()
            }
        })
    }

    @objc private func handleCollapsedTap() {
        guard let wrapper = tabBarWrapper, isMinimized else { return }
        expandTabBar(wrapper)
        ignoreScrollUntil = Date().addingTimeInterval(0.4)
        expandedLockUntil = Date().addingTimeInterval(0.6)
    }

    // Collapse: hide titles with empty string (avoids appearance cache issues)
    private func applyCollapsedAppearance(to tabBar: UITabBar) {
        if #available(iOS 15.0, *) {
            let appearance = (originalAppearance ?? tabBar.standardAppearance).copy() as! UITabBarAppearance
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterialDark)
            appearance.backgroundColor = UIColor.black.withAlphaComponent(0.22)
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
        // Clear all item titles
        tabBar.items?.forEach { item in
            if originalTitlesByTag[item.tag] == nil {
                originalTitlesByTag[item.tag] = item.title
            }
            item.title = ""
        }
    }

    // Expand: restore titles and visible colors/offsets
    private func restoreAppearance(on tabBar: UITabBar) {
        if #available(iOS 15.0, *) {
            let base = (originalAppearance ?? UITabBarAppearance())
            let ap = base.copy() as! UITabBarAppearance

            // Background style
            if base.backgroundEffect == nil && base.backgroundColor == nil {
                ap.configureWithTransparentBackground()
                ap.backgroundEffect = UIBlurEffect(style: .systemMaterialDark)
                ap.backgroundColor = UIColor.black.withAlphaComponent(0.15)
            }

            // Make titles visible
            var normalAttrs = ap.stackedLayoutAppearance.normal.titleTextAttributes
            var selectedAttrs = ap.stackedLayoutAppearance.selected.titleTextAttributes
            normalAttrs[.foregroundColor] = unselectedTintColor
            selectedAttrs[.foregroundColor] = selectedTintColor
            ap.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
            ap.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
            ap.stackedLayoutAppearance.normal.titlePositionAdjustment = .zero
            ap.stackedLayoutAppearance.selected.titlePositionAdjustment = .zero
            ap.stackedLayoutAppearance.normal.iconColor = unselectedTintColor
            ap.stackedLayoutAppearance.selected.iconColor = selectedTintColor

            // Match inline/compact layouts to stacked
            ap.inlineLayoutAppearance = ap.stackedLayoutAppearance
            ap.compactInlineLayoutAppearance = ap.stackedLayoutAppearance

            tabBar.standardAppearance = ap
            tabBar.scrollEdgeAppearance = ap

            tabBar.unselectedItemTintColor = unselectedTintColor
        } else {
            tabBar.items?.forEach { item in
                item.titlePositionAdjustment = .zero
                let normal = originalTitleAttrsNormal.isEmpty ? [.foregroundColor: unselectedTintColor] : originalTitleAttrsNormal
                let selected = originalTitleAttrsSelected.isEmpty ? [.foregroundColor: selectedTintColor] : originalTitleAttrsSelected
                item.setTitleTextAttributes(normal, for: .normal)
                item.setTitleTextAttributes(selected, for: .selected)
            }
            if #available(iOS 13.0, *) {
                tabBar.unselectedItemTintColor = unselectedTintColor
            }
        }

        // Restore saved title strings
        tabBar.items?.forEach { item in
            if let saved = originalTitlesByTag[item.tag] {
                item.title = saved
            }
        }
    }

    // Mirror tab selections back to Flutter
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let tag = viewController.tabBarItem.tag
        // Briefly ignore scroll-triggered minimize after selection
        ignoreScrollUntil = Date().addingTimeInterval(1.2)
        expandedLockUntil = Date().addingTimeInterval(1.2)
        // If minimized, expand first on any tab tap
        if isMinimized, let wrapper = tabBarWrapper {
            expandTabBar(wrapper)
        }
        // Any normal tab tap should clear action pill selection state.
        actionTabBar?.selectedItem = nil
        eventChannel.invokeMethod("onTabChanged", arguments: tag)
        return true
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if tabBar == actionTabBar && item.tag == -1 {
            eventChannel.invokeMethod("onActionTapped", arguments: nil)
            tabBar.selectedItem = nil
            ignoreScrollUntil = Date().addingTimeInterval(1.2)
            expandedLockUntil = Date().addingTimeInterval(1.2)
        }
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

    static func parseEnableMinimize(args: Any?) -> Bool {
        guard let dict = args as? [String: Any],
              let flag = dict["enableMinimize"] as? Bool else {
            return true
        }
        return flag
    }

    static func parseSelectedColor(args: Any?) -> UIColor {
        guard let dict = args as? [String: Any],
              let hexString = dict["selectedColorHex"] as? String else {
            return UIColor.systemBlue
        }
        return color(from: hexString) ?? UIColor.systemBlue
    }

    static func parseUnselectedColor(args: Any?) -> UIColor {
        guard let dict = args as? [String: Any],
              let hexString = dict["unselectedColorHex"] as? String else {
            return UIColor.label.withAlphaComponent(0.7)
        }
        return color(from: hexString) ?? UIColor.label.withAlphaComponent(0.7)
    }

    private static func color(from hexString: String) -> UIColor? {
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

    static func parseBottomOffset(args: Any?) -> Double {
        (args as? [String: Any])?["bottomOffset"] as? Double ?? 0
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
