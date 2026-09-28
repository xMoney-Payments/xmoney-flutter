import Flutter
import PassKit
import UIKit
import XMoneyPaymentSheet

final class XMoneyHostController {
    private var configuration: PaymentConfig?
    private var sheet: PaymentSheet?
    private var applePayConfig: PaymentConfig?
    private var applePay: ApplePay?
    private var applePayResolve: ((String) -> Void)?
    private var flutterChannel: FlutterMethodChannel?
    private var presentGeneration = 0

    func attach(flutterChannel: FlutterMethodChannel) {
        self.flutterChannel = flutterChannel
        CardHolderVerificationBridge.attach(channel: flutterChannel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initPaymentSheet":
            let json = call.arguments as? String ?? ""
            configuration = BridgeConfigParser.parseConfig(json: json)
            sheet = nil
            result(nil)
        case "presentPaymentSheet":
            let json = call.arguments as? String ?? ""
            presentPaymentSheet(json: json, result: result)
        case "dismissPaymentSheet":
            Task { @MainActor in self.sheet?.dismiss() }
            result(nil)
        case "initApplePay":
            let json = call.arguments as? String ?? ""
            applePayConfig = BridgeConfigParser.parseConfig(json: json)
            applePay = nil
            result(nil)
        case "presentApplePay":
            let json = call.arguments as? String ?? ""
            presentApplePay(json: json, result: result)
        case "dismissApplePay":
            Task { @MainActor in self.applePay?.dismiss() }
            result(nil)
        case "getApplePayState":
            let body = MainActor.assumeIsolated { self.applePayStateBody() }
            result(jsonString(from: body))
        case "updateApplePayOrder":
            let json = call.arguments as? String ?? ""
            updateApplePayOrder(json: json, result: result)
        case "initGooglePay":
            _ = call.arguments
            result(nil)
        case "presentGooglePay":
            result(
                jsonString(
                    from: BridgeResults.failedBody(
                        code: "GOOGLE_PAY",
                        message: "Google Pay is only available on Android."
                    )
                )
            )
        case "dismissGooglePay":
            result(nil)
        case "getGooglePayState":
            result(
                jsonString(
                    from: BridgeResults.walletStateBody(
                        isAvailable: false,
                        isReady: false,
                        isOrderConsumed: false,
                        isInteractionEnabled: true
                    )
                )
            )
        case "updateGooglePayOrder":
            result(
                FlutterError(
                    code: "GOOGLE_PAY",
                    message: "Google Pay is only available on Android.",
                    details: nil
                )
            )
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentPaymentSheet(json: String, result: @escaping FlutterResult) {
        let dict = BridgeJson.toMap(json)
        let requestId = dict["requestId"] as? String ?? ""
        let payload = dict["orderPayload"] as? String ?? ""
        let checksum = dict["orderChecksum"] as? String ?? ""
        Task { @MainActor in
            guard let configuration = self.configuration else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Call init before present.", details: nil))
                return
            }
            guard let presenter = Self.topViewController() else {
                result(FlutterError(code: "NO_PRESENTER", message: "Unable to present from the current screen.", details: nil))
                return
            }
            let intent = BridgeConfigParser.parseIntent(orderPayload: payload, orderChecksum: checksum)
            self.presentGeneration += 1
            let generation = self.presentGeneration
            self.sheet?.dismiss()
            let sheet = PaymentSheet(configuration: configuration)
            self.sheet = sheet
            sheet.present(
                from: presenter,
                intent: intent,
                onEvent: { event in
                    self.emitNativeEvent(requestId: requestId, body: Self.sheetEventBody(event))
                },
                completion: { paymentResult in
                    if self.presentGeneration == generation {
                        self.sheet = nil
                    }
                    result(jsonString(from: BridgeResults.resultBody(paymentResult)))
                }
            )
        }
    }

    private func presentApplePay(json: String, result: @escaping FlutterResult) {
        let dict = BridgeJson.toMap(json)
        let requestId = dict["requestId"] as? String ?? ""
        let payload = dict["orderPayload"] as? String ?? ""
        let checksum = dict["orderChecksum"] as? String ?? ""
        Task { @MainActor in
            guard let configuration = self.applePayConfig else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Call init before present.", details: nil))
                return
            }
            guard let presenter = Self.topViewController() else {
                result(FlutterError(code: "NO_PRESENTER", message: "Unable to present from the current screen.", details: nil))
                return
            }
            let intent = BridgeConfigParser.parseIntent(orderPayload: payload, orderChecksum: checksum)
            ApplePay.register()
            let session = self.applePay ?? ApplePay(configuration: configuration) { paymentResult in
                self.applePayResolve?(jsonString(from: BridgeResults.resultBody(paymentResult)))
                self.applePayResolve = nil
            }
            self.applePay = session
            self.applePayResolve = { encoded in result(encoded) }
            session.present(from: presenter, intent: intent) { event in
                self.emitNativeEvent(requestId: requestId, body: Self.applePayEventBody(event))
            }
        }
    }

    private func updateApplePayOrder(json: String, result: @escaping FlutterResult) {
        let dict = BridgeJson.toMap(json)
        let payload = dict["orderPayload"] as? String ?? ""
        let checksum = dict["orderChecksum"] as? String ?? ""
        Task { @MainActor in
            guard let applePay = self.applePay else {
                result(FlutterError(code: "NOT_INITIALIZED", message: "Call init before present.", details: nil))
                return
            }
            let intent = BridgeConfigParser.parseIntent(orderPayload: payload, orderChecksum: checksum)
            do {
                try await applePay.updateOrder(intent: intent)
                result(nil)
            } catch let error as PaymentError {
                result(
                    FlutterError(
                        code: error.code,
                        message: error.merchantMessage(),
                        details: nil
                    )
                )
            } catch {
                result(
                    FlutterError(
                        code: "PRESENT_ERROR",
                        message: "Failed to present",
                        details: nil
                    )
                )
            }
        }
    }

    @MainActor
    private func applePayStateBody() -> [String: Any] {
        let canPay = PKPaymentAuthorizationController.canMakePayments()
        return BridgeResults.walletStateBody(
            isAvailable: canPay,
            isReady: canPay,
            isOrderConsumed: applePay?.isOrderConsumed ?? false,
            isInteractionEnabled: applePay?.isInteractionEnabled ?? true
        )
    }

    private func emitNativeEvent(requestId: String, body: [String: Any]) {
        flutterChannel?.invokeMethod(
            "onNativeEvent",
            arguments: [
                "requestId": requestId,
                "eventJson": jsonString(from: body),
            ]
        )
    }

    private static func sheetEventBody(_ event: PaymentSheetEvent) -> [String: Any] {
        switch event {
        case .ready:
            return ["type": "onReady"]
        case let .processing(isProcessing):
            return ["type": "onProcessing", "isProcessing": isProcessing]
        }
    }

    private static func applePayEventBody(_ event: ApplePayEvent) -> [String: Any] {
        switch event {
        case .ready:
            return ["type": "onReady"]
        case let .processing(isProcessing):
            return ["type": "onProcessing", "isProcessing": isProcessing]
        }
    }

    private static func topViewController() -> UIViewController? {
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

private func jsonString(from object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object),
          let string = String(data: data, encoding: .utf8)
    else {
        return "{}"
    }
    return string
}
