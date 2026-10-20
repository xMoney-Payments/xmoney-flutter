# Changelog

All notable changes to the `xmoney_android` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.3] - 2026-10-20

### Changed

- Pins Maven `com.xmoney:paymentsheet`, `paymentelement`, and `googlepay` to **1.1.0**.
- `Ready` is sent once the form or Google Pay button has drawn, and not when the first load fails.

### Added

- `onUpdateFailed` when binding a new order fails after one was already bound. Pay stays locked until a later `updateOrder` succeeds.
- `PAYMENT_IN_PROGRESS` when `updateOrder` asks for a different order during a charge. That call sends neither `onResult` nor `onUpdateFailed`.

### Fixed

- Passing an order the view already sent no longer binds it again.
- The Google Pay button binds its mount order, so a failed cart update locks the button instead of charging the previous order.
- A new intent on a wallet button with no controller now reaches the native button.

## [0.0.2] - 2026-10-13

### Fixed

- `GooglePayButton` no longer stays loading forever. Composition crashed with a `ClassCastException` because the platform view context is a `MutableContextWrapper`, not the host `FragmentActivity`.
- `GooglePayButton` no longer reports Google Pay as unavailable before the order has loaded. `ready` and availability are sent once the native button has bound.

## [0.0.1] - 2026-09-28

First public release. Android implementation of the xMoney Flutter SDK.

Pins Maven `com.xmoney:paymentsheet`, `paymentelement`, and `googlepay` **1.0.0**.

### Added

- Federated Android plugin for Payment Sheet, Payment Element, and Google Pay
