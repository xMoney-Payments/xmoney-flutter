# xMoney Payments — Flutter SDK

Flutter SDK for [xMoney](https://xmoney.com) checkout. Three surfaces, one `PaymentConfig`, one `PaymentResult`. Card data never crosses the Dart platform channel.

| Surface | API | Use when |
| --- | --- | --- |
| **Payment Sheet** | `PaymentSheetController` | Drop-in bottom sheet. SDK owns the UI and the Pay button. |
| **Payment Element** | `PaymentElement` | Card, saved cards, and wallet **in your layout**. |
| **Apple Pay** | `ApplePay`, `ApplePayButton` (iOS) | Standalone wallet button or `present()`. |
| **Google Pay** | `GooglePay`, `GooglePayButton` (Android) | Standalone wallet button or `present()`. |

## Requirements

- Flutter 3.44+
- Dart 3.10+
- iOS 15.0+
- Android `minSdk` 23

Native SDKs: Android `com.xmoney:*` **1.1.0**, iOS `XMoneyPaymentSheet` **1.1.0**.

## Installation

```yaml
dependencies:
  xmoney: ^1.0.0
```

```bash
flutter pub get
cd ios && pod install   # iOS only
```

Put only a **publishable** `publicKey` (`pk_test_…` / `pk_live_…`) in the app. Create orders on **your server**. Never ship a secret API key.

## Payment Sheet

```dart
import 'package:xmoney/xmoney.dart';

final sheet = PaymentSheetController();

await sheet.init(PaymentConfig(publicKey: 'pk_test_…'));
final result = await sheet.present(intent);

switch (result) {
  case PaymentResultComplete(:final transaction):
    break;
  case PaymentResultFailed(:final error):
    break;
  case PaymentResultCanceled():
    break;
}
```

Full guide, Element, wallets, and order lifecycle: [github.com/xMoney-Payments/xmoney-flutter](https://github.com/xMoney-Payments/xmoney-flutter).

## Update an order

`updateOrder` rebinds a signed order you already have. Pay stays enabled while your server creates that order.

When the shopper changes the cart, use `updateOrderWith`. Pay locks immediately and stays locked until the order returned by the callback is bound, including during a debounce. If the callback throws, the previous order stays payable. If it throws before the first ready event, the surface binds the order the widget was mounted with and then sends ready.

Set the widget's `intent` to the intent `updateOrderWith` returns. A configuration change rebinds `widget.intent` on both platforms, so an order left only on the controller is replaced by the previous one. Changing the button appearance or whether it is enabled does not.

```dart
final next = await controller.updateOrderWith(() async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!controller.isUpdateCurrent) throw StateError('superseded');
  return createOrderOnYourServer(cartTotal);
});
setState(() => intent = next);
```

A newer call replaces an in-flight one and throws `XMoneyPaymentError` with code `SUPERSEDED_UPDATE_ORDER`. Check `isUpdateCurrent` after waiting so the older callback does not call your server. Keep the endpoint idempotent. During a charge it throws `PAYMENT_IN_PROGRESS` instead; show that error, because the order did not change. Changing the widget's `intent` during a charge does not throw. That order is bound when the charge ends.

`WalletPayButtonController` has the same `updateOrderWith` and `isUpdateCurrent` for a standalone Apple Pay or Google Pay button. The button locks while your server creates the order, so a fast tap cannot charge the previous one. `WalletPayReadyEvent` fires after the mount order is bound and the button has drawn. A failed mount bind sends `PaymentResultFailed` and no ready event. A later bind failure emits `WalletPayUpdateFailedEvent` and the button stays locked until an update succeeds. Those update events follow the same contract on both platforms.

## License

MIT. Security notes: [SECURITY.md](https://github.com/xMoney-Payments/xmoney-flutter/blob/main/SECURITY.md).
