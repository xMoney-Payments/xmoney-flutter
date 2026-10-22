# Changelog

All notable changes to the `xmoney_platform_interface` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-22

First stable release.

### Added

- `PaymentSheetUpdateFailedEvent` and `WalletPayUpdateFailedEvent` when binding a new order fails after one was already bound. Pay stays locked until a later update succeeds.

### Breaking changes

- Exhaustive switches on `PaymentSheetEvent` and `WalletPayEvent` must handle the new update-failed event.

### Changed

- `Ready` is documented as firing once per mounted surface, after the first draw, and not when the first load fails.

## [0.0.2] - 2026-10-13

No changes. Version aligned with the other xMoney Flutter packages.

## [0.0.1] - 2026-09-28

First public release.

### Added

- Shared payment types and the platform contract for the xMoney Flutter SDK
