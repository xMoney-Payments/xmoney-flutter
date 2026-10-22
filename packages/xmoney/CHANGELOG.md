# Changelog

All notable changes to the `xmoney` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-22

First stable release.

### Changed

- Pins native SDKs to CocoaPods `XMoneyPaymentSheet` **1.1.0** and Maven `com.xmoney:*` **1.1.0** (via `xmoney_android` and `xmoney_ios` 1.0.0).
- `Ready` fires once per mounted surface, after the form or wallet button has drawn. It is not emitted when the first load fails. The Apple Pay button waits for its mount order to bind as well.
- Set the widget's `intent` to the order `updateOrderWith` returns. A configuration change rebinds `widget.intent` on both platforms, so an order left only on the controller is replaced by the previous one. Changing wallet appearance or whether the button is enabled does not.
- Changing the widget's `intent` during a charge does not throw. That order is bound when the charge ends.

### Added

- `PaymentElementController.updateOrderWith` locks Pay before your callback creates the next order, matching native `updateOrder(createOrder:)`.
- `PaymentElementController.isUpdateCurrent`, so a debounced callback can stop before calling your server once a newer update has replaced it.
- `WalletPayButtonController.updateOrderWith` and `isUpdateCurrent` lock a standalone Apple Pay or Google Pay button while your server creates the next order.
- `PaymentElementUpdateFailedEvent` when binding a new order fails after one was already bound. Pay stays locked until a later `updateOrder` succeeds.
- `XMoneyPaymentError` code `PAYMENT_IN_PROGRESS` when `updateOrder` asks for a different order during a charge.

### Breaking changes

- Exhaustive switches on `PaymentElementEvent` must handle `PaymentElementUpdateFailedEvent`. Switches on `PaymentSheetEvent` and `WalletPayEvent` must handle the new update-failed event from `xmoney_platform_interface` 1.0.0.
- On iOS, a failed Apple Pay button `updateOrder` matches Google Pay: before any update has bound it sends a failed `onResult`; after one has, it sends `onUpdateFailed` and no `onResult`. `PAYMENT_IN_PROGRESS` sends neither. The button no longer emits `processing` during `updateOrder`.
- `updateOrderWith` throws `PAYMENT_IN_PROGRESS` during a charge, rather than `SUPERSEDED_UPDATE_ORDER`.

### Fixed

- If `updateOrderWith` throws before the first ready event, the surface binds the order the widget was mounted with and then sends ready.
- A widget-relayed intent rejected as `PAYMENT_IN_PROGRESS` is bound when the charge ends.
- `isUpdateCurrent` is per-controller, so a nested `updateOrderWith` on another controller does not steal the sequence.
- Passing an order the controller already sent no longer binds it again.
- A superseded `updateOrderWith` no longer reports an unhandled error while your callback is still running.
- The Apple Pay button binds its mount order, so a failed cart update locks the button instead of charging the previous order.
- A new intent on a wallet button with no controller now reaches the native button.
- Android: appearance-only Google Pay updates apply without recreating the native button (via `xmoney_android` 1.0.0).
- iOS: a rejected `updateOrderWith` before Ready rebinds the mount order. Appearance-only Apple Pay updates no longer tear down the button (via `xmoney_ios` 1.0.0).

### Migration

- End merchant loading on a failed `onResult` as well as `Ready`. A failed first load no longer emits `Ready`.

## [0.0.2] - 2026-10-13

### Fixed

- Android: `GooglePayButton` no longer stays loading forever, and no longer reports Google Pay as unavailable before the order has loaded (via `xmoney_android` 0.0.2).

## [0.0.1] - 2026-09-28

First public release.

Pins native SDKs to CocoaPods `XMoneyPaymentSheet` **1.0.1** and Maven `com.xmoney:*` **1.0.0**.

### Added

- Payment Sheet, Payment Element, Apple Pay, and Google Pay
