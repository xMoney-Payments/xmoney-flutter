# xMoney Flutter example app

In-repo demo for the SDK. One Flutter app, a launcher, copy-paste samples, three merchant scenarios, and an internal playground.

Sun/moon toggle for **light / dark** (saved across Integrations, Advanced, and Playground). Scenario stores hide it and use their own accent. Samples pass a matching `AppearanceConfig` (`colorsLight` / `colorsDark`) so the SDK form sits on the merchant page instead of the library defaults.

## Run

```bash
cp secrets.json.example secrets.json
# Fill PUBLIC_KEY, API_KEY, API_BASE, CURRENCY, DESCRIPTION

flutter pub get
cd ios && pod install && cd ..
flutter run
# or pick a device: flutter run -d <device_id>
```

Requires Flutter 3.44+ and Dart 3.10+.

Apple Pay only authorizes on a **physical device**. Add the Merchant ID under Signing & Capabilities; it must match xMoney wallet params.

## Launcher

| Section | Screen | What it is |
|---|---|---|
| Integrations | Payment Sheet | Drop-in sheet — copy this first. |
| Integrations | Embedded Payment Element | Form in your layout. |
| Integrations | Apple Pay / Google Pay | Standalone wallet button (platform). |
| Example app | Lumen shop | Lifestyle catalog → cart → Payment Sheet |
| Example app | Hearth Café | Café menu → cart → Embedded Element |
| Example app | Pulse Studio | Memberships → cart → Embedded Element |
| Advanced | Merchant Pay button | Embedded form, your CTA via `confirm()` |
| Advanced | Update order | `updateOrder` a new `PaymentIntent` on a mounted Element |
| Advanced | Card holder verification | Pre-pay name check |
| Internal | Playground | Every `PaymentConfig` option — SDK development |

Integrations and name-check include a **Test cards** sheet with the four xMoney simulator PANs (copy PAN / expiry / CVV / 3DS, success and fail).

## Backend warning

[`DemoCheckoutBackend`](lib/backend/demo_checkout_backend.dart) sends `API_KEY` to the public demo server so this app can create orders without a merchant backend.

**Do not copy that into production.** The Flutter app should hold only `publicKey`. Your server creates the order and returns `payload` + `checksum`. The samples build `PaymentIntent` from those two values.

## Copy-paste notes

- Integrations samples use `defaultPaymentConfig()` with saved cards and example appearance — adjust for your brand.
- After `complete`, `failed`, or post-submit `canceled`, the order checksum is **consumed**. Create a new intent before paying again.
- Closing Payment Sheet **before** pay does not consume; present the same intent (**Continue**).
- Embedded / wallet: keep merchant loading until `onEvent` `ready`. Branch on `isOrderConsumed` after that.
- Cart amounts are **minor units** (cents). The demo backend converts to a decimal only at the HTTP boundary.
