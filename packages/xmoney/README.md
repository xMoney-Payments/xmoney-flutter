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

Native SDKs: Android `com.xmoney:*` **1.0.0**, iOS `XMoneyPaymentSheet` **1.0.1**.

## Installation

```yaml
dependencies:
  xmoney: ^0.0.1
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

## License

MIT. Security notes: [SECURITY.md](https://github.com/xMoney-Payments/xmoney-flutter/blob/main/SECURITY.md).
