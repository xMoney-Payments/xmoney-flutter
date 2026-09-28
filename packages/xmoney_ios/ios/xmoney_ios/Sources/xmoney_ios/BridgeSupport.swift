import Foundation
import Flutter
import XMoneyPaymentSheet

enum BridgeJson {
    static func toMap(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return object
    }
}

enum BridgeResults {
    static func resultBody(_ result: PaymentResult) -> [String: Any] {
        switch result {
        case let .complete(transaction):
            return ["status": "complete", "transaction": transactionBody(transaction)]
        case let .failed(error):
            return [
                "status": "failed",
                "error": ["code": error.code, "message": error.merchantMessage()],
            ]
        case .canceled:
            return ["status": "canceled"]
        }
    }

    static func failedBody(code: String, message: String) -> [String: Any] {
        ["status": "failed", "error": ["code": code, "message": message]]
    }

    static func walletStateBody(
        isAvailable: Bool,
        isReady: Bool,
        isOrderConsumed: Bool,
        isInteractionEnabled: Bool
    ) -> [String: Any] {
        [
            "isAvailable": isAvailable,
            "isReady": isReady,
            "isOrderConsumed": isOrderConsumed,
            "isInteractionEnabled": isInteractionEnabled,
        ]
    }

    private static func transactionBody(_ transaction: Transaction) -> [String: Any] {
        var body: [String: Any] = [:]
        if let id = transaction.id { body["id"] = id }
        if let status = transaction.status { body["status"] = status }
        if let amount = transaction.amount { body["amount"] = amount }
        if let currencyKey = transaction.currencyKey { body["currencyKey"] = currencyKey }
        if let amountInEuro = transaction.amountInEuro { body["amountInEuro"] = amountInEuro }
        if let externalOrderId = transaction.externalOrderId { body["externalOrderId"] = externalOrderId }
        if let description = transaction.description { body["description"] = description }
        return body
    }
}

enum BridgeConfigParser {
    static func parseConfig(json: String) -> PaymentConfig {
        parseConfig(dict: BridgeJson.toMap(json))
    }

    static func parseConfig(dict: [String: Any]) -> PaymentConfig {
        PaymentConfig(
            publicKey: dict["publicKey"] as? String ?? "",
            card: parseCard(dict["card"] as? [String: Any]),
            paymentMethods: parsePaymentMethods(dict["paymentMethods"] as? [String: Any]),
            options: parseOptions(dict["options"] as? [String: Any])
        )
    }

    static func parseIntent(orderPayload: String, orderChecksum: String) -> PaymentIntent {
        PaymentIntent(
            orderPayload: OrderPayload(orderPayload),
            orderChecksum: OrderChecksum(orderChecksum)
        )
    }

    private static func parseCard(_ dict: [String: Any]?) -> PaymentConfig.CardConfig {
        var card = PaymentConfig.CardConfig()
        guard let dict else { return card }
        if let saved = dict["savedCards"] as? [String: Any] {
            var savedCards = PaymentConfig.SavedCardsConfig()
            if let enabled = saved["enabled"] as? Bool { savedCards.enabled = enabled }
            if let optIn = saved["optInVisible"] as? Bool { savedCards.optInVisible = optIn }
            card.savedCards = savedCards
        }
        card.cardHolderVerification = parseCardHolderVerification(dict["cardHolderVerification"] as? [String: Any])
        return card
    }

    private static func parseCardHolderVerification(_ dict: [String: Any]?) -> CardHolderVerification? {
        guard let dict,
              let name = dict["name"] as? [String: Any],
              let firstName = name["firstName"] as? String,
              let lastName = name["lastName"] as? String
        else { return nil }
        let chvId = dict["chvId"] as? String ?? ""
        return CardHolderVerification(
            name: CardHolderName(
                firstName: firstName,
                middleName: name["middleName"] as? String ?? "",
                lastName: lastName
            ),
            onCardHolderVerification: { result in
                CardHolderVerificationBridge.ask(chvId: chvId, result: result)
            }
        )
    }

    private static func parsePaymentMethods(_ dict: [String: Any]?) -> PaymentConfig.PaymentMethodsConfig {
        var methods = PaymentConfig.PaymentMethodsConfig()
        guard let dict, let apple = dict["applePay"] as? [String: Any] else { return methods }
        var applePay = PaymentConfig.ApplePayConfig()
        if let enabled = apple["enabled"] as? Bool { applePay.enabled = enabled }
        methods.applePay = applePay
        return methods
    }

    private static func parseOptions(_ dict: [String: Any]?) -> PaymentConfig.OptionsConfig {
        var options = PaymentConfig.OptionsConfig()
        guard let dict else { return options }
        if let locale = dict["locale"] as? String { options.locale = locale }
        if let styleRaw = dict["style"] as? String,
           let style = PaymentConfig.UserInterfaceStyle(rawValue: styleRaw)
        {
            options.style = style
        }
        if let appearance = dict["appearance"] as? [String: Any] {
            options.appearance = PaymentConfig.AppearanceConfig.from(appearance)
        }
        return options
    }

    static func parseWalletAppearance(_ dict: [String: Any]?) -> PaymentConfig.WalletAppearance {
        guard let dict else { return .init() }
        return PaymentConfig.WalletAppearance(
            color: PaymentConfig.WalletButtonColor.from(dict["color"] as? String),
            radius: (dict["radius"] as? NSNumber)?.doubleValue,
            type: PaymentConfig.WalletButtonType.from(dict["type"] as? String)
        )
    }
}

enum CardHolderVerificationBridge {
    private static let lock = NSLock()
    private static var channel: FlutterMethodChannel?
    private static var pending = [String: DispatchSemaphore]()
    private static var answers = [String: Bool]()

    static func attach(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    static func ask(chvId: String, result: CardHolderVerificationResult) -> Bool {
        let requestId = UUID().uuidString
        var body: [String: Any] = ["status": result.status.rawValue]
        if let value = result.firstNameStatus { body["firstNameStatus"] = value.rawValue }
        if let value = result.middleNameStatus { body["middleNameStatus"] = value.rawValue }
        if let value = result.lastNameStatus { body["lastNameStatus"] = value.rawValue }
        guard channel != nil,
              let data = try? JSONSerialization.data(withJSONObject: body),
              let resultJson = String(data: data, encoding: .utf8)
        else {
            return false
        }
        let arguments: [String: Any] = [
            "chvId": chvId,
            "requestId": requestId,
            "resultJson": resultJson,
        ]
        let semaphore = DispatchSemaphore(value: 0)
        lock.lock()
        pending[requestId] = semaphore
        lock.unlock()
        // The merchant answer is delivered on xmoney/chv (background task
        // queue). Waiting here does not spin the main run loop.
        func send() {
            channel?.invokeMethod("onCardHolderVerification", arguments: arguments)
        }
        if Thread.isMainThread {
            send()
        } else {
            DispatchQueue.main.async(execute: send)
        }
        _ = semaphore.wait(timeout: .now() + 2)
        lock.lock()
        pending.removeValue(forKey: requestId)
        let accepted = answers.removeValue(forKey: requestId) ?? false
        lock.unlock()
        return accepted
    }

    static func answer(requestId: String, accepted: Bool) {
        lock.lock()
        answers[requestId] = accepted
        let semaphore = pending[requestId]
        lock.unlock()
        semaphore?.signal()
    }
}
