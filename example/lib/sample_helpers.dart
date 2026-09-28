import 'package:xmoney/xmoney.dart';

import 'backend/demo_checkout_backend.dart';
import 'theme/example_colors.dart';

const sampleAmountMinor = 1999;

UserInterfaceStyle exampleForcedStyle(bool dark) {
  return dark ? UserInterfaceStyle.alwaysDark : UserInterfaceStyle.alwaysLight;
}

WalletAppearance exampleWalletAppearance(bool dark) {
  return WalletAppearance(color: dark ? WalletButtonColor.white : WalletButtonColor.black);
}

AppearanceColors _appearanceColors({
  required String primary,
  required String background,
  required String component,
  required String text,
  required String muted,
  required String hairline,
}) {
  return AppearanceColors(
    primary: primary,
    background: background,
    componentBackground: component,
    componentBorder: hairline,
    componentDivider: hairline,
    primaryText: text,
    secondaryText: muted,
    componentText: text,
    placeholderText: muted,
    icon: muted,
    error: '#FF4757',
    containerBorder: hairline,
  );
}

AppearanceConfig exampleAppearance({
  String? primary,
  String? primaryDark,
  String? buttonBackground,
  String? buttonText,
}) {
  final p = primary ?? '#7C4DFF';
  final pDark = primaryDark ?? p;
  final payBg = buttonBackground ?? p;
  final payText = buttonText ?? '#FFFFFF';
  final pay = PrimaryButtonColors(background: payBg, text: payText);
  return AppearanceConfig(
    colorsLight: _appearanceColors(
      primary: p,
      background: '#F4F3FB',
      component: '#FFFFFF',
      text: '#16141A',
      muted: AppearanceHex.lightMuted,
      hairline: AppearanceHex.lightHairline,
    ),
    colorsDark: _appearanceColors(
      primary: pDark,
      background: '#09090B',
      component: '#18181B',
      text: '#FAFAFA',
      muted: '#A1A1AA',
      hairline: AppearanceHex.darkHairline,
    ),
    borderRadius: 24,
    primaryButton: PrimaryButtonConfig(
      colorsLight: pay,
      colorsDark: pay,
      borderRadius: 9999,
      borderWidth: 0,
    ),
  );
}

PaymentConfig defaultPaymentConfig(
  DemoSecrets secrets, {
  required bool dark,
  AppearanceConfig? appearance,
  bool applePayEnabled = true,
  bool googlePayEnabled = true,
  bool savedCardsEnabled = true,
}) {
  final wallet = exampleWalletAppearance(dark);
  return PaymentConfig(
    publicKey: secrets.publicKey,
    paymentMethods: PaymentMethodsConfig(
      applePay: ApplePayConfig(enabled: applePayEnabled, appearance: wallet),
      googlePay: GooglePayConfig(enabled: googlePayEnabled, appearance: wallet),
    ),
    card: CardConfig(
      savedCards: SavedCardsConfig(enabled: savedCardsEnabled),
    ),
    options: OptionsConfig(
      style: exampleForcedStyle(dark),
      appearance: appearance ?? exampleAppearance(),
    ),
  );
}

String formatMoney(int amountMinor, {String currency = 'EUR'}) {
  final amount = amountMinor / 100;
  final cur = currency.toUpperCase();
  final symbol = switch (cur) {
    'EUR' => '€',
    'USD' => '\$',
    'GBP' => '£',
    _ => '$cur ',
  };
  final fraction = amountMinor % 100 == 0 ? 0 : 2;
  return '$symbol${amount.toStringAsFixed(fraction)}';
}

bool isNativeBoundSheetEvent(PaymentSheetEvent event) {
  return event is PaymentSheetReadyEvent;
}

bool isNativeBoundElementEvent(PaymentElementEvent event) {
  return event is PaymentElementReadyEvent ||
      event is PaymentElementAvailabilityEvent;
}

bool isNativeBoundWalletEvent(WalletPayEvent event) {
  return event is WalletPayReadyEvent || event is WalletPayAvailabilityEvent;
}

String? bindFailureMessage(PaymentResult result) {
  if (result is! PaymentResultFailed) return null;
  return result.error.message.isNotEmpty
      ? result.error.message
      : result.error.code;
}

bool orderConsumed(PaymentResult result, bool didProcess) {
  if (result is PaymentResultComplete || result is PaymentResultFailed) {
    return true;
  }
  return didProcess;
}

String resultMessage(PaymentResult result) {
  return switch (result) {
    PaymentResultComplete(:final transaction) =>
      (transaction.id?.isNotEmpty ?? false)
          ? 'Paid · ${transaction.id}'
          : 'Payment complete',
    PaymentResultFailed(:final error) => error.message.isNotEmpty
        ? error.message
        : error.code,
    PaymentResultCanceled() => 'Canceled',
  };
}
