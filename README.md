# xMoney Payments — Flutter SDK

Flutter SDK for [xMoney](https://xmoney.com) checkout. Three surfaces, one `PaymentConfig`, one `PaymentResult`. Card data never crosses the Dart platform channel.

| Surface             | API                                              | Use when                                                   |
| ------------------- | ------------------------------------------------ | ---------------------------------------------------------- |
| **Payment Sheet**   | `PaymentSheet`, `PaymentSheetController`         | Drop-in bottom sheet. SDK owns the UI and the Pay button. |
| **Payment Element** | `PaymentElement`, `PaymentElementController`     | Card, saved cards, and wallet **in your layout**.         |
| **Apple Pay**       | `ApplePay`, `ApplePayButton` (iOS)               | Standalone wallet button or `present()`.                  |
| **Google Pay**      | `GooglePay`, `GooglePayButton` (Android)         | Standalone wallet button or `present()`.                  |

## Requirements

- Flutter 3.44+
- Dart 3.10+
- iOS 15.0+
- Android `minSdk` 23

Native SDKs: Android `com.xmoney:*` **1.0.0**, iOS `XMoneyPaymentSheet` **1.0.1**.

## Installation

Latest release: **`0.0.1`**

```yaml
dependencies:
  xmoney: ^0.0.1
```

```bash
flutter pub get
cd ios && pod install   # iOS only
```

Put only a **publishable** `publicKey` (`pk_test_…` / `pk_live_…`) in the app. Create orders on **your server**. Never ship a secret API key.

## Android setup

Payment Sheet, Payment Element, and Google Pay present from a `FragmentActivity`.

1. `MainActivity` extends `FlutterFragmentActivity`. A plain `FlutterActivity` fails with `NO_PRESENTER`.
2. Set the app `minSdk` to at least 23.
3. Set `android:windowSoftInputMode="adjustResize"` on that activity so card fields clear the keyboard.
4. In `android/settings.gradle.kts`, declare the Android library plugin and the Compose compiler at the same version as the app’s Kotlin plugin:

```kotlin
id("com.android.library") version "9.1.0" apply false
id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
```

Match those versions to the app. The plugin compiles its Compose views with that compiler. If `android/gradle.properties` sets `android.builtInKotlin=false`, remove that line. AGP 9 compiles this plugin with built-in Kotlin, and that flag reapplies the Kotlin Gradle plugin.

5. Release builds that turn on R8 merge this plugin’s `consumer-rules.pro` (`-keep class com.xmoney.**`). Add extra `-dontwarn` rules only when the build asks for them.
6. Native plugin changes need a full rebuild. Hot reload does not pick them up.

## Checkout flow

1. Your backend creates an order and returns `payload` + `checksum`.
2. The app builds a `PaymentIntent` from those two values.
3. You present Sheet, mount Element, or show a wallet button.
4. The SDK fetches the session token, collects payment, and runs 3DS if needed.
5. You handle `PaymentResult`. Session tokens are never passed by the merchant.

```dart
final intent = PaymentIntent(
  orderPayload: payloadFromYourServer,
  orderChecksum: checksumFromYourServer,
);
```

## Payment result

Every surface delivers the same sealed type:

```dart
switch (result) {
  case PaymentResultComplete(:final transaction): // paid
  case PaymentResultFailed(:final error):         // error.code / error.message
  case PaymentResultCanceled():                   // user dismissed; no error payload
}
```

`failed` messages are SDK-authored. Do not display raw server bodies.

Interim events (`PaymentSheetReadyEvent`, `PaymentSheetProcessingEvent`) are optional and do not replace the result. Use `ready` to hide merchant loading until the surface is bound. `processing` is an in-flight charge only — `updateOrder` does not emit it.

## Order lifecycle

Order checksums are **one-shot**. After a consumed result the bound order cannot be charged again.

| Outcome                                           | Consumes order? | What you do                                  |
| ------------------------------------------------- | --------------- | -------------------------------------------- |
| `PaymentResultComplete`                           | Yes             | New `PaymentIntent` for another payment      |
| `PaymentResultFailed`                             | Yes             | New `PaymentIntent`                          |
| `PaymentResultCanceled` **after** pay / 3DS started | Yes           | New `PaymentIntent`                          |
| Sheet closed **before** pay (header, drag, scrim) | No              | Present the **same** intent again            |
| Wallet dismissed **before** authorization         | No              | Present / tap again with the **same** intent |

Embedded and wallet buttons stay mounted after a consumed result; Pay / wallet disable (`isOrderConsumed`). Unmount them, or pass a **new** `intent`.

Payment Sheet dismisses on terminal results (including post-submit cancel). Present again with a new intent.

Use `onEvent` `PaymentSheetProcessingEvent` (or `isOrderConsumed` on Element / wallet buttons) to tell pre-pay cancel apart from post-submit cancel.

## Payment Sheet

SDK owns the full checkout UI, including the Pay button (`card.submitButton.visible` is ignored).

**Controller**

```dart
import 'package:xmoney/xmoney.dart';

final sheet = PaymentSheetController();

await sheet.init(PaymentConfig(
  publicKey: 'pk_test_…',
  paymentMethods: PaymentMethodsConfig(
    applePay: ApplePayConfig(enabled: true),
    googlePay: GooglePayConfig(enabled: true),
  ),
  card: CardConfig(savedCards: SavedCardsConfig(enabled: true)),
));

final result = await sheet.present(
  intent,
  onEvent: (event) {
    if (event is PaymentSheetReadyEvent) {
      // hide merchant loading
    }
  },
);

if (result is PaymentResultComplete) {
  // result.transaction
}
```

`sheet.loading` is true while `init` is in flight.

**Imperative**

```dart
await PaymentSheet.init(PaymentConfig(publicKey: 'pk_test_…'));
final result = await PaymentSheet.present(intent);
PaymentSheet.dismiss(); // optional; idle close still cancels
```

While idle, the sheet can be dragged closed. Drag, back, and scrim lock while a charge is in flight. `dismiss()` waits for an in-flight charge; idle close still cancels. A second `present()` while a charge is in flight returns `PaymentResultCanceled` without opening another sheet.

Copy-paste sample: [`payment_sheet_sample.dart`](example/lib/samples/payment_sheet_sample.dart)

## Payment Element

Same form as the sheet, without the bottom-sheet chrome. Mount it in your layout. Embedded does not add outer content padding or a page fill — the host background shows through; supply your own page spacing. Keep merchant loading until `onEvent` `PaymentElementReadyEvent`.

```dart
import 'package:xmoney/xmoney.dart';

PaymentElement(
  configuration: PaymentConfig(
    publicKey: 'pk_test_…',
    paymentMethods: PaymentMethodsConfig(
      applePay: ApplePayConfig(enabled: true),
      googlePay: GooglePayConfig(enabled: true),
    ),
  ),
  intent: intent,
  onEvent: (event) {
    switch (event) {
      case PaymentElementReadyEvent():
        // hide merchant loading
      case PaymentElementAvailabilityEvent(
          :final isOrderConsumed,
          :final isInteractionEnabled,
        ):
        // gate Pay / wallet
      case PaymentElementProcessingEvent():
        break;
    }
  },
  onResult: (result) {
    if (result is PaymentResultComplete) {
      // result.transaction
    }
  },
)
```

After `PaymentResultComplete` / `PaymentResultFailed` / post-submit `PaymentResultCanceled`, hide the element (or pass a new `intent`). Pre-pay cancel does not consume — keep it mounted.

### Update the order

`PaymentElementController.updateOrder` (or changing the `intent` passed to `PaymentElement`) rebinds a new signed `PaymentIntent` on the mounted Element. Pay, `confirm()`, and wallet buttons are disabled until bind finishes (`isInteractionEnabled` is false). A newer `updateOrder` cancels the in-flight one. The Pay button keeps its current title; it does not show “Processing...”.

```dart
await controller.updateOrder(nextIntent);
```

Keep the surface mounted; do not swap the form for a loader. Gate a merchant-owned Pay button with `isInteractionEnabled`.

Copy-paste sample: [`update_order_sample.dart`](example/lib/advanced/update_order_sample.dart)

### Live appearance

Call `updateAppearance` / `updateLocale` / `updateStyle` / `updateWalletAppearance` on `PaymentElementController` instead of recreating `PaymentConfig` for style-only changes. Changing `publicKey`, `card`, or `paymentMethods` pushes a full native update.

Payment Sheet snapshots config at `present()` — pass appearance on `PaymentConfig` and present again to replace an idle sheet.

### Merchant-owned Pay button

Embedded only. Hide the SDK button and call `confirm()` after `PaymentElementReadyEvent`:

```dart
final controller = PaymentElementController();

PaymentElement(
  controller: controller,
  configuration: PaymentConfig(
    publicKey: 'pk_test_…',
    card: CardConfig(
      submitButton: SubmitButtonConfig(visible: false),
    ),
  ),
  intent: intent,
  onEvent: (event) {
    if (event is PaymentElementReadyEvent) {
      // enable your Pay button
    }
  },
  onResult: (result) { /* PaymentResult */ },
);

FilledButton(
  onPressed: () => controller.confirm(),
  child: const Text('Pay'),
);
```

`confirm()` submits the currently selected method (new card or saved card). Wallet buttons still use the native wallet UI. `isInteractionEnabled` is false during `updateOrder` and while a charge is in flight. `PaymentElementProcessingEvent` is the in-flight charge only.

Copy-paste sample: [`payment_element_sample.dart`](example/lib/samples/payment_element_sample.dart) · Merchant CTA: [`merchant_confirm_sample.dart`](example/lib/advanced/merchant_confirm_sample.dart)

## Apple Pay

**iOS only.** `ApplePayButton` renders nothing on Android. `ApplePay.present` on Android returns `PaymentResultFailed` with code `APPLE_PAY`.

```dart
import 'package:xmoney/xmoney.dart';

await ApplePay.init(PaymentConfig(publicKey: 'pk_test_…'));

final state = await ApplePay.getState();
if (state.isAvailable && state.isReady) {
  final result = await ApplePay.present(intent);
}

ApplePay.dismiss(); // closes PassKit before authorize; no-op during token submit / 3DS

ApplePayButton(
  configuration: PaymentConfig(publicKey: 'pk_test_…'),
  intent: intent,
  appearance: WalletAppearance(
    color: WalletButtonColor.black,
    type: WalletButtonType.buy,
  ),
  onResult: (result) { /* PaymentResult */ },
)
```

`ApplePay.updateOrder` rebinds a signed `PaymentIntent` on the session opened by `present`. Before that session exists it throws `XMoneyPaymentError` (`NOT_INITIALIZED`). After `getState` or wallet-button `onEvent` `WalletPayAvailabilityEvent`, gate your own chrome with `isAvailable`, `isReady`, `isOrderConsumed`, and `isInteractionEnabled`.

Pre-auth dismiss delivers `PaymentResultCanceled` and does **not** consume. Present or tap again with the same intent.

### Setup

1. Enable Apple Pay: `paymentMethods.applePay.enabled: true`.
2. Create a Merchant ID in [Apple Developer](https://developer.apple.com/account/resources/identifiers/list/merchant).
3. In Xcode: app target → **Signing & Capabilities** → **Apple Pay** → add that Merchant ID.
4. The Merchant ID must match xMoney wallet params.
5. Test on a **physical device** with a card in Wallet.

`getState` uses `canMakePayments()` and reports whether the device can use Apple Pay. A missing Apple Pay capability fails when the sheet opens, not in `getState`.

Copy-paste sample: [`wallet_pay_sample.dart`](example/lib/samples/wallet_pay_sample.dart)

## Google Pay

**Android only.** `GooglePayButton` renders nothing on iOS. `GooglePay.present` on iOS returns `PaymentResultFailed` with code `GOOGLE_PAY`.

```dart
import 'package:xmoney/xmoney.dart';

await GooglePay.init(PaymentConfig(publicKey: 'pk_test_…'));

final state = await GooglePay.getState(intent);
if (state.isAvailable && state.isReady) {
  final present = GooglePay.present(intent);
  await GooglePay.updateOrder(nextIntent); // while overlay is open
  final result = await present;
}

GooglePayButton(
  configuration: PaymentConfig(publicKey: 'pk_test_…'),
  intent: intent,
  appearance: WalletAppearance(
    color: WalletButtonColor.black,
    type: WalletButtonType.buy,
  ),
  onResult: (result) { /* PaymentResult */ },
)
```

`GooglePay.updateOrder` rebinds the open host — call **after** `present`, while the overlay is still open. Throws if no host is open. A second `present()` while one is in flight returns `PaymentResultCanceled` — `dismiss()` then `present()` to replace.

Pre-auth dismiss delivers `PaymentResultCanceled` and does **not** consume. Present or tap again with the same intent.

The device needs Google Play services. Test versus production comes from the order (`PRODUCTION` or test), not from a Flutter flag. The Play Wallet manifest entry is merged from the Google Pay SDK.

Copy-paste sample: [`wallet_pay_sample.dart`](example/lib/samples/wallet_pay_sample.dart)

## Configuration

```dart
PaymentConfig(
  publicKey: 'pk_test_…',
  paymentMethods: PaymentMethodsConfig(
    applePay: ApplePayConfig(
      enabled: true,
      appearance: WalletAppearance(
        color: WalletButtonColor.black, // white, whiteOutline
        radius: 12,
        type: WalletButtonType.pay, // book, buy, checkout, donate, topUp
      ),
    ),
    googlePay: GooglePayConfig(
      enabled: true,
      appearance: WalletAppearance(
        color: WalletButtonColor.black,
        radius: 12,
        type: WalletButtonType.pay,
      ),
    ),
  ),
  card: CardConfig(
    savedCards: SavedCardsConfig(enabled: true, optInVisible: true),
    validationMode: ValidationMode.onTouched,
    inputs: CardInputsConfig(grouping: CardGrouping.condensed),
    submitButton: SubmitButtonConfig(
      visible: true, // Embedded only
      type: SubmitButtonType.pay, // book, buy, checkout, donate, …
    ),
  ),
  options: OptionsConfig(
    locale: 'en-US', // UI language + pay-button amount punctuation
    style: UserInterfaceStyle.automatic,
    appearance: AppearanceConfig(
      colorsLight: AppearanceColors(primaryText: '#16141a'),
      colorsDark: AppearanceColors(primaryText: '#f7f6f9'),
      borderRadius: 12, // card fields + methods container
      primaryButton: PrimaryButtonConfig(borderRadius: 12),
    ),
  ),
)
```

**Card validation** (`card.validationMode`, default `ValidationMode.onTouched`):

| Mode       | When errors show                                                     |
| ---------- | -------------------------------------------------------------------- |
| `onTouched` | None while first typing; on blur; then live. After Pay, always live. |
| `onChange` | Live from the first keystroke                                        |
| `onBlur`   | On blur; frozen until the next blur (live after Pay)                 |
| `onSubmit` | On Pay (then live)                                                   |

Pay uses current field validity. Cardholder name is always collected.

**Appearance** — pass `colorsLight` / `colorsDark` so the form matches your chrome. Card fields use `appearance.borderRadius` (default 16) and `colors.componentBorder`. Pay button radius comes from `appearance.primaryButton.borderRadius` (default a pill, `9999`). Pass `12` for a squircle. On a mounted Element, call `updateAppearance` / `updateStyle` / `updateWalletAppearance`. See [`exampleAppearance()`](example/lib/sample_helpers.dart) for a copy-paste palette.

**Locale** — `options.locale` sets UI copy and pay-button amount punctuation. Supported languages: `en`, `el`, `ro`, `bg`, `hu`, `pl`. Region tags (`en-US`, `pl-PL`) work; unknown languages fall back to English.

## Card holder verification

Optional pre-pay name check. Requires the site to have name-check validation enabled.

```dart
card: CardConfig(
  cardHolderVerification: CardHolderVerification(
    name: CardHolderName(firstName: 'John', lastName: 'Doe'),
    onCardHolderVerification: (result) {
      return result.status == CardHolderMatchStatus.matched;
    },
  ),
),
```

Return `true` to continue pay, `false` to block. The callback must return immediately and must not do network or other async work. If it does not answer within 2 seconds, the SDK declines the check. Sample: [`card_holder_verification_sample.dart`](example/lib/advanced/card_holder_verification_sample.dart)

## Public API

Use only these merchant-facing exports from `package:xmoney/xmoney.dart`:

| Surface         | Types |
| --------------- | ----- |
| Config / models | `PaymentConfig` and nested options, `PaymentIntent`, `PaymentResult`, `PaymentError`, `Transaction`, `CardHolderVerificationResult` |
| Payment Sheet   | `PaymentSheet`, `PaymentSheetController`, `PaymentSheetEvent` (`PaymentSheetReadyEvent`, `PaymentSheetProcessingEvent`) |
| Payment Element | `PaymentElement`, `PaymentElementController` (`confirm`, `updateOrder`, `updateAppearance`, `updateLocale`, `updateStyle`, `updateWalletAppearance`), `PaymentElementEvent` |
| Apple Pay       | `ApplePay` (`init`, `present`, `updateOrder`, `dismiss`, `getState`), `ApplePayButton`, `WalletPayButtonController`, `WalletPayEvent` |
| Google Pay      | `GooglePay` (`init`, `present`, `updateOrder`, `dismiss`, `getState`), `GooglePayButton`, `WalletPayButtonController`, `WalletPayEvent` |
| Errors          | `XMoneyPaymentError` (`NOT_LINKED` when the plugin is missing) |

## PCI scope

Card fields live entirely inside the native SDKs. This wrapper never receives raw PAN / CVV. Merchants should follow xMoney integration guidance and the SAQ attestation provided with native SDK certification.

## Example app

In-repo demo: copy-paste Integrations (Sheet / Element / Apple Pay or Google Pay), Lumen / Hearth / Pulse stores, merchant CTA / `updateOrder` / name-check, and an internal playground. See [`example/README.md`](example/README.md) for the launcher map, secrets, and consumption notes.

```bash
cp example/secrets.json.example example/secrets.json
# PUBLIC_KEY, API_KEY, API_BASE, CURRENCY, DESCRIPTION

cd example && flutter run
```

The example talks to a demo backend with `API_KEY` in the app. **Do not ship that pattern.** Production apps hold only `publicKey`; your server returns `payload` + `checksum`.

## Testing

```bash
flutter analyze packages/xmoney packages/xmoney_platform_interface
flutter test --directory packages/xmoney
```

## Support

- Releases: [CHANGELOG.md](CHANGELOG.md)
- Security: [SECURITY.md](SECURITY.md) — report vulnerabilities to **it-team@xmoney.com**, not a public issue
- License: [MIT](LICENSE)
