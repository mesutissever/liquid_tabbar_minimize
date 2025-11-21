import Flutter
import UIKit

// MARK: - Platform View

class LiquidTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {

    private let container: UIView
    private let channel: FlutterMethodChannel

    // Native TabBar (Items are managed here)
    private let tabBar: UITabBar = UITabBar(frame: .zero)
    private var tabBarBaseTransform: CGAffineTransform = .identity

    // Data
    private var currentLabels: [String] = []
    private var currentSymbols: [String] = []
    private var currentSelectedIndex: Int = 0

    // Animation State
    private var lastProgress: CGFloat = 0.0
    private var lastOffsetY: CGFloat = 0.0
    private var minimizeProgress: CGFloat = 0.0

    // Background Views
    private var mainBackground: UIVisualEffectView?
    private var singleBubble: UIVisualEffectView? // The single floating button
    private var singleBubbleIcon: UIImageView?
    private var singleBubbleCenterX: NSLayoutConstraint?
    private var singleBubbleCenterY: NSLayoutConstraint?

    // Constants
    private let bubbleSize: CGFloat = 50.0
    private let sideMargin: CGFloat = 16.0

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        self.container = UIView(frame: frame)
        self.channel = FlutterMethodChannel(
            name: "liquid_tabbar_minimize/tabbar_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        setupTabBar()
        parseInitialArgs(args)
        channel.setMethodCallHandler(handleMethodCall)
    }

    private func setupTabBar() {
        container.backgroundColor = .clear

        // 1. Create Background Views
        // Using systemMaterialDark to match the dark theme request
        let blur = UIBlurEffect(style: .systemMaterialDark)

        // Main Capsule (Visible in Normal State)
        mainBackground = UIVisualEffectView(effect: blur)
        mainBackground?.layer.masksToBounds = true
        mainBackground?.layer.cornerRadius = 32 // Approximate capsule radius
        mainBackground?.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mainBackground!)

        // Single Bubble (Visible in Scrolled State - Bottom Left)
        singleBubble = UIVisualEffectView(effect: blur)
        singleBubble?.layer.masksToBounds = true
        singleBubble?.layer.cornerRadius = bubbleSize / 2
        singleBubble?.translatesAutoresizingMaskIntoConstraints = false
        singleBubble?.alpha = 0.0
        container.addSubview(singleBubble!)
        container.bringSubviewToFront(singleBubble!)

        // Icon that will live inside the floating bubble
        let iconView = UIImageView(frame: .zero)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        singleBubble?.contentView.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            iconView.centerXAnchor.constraint(equalTo: singleBubble!.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: singleBubble!.contentView.centerYAnchor),
        ])
        singleBubbleIcon = iconView

        // 2. Setup TabBar
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.isTranslucent = true
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.backgroundColor = .clear
        
        // Colors
        tabBar.tintColor = .white
        tabBar.unselectedItemTintColor = .gray

        container.addSubview(tabBar)

        NSLayoutConstraint.activate([
            // TabBar fills container
            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: container.topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            // Main Background (Capsule) - Inset slightly
            mainBackground!.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: sideMargin),
            mainBackground!.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -sideMargin),
            mainBackground!.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            mainBackground!.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),

            // Single Bubble constraints (size + initial position)
            singleBubble!.widthAnchor.constraint(equalToConstant: bubbleSize),
            singleBubble!.heightAnchor.constraint(equalToConstant: bubbleSize),
        ])

        // Keep a reference to bubble center constraints so we can animate position safely
        singleBubbleCenterX = singleBubble!.centerXAnchor.constraint(equalTo: container.leadingAnchor, constant: sideMargin + (bubbleSize / 2))
        singleBubbleCenterY = singleBubble!.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        NSLayoutConstraint.activate([singleBubbleCenterX!, singleBubbleCenterY!])

        container.layoutIfNeeded()
        tabBarBaseTransform = tabBar.transform
    }

    private func parseInitialArgs(_ args: Any?) {
        guard let dict = args as? [String: Any] else { return }

        currentLabels = dict["labels"] as? [String] ?? []
        currentSymbols = dict["sfSymbols"] as? [String] ?? []
        currentSelectedIndex = (dict["selectedIndex"] as? NSNumber)?.intValue ?? 0

        rebuildItems()
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "setItems":
            guard let dict = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
                return
            }
            currentLabels = dict["labels"] as? [String] ?? []
            currentSymbols = dict["sfSymbols"] as? [String] ?? []
            currentSelectedIndex = (dict["selectedIndex"] as? NSNumber)?.intValue ?? 0
            rebuildItems()
            result(nil)

        case "setSelectedIndex":
            guard let dict = call.arguments as? [String: Any],
                  let idx = (dict["index"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "bad_args", message: "Missing index", details: nil))
                return
            }
            currentSelectedIndex = idx
            if let items = tabBar.items, idx >= 0, idx < items.count {
                tabBar.selectedItem = items[idx]
            }
            // Update animation state for new selection
            updateMinimizeProgress(progress: minimizeProgress)
            result(nil)

        case "setScrollOffset":
            guard let dict = call.arguments as? [String: Any],
                  let offsetNum = dict["offset"] as? NSNumber else {
                result(FlutterError(code: "bad_args", message: "Missing offset", details: nil))
                return
            }
            let offsetY = CGFloat(truncating: offsetNum)
            handleScroll(offsetY: offsetY)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - TabBar Items

    private func rebuildItems() {
        var items: [UITabBarItem] = []
        let count = max(currentLabels.count, currentSymbols.count)

        for i in 0..<count {
            let title = (i < currentLabels.count) ? currentLabels[i] : "Tab \(i+1)"
            let symbol = (i < currentSymbols.count) ? currentSymbols[i] : "circle"
            let image = UIImage(systemName: symbol)
            let item = UITabBarItem(title: title, image: image, selectedImage: image)
            item.tag = i
            items.append(item)
        }

        tabBar.items = items
        if currentSelectedIndex >= 0,
           let items = tabBar.items,
           currentSelectedIndex < items.count {
            tabBar.selectedItem = items[currentSelectedIndex]
        }

        updateBubbleIconImage()
    }

    // MARK: - Animation Logic

    private func updateBubbleIconImage() {
        guard let items = tabBar.items,
              currentSelectedIndex >= 0,
              currentSelectedIndex < items.count else { return }

        let selectedItem = items[currentSelectedIndex]
        // Prefer selectedImage if provided, fallback to regular image
        singleBubbleIcon?.image = selectedItem.selectedImage ?? selectedItem.image
    }

    /// progress: 0.0 (Normal) -> 1.0 (Minimized/Single Button)
    private func updateMinimizeProgress(progress: CGFloat) {
        let t = max(0.0, min(1.0, progress))
        lastProgress = t
        updateBubbleIconImage()

        // Fade out the tab bar as we minimize to avoid invisible hit targets
        tabBar.alpha = 1.0 - t
        tabBar.isUserInteractionEnabled = t < 0.95

        // 1. Background Transition
        // Main capsule fades out
        mainBackground?.alpha = 1.0 - t
        // Slight scale down for effect (no vertical slide; keep motion lateral like native)
        let backgroundScale = 1.0 - (0.08 * t)
        mainBackground?.transform = CGAffineTransform(scaleX: backgroundScale, y: backgroundScale)

        // Keep tab bar at the same vertical position to avoid downward drift
        tabBar.transform = tabBarBaseTransform

        // Single Bubble fades in
        singleBubble?.alpha = t

        // 2. Item Transition
        let tabButtons = tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }

        guard !tabButtons.isEmpty else { return }

        let selectedIdx = currentSelectedIndex

        // Calculate Target Position (Bottom Left)
        // Left Target: Left edge + margin + half bubble (using constraints)
        let targetX = sideMargin + (bubbleSize / 2)
        let targetY = container.bounds.height / 2

        // Read current layout to interpolate bubble from selected tab position
        container.layoutIfNeeded()
        let selectedButton = tabButtons[min(max(0, selectedIdx), tabButtons.count - 1)]
        let startCenter = selectedButton.center

        // Interpolate bubble center between selected item and target point
        let bubbleCenterX = startCenter.x + (targetX - startCenter.x) * t
        let bubbleCenterY = startCenter.y + (targetY - startCenter.y) * t

        singleBubbleCenterX?.constant = bubbleCenterX
        let midY = container.bounds.height / 2
        singleBubbleCenterY?.constant = bubbleCenterY - midY

        // Scale bubble slightly for effect 0.9 -> 1.0
        let bubbleScale = 0.9 + (0.1 * t)
        singleBubble?.transform = CGAffineTransform(scaleX: bubbleScale, y: bubbleScale)
        singleBubbleIcon?.alpha = t
        // Apply layout immediately so the bubble tracks the finger during scroll
        UIView.performWithoutAnimation {
            container.layoutIfNeeded()
        }

        // Animate Buttons
        for (i, button) in tabButtons.enumerated() {
            if i == selectedIdx {
                // Selected Item -> fade and gently scale down as bubble takes over
                let scale = 1.0 - (0.15 * t)
                button.transform = CGAffineTransform(scaleX: scale, y: scale)
                button.alpha = max(0.0, 1.0 - (t * 1.15))
            } else {
                // Other Items -> Fade out
                button.alpha = 1.0 - t
            }

            // Hide the label as we minimize to mimic native behavior
            button.subviews.forEach { subview in
                if let label = subview as? UILabel {
                    label.alpha = 1.0 - t
                }
            }
            if i != selectedIdx {
                button.transform = .identity
            }
        }
    }

    private func handleScroll(offsetY: CGFloat) {
        let delta = offsetY - lastOffsetY
        lastOffsetY = offsetY

        // Ignore small jitters
        if abs(delta) < 0.5 { return }

        let sensitivity: CGFloat = 180.0

        if delta > 0 {
            // Scroll Down -> Minimize
            minimizeProgress += (delta / sensitivity)
        } else {
            // Scroll Up -> Restore
            minimizeProgress += (delta / sensitivity)
        }

        // Clamp 0-1
        minimizeProgress = max(0.0, min(1.0, minimizeProgress))

        // Reset if at top
        if offsetY <= 0.0 {
            minimizeProgress = 0.0
        }

        updateMinimizeProgress(progress: minimizeProgress)
    }

    // MARK: - FlutterPlatformView

    func view() -> UIView {
        return container
    }

    // MARK: - UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        currentSelectedIndex = item.tag
        
        // Reset progress on tab change? 
        // Maybe keep it if we are scrolled down?
        // Let's keep current progress but update positions
        updateMinimizeProgress(progress: minimizeProgress)

        channel.invokeMethod("onTabSelected", arguments: ["index": item.tag])
    }
}

// MARK: - Factory

class LiquidTabBarViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return LiquidTabBarPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
