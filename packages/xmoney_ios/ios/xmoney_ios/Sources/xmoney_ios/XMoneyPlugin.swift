import Flutter
import UIKit
import XMoneyPaymentSheet

public class XMoneyPlugin: NSObject, FlutterPlugin {
    private let host = XMoneyHostController()
    private var chvChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = XMoneyPlugin()
        let hostChannel = FlutterMethodChannel(
            name: "xmoney/host",
            binaryMessenger: registrar.messenger()
        )
        let flutterChannel = FlutterMethodChannel(
            name: "xmoney/flutter",
            binaryMessenger: registrar.messenger()
        )
        // Optional on the protocol because macOS does not implement it. This
        // plugin is iOS-only, where the engine provides the queue.
        guard let taskQueue = registrar.messenger().makeBackgroundTaskQueue?() else {
            preconditionFailure("xmoney requires a background Flutter task queue.")
        }
        let chvChannel = FlutterMethodChannel(
            name: "xmoney/chv",
            binaryMessenger: registrar.messenger(),
            codec: FlutterStandardMethodCodec.sharedInstance(),
            taskQueue: taskQueue
        )
        instance.chvChannel = chvChannel
        hostChannel.setMethodCallHandler(instance.handle)
        chvChannel.setMethodCallHandler { call, result in
            guard call.method == "answerCardHolderVerification" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let args = call.arguments as? [String: Any]
            let requestId = args?["requestId"] as? String ?? ""
            let accepted = args?["accepted"] as? Bool ?? false
            CardHolderVerificationBridge.answer(requestId: requestId, accepted: accepted)
            result(nil)
        }
        instance.host.attach(flutterChannel: flutterChannel)

        registrar.register(
            PaymentElementViewFactory(messenger: registrar.messenger(), host: instance.host),
            withId: "xmoney/payment_element"
        )
        registrar.register(
            ApplePayButtonViewFactory(messenger: registrar.messenger(), host: instance.host),
            withId: "xmoney/apple_pay_button"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        host.handle(call, result: result)
    }
}
