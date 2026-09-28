import Flutter
import PassKit
import UIKit
import XMoneyPaymentSheet

final class PaymentElementViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger, host: XMoneyHostController) {
        self.messenger = messenger
        _ = host
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        MainActor.assumeIsolated {
            PaymentElementPlatformView(
                frame: frame,
                viewId: viewId,
                messenger: messenger,
                args: args as? [String: Any] ?? [:]
            )
        }
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@MainActor
final class PaymentElementPlatformView: NSObject, FlutterPlatformView {
    private let container = UIView()
    private let elementChannel: FlutterMethodChannel
    private var element: PaymentElement?
    private var payment: EmbeddedPayment?
    private var configurationMap: [String: Any] = [:]
    private var orderPayload = ""
    private var orderChecksum = ""
    private var prepareTask: Task<Void, Never>?
    private var lastReportedHeight: CGFloat = -1
    private var lastOrderConsumed: Bool?
    private var lastInteractionEnabled: Bool?
    /// `onReady` is sent once, after the form has finished its first layout.
    private var didSendReady = false
    private var keyboardObservers: [NSObjectProtocol] = []
    /// Off-screen until a keyboard notification arrives.
    private var keyboardFrameInWindow = CGRect(x: 0, y: 10_000, width: 0, height: 0)
    private var lastKeyboardReport = ""

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, args: [String: Any]) {
        elementChannel = FlutterMethodChannel(
            name: "xmoney/payment_element/\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        container.frame = frame
        configurationMap = args["configuration"] as? [String: Any] ?? [:]
        orderPayload = args["orderPayload"] as? String ?? ""
        orderChecksum = args["orderChecksum"] as? String ?? ""
        elementChannel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                self?.handle(call, result: result)
            }
        }
        bind(requestId: "")
        startKeyboardTracking()
    }

    func view() -> UIView { container }

    deinit {
        prepareTask?.cancel()
        let observers = keyboardObservers
        keyboardObservers = []
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "confirm":
            payment?.confirm()
            result(nil)
        case "updateOrder":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            orderPayload = args["orderPayload"] as? String ?? orderPayload
            orderChecksum = args["orderChecksum"] as? String ?? orderChecksum
            runUpdateOrder(result: result)
        case "updateAppearance":
            guard let args = call.arguments as? [String: Any],
                  let appearance = args["appearance"] as? [String: Any]
            else {
                result(nil)
                return
            }
            element?.updateAppearance(PaymentConfig.AppearanceConfig.from(appearance))
            reportHeight()
            result(nil)
        case "updateLocale":
            guard let args = call.arguments as? [String: Any],
                  let locale = args["locale"] as? String
            else {
                result(nil)
                return
            }
            element?.updateLocale(locale)
            reportHeight()
            result(nil)
        case "updateStyle":
            guard let args = call.arguments as? [String: Any],
                  let styleRaw = args["style"] as? String,
                  let style = PaymentConfig.UserInterfaceStyle(rawValue: styleRaw)
            else {
                result(nil)
                return
            }
            element?.updateStyle(style)
            reportHeight()
            result(nil)
        case "updateWalletAppearance":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            let apple = args["applePay"] as? [String: Any]
            element?.updateWalletAppearance(BridgeConfigParser.parseWalletAppearance(apple))
            reportHeight()
            result(nil)
        case "updateAll":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            configurationMap = args["configuration"] as? [String: Any] ?? configurationMap
            orderPayload = args["orderPayload"] as? String ?? orderPayload
            orderChecksum = args["orderChecksum"] as? String ?? orderChecksum
            bind(requestId: "")
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func bind(requestId: String) {
        let config = configurationMap
        let (nativeConfig, intent) = (
            BridgeConfigParser.parseConfig(dict: config),
            BridgeConfigParser.parseIntent(
                orderPayload: orderPayload,
                orderChecksum: orderChecksum
            )
        )
        if nativeConfig.paymentMethods.applePay.enabled {
            ApplePay.register()
        }
        rebuild(configuration: nativeConfig, intent: intent, requestId: requestId)
    }

    private func runUpdateOrder(result: @escaping FlutterResult) {
        guard let element else {
            result(
                FlutterError(code: "NOT_INITIALIZED", message: "Call init before present.", details: nil)
            )
            return
        }
        let intent = BridgeConfigParser.parseIntent(
            orderPayload: orderPayload,
            orderChecksum: orderChecksum
        )
        prepareTask?.cancel()
        prepareTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                try await element.updateOrder(intent: intent)
                self.reportHeight()
                self.emitAvailability()
                result(nil)
            } catch is CancellationError {
                result(
                    FlutterError(
                        code: "SUPERSEDED_UPDATE_ORDER",
                        message: "Superseded by a newer updateOrder call",
                        details: nil
                    )
                )
            } catch let error as PaymentError {
                result(
                    FlutterError(code: error.code, message: error.merchantMessage(), details: nil)
                )
            } catch {
                result(FlutterError(code: "PRESENT_ERROR", message: "Failed to present", details: nil))
            }
        }
    }

    private func rebuild(
        configuration: PaymentConfig,
        intent: PaymentIntent,
        requestId: String
    ) {
        prepareTask?.cancel()
        element?.removeFromSuperview()
        element = nil
        payment = nil
        lastOrderConsumed = nil
        lastInteractionEnabled = nil

        let payment = EmbeddedPayment(configuration: configuration) { [weak self] paymentResult in
            let encoded = jsonString(from: BridgeResults.resultBody(paymentResult))
            Task { @MainActor in
                self?.elementChannel.invokeMethod("onResult", arguments: ["result": encoded])
                self?.emitAvailability()
            }
        }
        self.payment = payment
        let view = PaymentElement(payment: payment) { [weak self] event in
            guard let self else { return }
            // The SDK emits `.ready` when bind finishes, before the form is
            // laid out. Flutter is told from `publishReady` after that layout.
            guard case let .processing(isProcessing) = event else { return }
            let body: [String: Any] = [
                "type": "onProcessing",
                "isProcessing": isProcessing,
            ]
            Task { @MainActor in
                self.elementChannel.invokeMethod(
                    "onEvent",
                    arguments: ["event": jsonString(from: body)]
                )
            }
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.onContentSizeChange = { [weak self] in
            Task { @MainActor in
                self?.reportHeight()
            }
        }
        container.addSubview(view)
        // Top-aligned, not stretched to the Flutter frame. A taller frame would
        // otherwise pull the Apple Pay button past its 56pt height.
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
        ])
        element = view
        didSendReady = false

        prepareTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                try await view.prepare(intent: intent)
                guard !Task.isCancelled else { return }
                // The form measures itself on the next turn (`applySelection`).
                // That block is already queued, so resuming after one main-queue
                // turn means the laid-out height is in place before Flutter
                // drops the skeleton.
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.main.async {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { return }
                view.layoutIfNeeded()
                self.reportHeight()
                self.publishReady()
            } catch let error as PaymentError {
                let encoded = jsonString(
                    from: BridgeResults.failedBody(
                        code: error.code,
                        message: error.merchantMessage()
                    )
                )
                self.elementChannel.invokeMethod("onResult", arguments: ["result": encoded])
            } catch {
                let encoded = jsonString(
                    from: BridgeResults.failedBody(code: "LOAD_ERROR", message: "Failed to load")
                )
                self.elementChannel.invokeMethod("onResult", arguments: ["result": encoded])
            }
        }
    }

    /// Tells Flutter the embedded surface is ready to show. Once per mount.
    private func publishReady() {
        guard !didSendReady else { return }
        didSendReady = true
        elementChannel.invokeMethod(
            "onEvent",
            arguments: ["event": jsonString(from: ["type": "onReady"])]
        )
        emitAvailability()
    }

    private func emitAvailability() {
        let consumed = payment?.isOrderConsumed ?? element?.isOrderConsumed ?? false
        let enabled = payment?.isInteractionEnabled ?? true
        if lastOrderConsumed == consumed, lastInteractionEnabled == enabled {
            return
        }
        lastOrderConsumed = consumed
        lastInteractionEnabled = enabled
        let body: [String: Any] = [
            "type": "onAvailability",
            "isOrderConsumed": consumed,
            "isInteractionEnabled": enabled,
        ]
        elementChannel.invokeMethod(
            "onEvent",
            arguments: ["event": jsonString(from: body)]
        )
    }

    private func startKeyboardTracking() {
        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in
                    self?.handleKeyboard(note)
                }
            },
            center.addObserver(
                forName: UITextField.textDidBeginEditingNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in
                    guard let self, let field = note.object as? UIView,
                          field.isDescendant(of: self.container) else { return }
                    self.emitKeyboard()
                }
            },
        ]
    }

    private func handleKeyboard(_ note: Notification) {
        guard let window = container.window,
              let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        keyboardFrameInWindow = window.convert(end, from: window.screen.coordinateSpace)
        emitKeyboard()
    }

    private func emitKeyboard() {
        guard let window = container.window else { return }
        let overlap = max(0, window.bounds.maxY - keyboardFrameInWindow.minY)
        guard overlap > 1, let field = container.deepestFirstResponder else {
            // Ignore the focus event that arrives before the keyboard frame.
            guard !lastKeyboardReport.isEmpty, lastKeyboardReport != "hidden" else { return }
            lastKeyboardReport = "hidden"
            elementChannel.invokeMethod("onKeyboard", arguments: ["visible": false])
            return
        }
        let fieldFrame = field.convert(field.bounds, to: window)
        let report = "\(Int(keyboardFrameInWindow.minY))-\(Int(fieldFrame.minY))-\(Int(fieldFrame.maxY))"
        guard report != lastKeyboardReport else { return }
        lastKeyboardReport = report
        elementChannel.invokeMethod(
            "onKeyboard",
            arguments: [
                "visible": true,
                "keyboardTop": keyboardFrameInWindow.minY,
                "fieldTop": fieldFrame.minY,
                "fieldBottom": fieldFrame.maxY,
            ]
        )
    }

    private func reportHeight() {
        let height = max(element?.intrinsicContentSize.height ?? 160, 160)
        guard abs(height - lastReportedHeight) > 1 else { return }
        lastReportedHeight = height
        elementChannel.invokeMethod("onHeight", arguments: ["height": height])
    }
}

private extension UIView {
    var deepestFirstResponder: UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.deepestFirstResponder { return found }
        }
        return nil
    }
}

final class ApplePayButtonViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger, host: XMoneyHostController) {
        self.messenger = messenger
        _ = host
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        MainActor.assumeIsolated {
            ApplePayButtonPlatformView(
                frame: frame,
                viewId: viewId,
                messenger: messenger,
                args: args as? [String: Any] ?? [:]
            )
        }
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@MainActor
final class ApplePayButtonPlatformView: NSObject, FlutterPlatformView {
    private let container = UIView()
    private let buttonChannel: FlutterMethodChannel
    private let button = ApplePayButton()
    private var applePay: ApplePay?
    private var paymentConfig: PaymentConfig?
    private var intent: PaymentIntent?
    private var configurationMap: [String: Any] = [:]
    private var orderPayload = ""
    private var orderChecksum = ""
    private var appearanceMap: [String: Any]?
    private var disabled = false
    private var updateTask: Task<Void, Never>?
    private var lastAvailabilityKey: String?

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, args: [String: Any]) {
        buttonChannel = FlutterMethodChannel(
            name: "xmoney/apple_pay_button/\(viewId)",
            binaryMessenger: messenger
        )
        super.init()
        container.frame = frame
        configurationMap = args["configuration"] as? [String: Any] ?? [:]
        orderPayload = args["orderPayload"] as? String ?? ""
        orderChecksum = args["orderChecksum"] as? String ?? ""
        appearanceMap = args["appearance"] as? [String: Any]
        disabled = !(args["isEnabled"] as? Bool ?? true)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.onTap = { [weak self] in
            Task { @MainActor in
                self?.presentApplePay()
            }
        }
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        buttonChannel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                self?.handle(call, result: result)
            }
        }
        bind()
    }

    func view() -> UIView { container }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateOrder":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            orderPayload = args["orderPayload"] as? String ?? orderPayload
            orderChecksum = args["orderChecksum"] as? String ?? orderChecksum
            runUpdateOrder(result: result)
        case "updateAppearance":
            guard let map = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            appearanceMap = map
            button.apply(appearance: BridgeConfigParser.parseWalletAppearance(map))
            result(nil)
        case "updateProps":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            configurationMap = args["configuration"] as? [String: Any] ?? configurationMap
            orderPayload = args["orderPayload"] as? String ?? orderPayload
            orderChecksum = args["orderChecksum"] as? String ?? orderChecksum
            appearanceMap = args["appearance"] as? [String: Any] ?? appearanceMap
            disabled = !(args["isEnabled"] as? Bool ?? true)
            bind()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func bind() {
        paymentConfig = BridgeConfigParser.parseConfig(dict: configurationMap)
        intent = BridgeConfigParser.parseIntent(
            orderPayload: orderPayload,
            orderChecksum: orderChecksum
        )
        guard let paymentConfig, let intent else { return }
        let wallet = appearanceMap != nil
            ? BridgeConfigParser.parseWalletAppearance(appearanceMap)
            : paymentConfig.paymentMethods.applePay.appearance
        button.apply(appearance: wallet)
        syncEnabled()
        ApplePay.register()
        applePay = ApplePay(configuration: paymentConfig) { [weak self] paymentResult in
            let encoded = jsonString(from: BridgeResults.resultBody(paymentResult))
            Task { @MainActor in
                self?.buttonChannel.invokeMethod("onResult", arguments: ["result": encoded])
                self?.emitAvailability()
            }
        }
        buttonChannel.invokeMethod("onEvent", arguments: ["event": jsonString(from: ["type": "onReady"])])
        emitAvailability()
    }

    private func runUpdateOrder(result: @escaping FlutterResult) {
        guard let applePay else {
            result(
                FlutterError(code: "NOT_INITIALIZED", message: "Call init before present.", details: nil)
            )
            return
        }
        let nextIntent = BridgeConfigParser.parseIntent(
            orderPayload: orderPayload,
            orderChecksum: orderChecksum
        )
        updateTask?.cancel()
        button.isEnabled = false
        emitProcessing(true)
        updateTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                try await applePay.updateOrder(intent: nextIntent)
                self.intent = nextIntent
                self.syncEnabled()
                self.emitProcessing(false)
                self.emitAvailability()
                result(nil)
            } catch is CancellationError {
                self.syncEnabled()
                self.emitProcessing(false)
                self.emitAvailability()
                result(
                    FlutterError(
                        code: "SUPERSEDED_UPDATE_ORDER",
                        message: "Superseded by a newer updateOrder call",
                        details: nil
                    )
                )
            } catch let error as PaymentError {
                self.syncEnabled()
                self.emitProcessing(false)
                self.emitAvailability()
                let encoded = jsonString(
                    from: BridgeResults.failedBody(
                        code: error.code,
                        message: error.merchantMessage()
                    )
                )
                self.buttonChannel.invokeMethod("onResult", arguments: ["result": encoded])
                result(FlutterError(code: error.code, message: error.merchantMessage(), details: nil))
            } catch {
                self.syncEnabled()
                self.emitProcessing(false)
                result(FlutterError(code: "PRESENT_ERROR", message: "Failed to present", details: nil))
            }
        }
    }

    private func syncEnabled() {
        button.isEnabled = !disabled && (applePay?.isInteractionEnabled ?? true)
    }

    private func presentApplePay() {
        guard !disabled, let applePay, let intent, applePay.isInteractionEnabled else { return }
        guard let presenter = XMoneyHostController.topViewControllerForPlatformView() else {
            let encoded = jsonString(
                from: BridgeResults.failedBody(
                    code: "NO_PRESENTER",
                    message: "Unable to present from the current screen."
                )
            )
            buttonChannel.invokeMethod("onResult", arguments: ["result": encoded])
            return
        }
        applePay.present(from: presenter, intent: intent) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                let body: [String: Any]
                switch event {
                case .ready:
                    body = ["type": "onReady"]
                case let .processing(isProcessing):
                    body = ["type": "onProcessing", "isProcessing": isProcessing]
                }
                self.buttonChannel.invokeMethod(
                    "onEvent",
                    arguments: ["event": jsonString(from: body)]
                )
                self.emitAvailability()
            }
        }
    }

    private func emitProcessing(_ isProcessing: Bool) {
        let body: [String: Any] = ["type": "onProcessing", "isProcessing": isProcessing]
        buttonChannel.invokeMethod(
            "onEvent",
            arguments: ["event": jsonString(from: body)]
        )
    }

    private func emitAvailability() {
        let canPay = PKPaymentAuthorizationController.canMakePayments()
        let body: [String: Any] = [
            "type": "onAvailability",
            "isAvailable": canPay,
            "isReady": canPay,
            "isOrderConsumed": applePay?.isOrderConsumed ?? false,
            "isInteractionEnabled": (applePay?.isInteractionEnabled ?? true) && !disabled,
        ]
        let key = "\(body)"
        if key == lastAvailabilityKey { return }
        lastAvailabilityKey = key
        buttonChannel.invokeMethod(
            "onEvent",
            arguments: ["event": jsonString(from: body)]
        )
    }
}

private func jsonString(from object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object),
          let string = String(data: data, encoding: .utf8)
    else {
        return "{}"
    }
    return string
}

extension XMoneyHostController {
    static func topViewControllerForPlatformView() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostViewController()
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostViewController()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController()
        }
        return self
    }
}
