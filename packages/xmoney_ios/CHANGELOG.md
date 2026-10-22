# Changelog

All notable changes to the `xmoney_ios` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-20

### Changed

- Pins CocoaPods `XMoneyPaymentSheet` to **1.1.0**.
- `Ready` is sent once the form or Apple Pay button has drawn, and not when the first load fails. The Apple Pay button waits for its mount order to bind as well.
- A failed Apple Pay button `updateOrder` matches Google Pay: before any update has bound it sends a failed `onResult`; after one has, it sends `onUpdateFailed` and no `onResult`. `PAYMENT_IN_PROGRESS` sends neither. The button no longer emits `processing` during `updateOrder`.

### Added

- `onUpdateFailed` when binding a new order fails after one was already bound. Pay stays locked until a later `updateOrder` succeeds.
- `PAYMENT_IN_PROGRESS` when `updateOrder` asks for a different order during a charge.

### Fixed

- Passing an order the view already sent no longer binds it again.
- The Apple Pay button binds its mount order, so a failed cart update locks the button instead of charging the previous order.
- A new intent on a wallet button with no controller now reaches the native button.

## [0.0.2] - 2026-10-13

No iOS changes. Version aligned with the other xMoney Flutter packages.

## [0.0.1] - 2026-09-28

First public release. iOS implementation of the xMoney Flutter SDK.

Pins CocoaPods `XMoneyPaymentSheet` **1.0.1**.

### Added

- Federated iOS plugin for Payment Sheet, Payment Element, and Apple Pay
