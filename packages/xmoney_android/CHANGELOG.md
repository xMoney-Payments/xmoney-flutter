# Changelog

All notable changes to the `xmoney_android` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2026-10-13

### Fixed

- `GooglePayButton` no longer stays loading forever. Composition crashed with a `ClassCastException` because the platform view context is a `MutableContextWrapper`, not the host `FragmentActivity`.
- `GooglePayButton` no longer reports Google Pay as unavailable before the order has loaded. `ready` and availability are sent once the native button has bound.

## [0.0.1] - 2026-09-28

First public release. Android implementation of the xMoney Flutter SDK.

Pins Maven `com.xmoney:paymentsheet`, `paymentelement`, and `googlepay` **1.0.0**.

### Added

- Federated Android plugin for Payment Sheet, Payment Element, and Google Pay
