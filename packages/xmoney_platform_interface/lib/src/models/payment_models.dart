enum ValidationMode {
  onSubmit('onSubmit'),
  onChange('onChange'),
  onBlur('onBlur'),
  onTouched('onTouched');

  const ValidationMode(this.value);
  final String value;
}

enum SubmitButtonType {
  book('book'),
  buy('buy'),
  checkout('checkout'),
  donate('donate'),
  order('order'),
  pay('pay'),
  subscribe('subscribe'),
  topUp('topUp'),
  deposit('deposit');

  const SubmitButtonType(this.value);
  final String value;
}

enum UserInterfaceStyle {
  automatic('automatic'),
  alwaysLight('alwaysLight'),
  alwaysDark('alwaysDark');

  const UserInterfaceStyle(this.value);
  final String value;
}

enum CardGrouping {
  condensed('condensed'),
  spaced('spaced');

  const CardGrouping(this.value);
  final String value;
}

enum CardHolderMatchStatus {
  matched('Matched'),
  notMatched('NotMatched'),
  notVerified('NotVerified'),
  partialMatched('PartialMatched'),
  notSupported('NotSupported');

  const CardHolderMatchStatus(this.value);
  final String value;

  static CardHolderMatchStatus? tryParse(String? raw) {
    if (raw == null) return null;
    for (final status in values) {
      if (status.value == raw) return status;
    }
    return null;
  }
}

class CardHolderVerificationResult {
  const CardHolderVerificationResult({
    required this.status,
    this.firstNameStatus,
    this.middleNameStatus,
    this.lastNameStatus,
  });

  final CardHolderMatchStatus status;
  final CardHolderMatchStatus? firstNameStatus;
  final CardHolderMatchStatus? middleNameStatus;
  final CardHolderMatchStatus? lastNameStatus;
}

/// Interim events from Payment Sheet and wallet present flows.
sealed class PaymentSheetEvent {
  const PaymentSheetEvent();
}

/// The native surface finished binding the order and is interactive.
final class PaymentSheetReadyEvent extends PaymentSheetEvent {
  const PaymentSheetReadyEvent();
}

/// Charge lifecycle for imperative present APIs.
final class PaymentSheetProcessingEvent extends PaymentSheetEvent {
  const PaymentSheetProcessingEvent(this.isProcessing);

  final bool isProcessing;
}

typedef EmbeddedEvent = PaymentSheetEvent;
typedef ApplePayEvent = PaymentSheetEvent;
typedef GooglePayEvent = PaymentSheetEvent;

/// Interim events from embedded wallet buttons.
sealed class WalletPayEvent {
  const WalletPayEvent();
}

final class WalletPayReadyEvent extends WalletPayEvent {
  const WalletPayReadyEvent();
}

final class WalletPayProcessingEvent extends WalletPayEvent {
  const WalletPayProcessingEvent(this.isProcessing);

  final bool isProcessing;
}

final class WalletPayAvailabilityEvent extends WalletPayEvent {
  const WalletPayAvailabilityEvent({
    required this.isAvailable,
    required this.isReady,
    required this.isOrderConsumed,
    required this.isInteractionEnabled,
  });

  final bool isAvailable;
  final bool isReady;
  final bool isOrderConsumed;
  final bool isInteractionEnabled;
}

enum WalletButtonColor {
  white('white'),
  black('black'),
  whiteOutline('white-outline');

  const WalletButtonColor(this.value);
  final String value;
}

enum WalletButtonType {
  plain('plain'),
  pay('pay'),
  buy('buy'),
  book('book'),
  checkout('checkout'),
  donate('donate'),
  order('order'),
  subscribe('subscribe'),
  topUp('topUp');

  const WalletButtonType(this.value);
  final String value;
}

class AppearanceColors {
  const AppearanceColors({
    this.primary,
    this.background,
    this.componentBackground,
    this.componentBorder,
    this.componentDivider,
    this.primaryText,
    this.secondaryText,
    this.componentText,
    this.placeholderText,
    this.icon,
    this.error,
    this.containerBorder,
  });

  final String? primary;
  final String? background;
  final String? componentBackground;
  final String? componentBorder;
  final String? componentDivider;
  final String? primaryText;
  final String? secondaryText;
  final String? componentText;
  final String? placeholderText;
  final String? icon;
  final String? error;
  final String? containerBorder;

  Map<String, dynamic> toJson() => {
        if (primary != null) 'primary': primary,
        if (background != null) 'background': background,
        if (componentBackground != null) 'componentBackground': componentBackground,
        if (componentBorder != null) 'componentBorder': componentBorder,
        if (componentDivider != null) 'componentDivider': componentDivider,
        if (primaryText != null) 'primaryText': primaryText,
        if (secondaryText != null) 'secondaryText': secondaryText,
        if (componentText != null) 'componentText': componentText,
        if (placeholderText != null) 'placeholderText': placeholderText,
        if (icon != null) 'icon': icon,
        if (error != null) 'error': error,
        if (containerBorder != null) 'containerBorder': containerBorder,
      };
}

class PrimaryButtonColors {
  const PrimaryButtonColors({this.background, this.text, this.border});

  final String? background;
  final String? text;
  final String? border;

  Map<String, dynamic> toJson() => {
        if (background != null) 'background': background,
        if (text != null) 'text': text,
        if (border != null) 'border': border,
      };
}

class PrimaryButtonConfig {
  const PrimaryButtonConfig({
    this.fontFamily,
    this.colors,
    this.colorsLight,
    this.colorsDark,
    this.borderRadius,
    this.borderWidth,
  });

  final String? fontFamily;
  final PrimaryButtonColors? colors;
  final PrimaryButtonColors? colorsLight;
  final PrimaryButtonColors? colorsDark;
  final double? borderRadius;
  final double? borderWidth;

  Map<String, dynamic> toJson() => {
        if (fontFamily != null) 'font': {'family': fontFamily},
        if (colors != null) 'colors': colors!.toJson(),
        if (colorsLight != null) 'colorsLight': colorsLight!.toJson(),
        if (colorsDark != null) 'colorsDark': colorsDark!.toJson(),
        if (borderRadius != null || borderWidth != null)
          'shapes': {
            if (borderRadius != null) 'borderRadius': borderRadius,
            if (borderWidth != null) 'borderWidth': borderWidth,
          },
      };
}

class AppearanceConfig {
  const AppearanceConfig({
    this.fontFamily,
    this.fontScale,
    this.colors,
    this.colorsLight,
    this.colorsDark,
    this.borderRadius,
    this.borderWidth,
    this.primaryButton,
  });

  final String? fontFamily;
  final double? fontScale;
  final AppearanceColors? colors;
  final AppearanceColors? colorsLight;
  final AppearanceColors? colorsDark;
  final double? borderRadius;
  final double? borderWidth;
  final PrimaryButtonConfig? primaryButton;

  Map<String, dynamic> toJson() => {
        if (fontFamily != null || fontScale != null)
          'font': {
            if (fontFamily != null) 'family': fontFamily,
            if (fontScale != null) 'scale': fontScale,
          },
        if (colors != null) 'colors': colors!.toJson(),
        if (colorsLight != null) 'colorsLight': colorsLight!.toJson(),
        if (colorsDark != null) 'colorsDark': colorsDark!.toJson(),
        if (borderRadius != null || borderWidth != null)
          'shapes': {
            if (borderRadius != null) 'borderRadius': borderRadius,
            if (borderWidth != null) 'borderWidth': borderWidth,
          },
        if (primaryButton != null) 'primaryButton': primaryButton!.toJson(),
      };
}

class SavedCardsConfig {
  const SavedCardsConfig({this.enabled, this.optInVisible});

  final bool? enabled;
  final bool? optInVisible;

  Map<String, dynamic> toJson() => {
        if (enabled != null) 'enabled': enabled,
        if (optInVisible != null) 'optInVisible': optInVisible,
      };
}

class CardHolderName {
  const CardHolderName({
    required this.firstName,
    this.middleName,
    required this.lastName,
  });

  final String firstName;
  final String? middleName;
  final String lastName;
}

class CardHolderVerification {
  const CardHolderVerification({
    required this.name,
    required this.onCardHolderVerification,
  });

  final CardHolderName name;
  final bool Function(CardHolderVerificationResult result)
      onCardHolderVerification;
}

class CardInputsConfig {
  const CardInputsConfig({this.grouping});

  final CardGrouping? grouping;

  Map<String, dynamic> toJson() => {
        if (grouping != null) 'grouping': grouping!.value,
      };
}

class SubmitButtonConfig {
  const SubmitButtonConfig({this.visible, this.type});

  final bool? visible;
  final SubmitButtonType? type;

  Map<String, dynamic> toJson() => {
        if (visible != null) 'visible': visible,
        if (type != null) 'type': type!.value,
      };
}

class CardConfig {
  const CardConfig({
    this.savedCards,
    this.cardHolderVerification,
    this.inputs,
    this.validationMode,
    this.submitButton,
  });

  final SavedCardsConfig? savedCards;
  final CardHolderVerification? cardHolderVerification;
  final CardInputsConfig? inputs;
  final ValidationMode? validationMode;
  final SubmitButtonConfig? submitButton;

  Map<String, dynamic> toJson() => {
        if (savedCards != null) 'savedCards': savedCards!.toJson(),
        if (inputs != null) 'inputs': inputs!.toJson(),
        if (validationMode != null) 'validationMode': validationMode!.value,
        if (submitButton != null) 'submitButton': submitButton!.toJson(),
      };
}

class WalletAppearance {
  const WalletAppearance({this.color, this.radius, this.type});

  final WalletButtonColor? color;
  final double? radius;
  final WalletButtonType? type;

  Map<String, dynamic> toJson() => {
        if (color != null) 'color': color!.value,
        if (radius != null) 'radius': radius,
        if (type != null) 'type': type!.value,
      };
}

class ApplePayConfig {
  const ApplePayConfig({this.enabled, this.appearance});

  final bool? enabled;
  final WalletAppearance? appearance;

  Map<String, dynamic> toJson() => {
        if (enabled != null) 'enabled': enabled,
        if (appearance != null) 'appearance': appearance!.toJson(),
      };
}

class GooglePayConfig {
  const GooglePayConfig({this.enabled, this.appearance});

  final bool? enabled;
  final WalletAppearance? appearance;

  Map<String, dynamic> toJson() => {
        if (enabled != null) 'enabled': enabled,
        if (appearance != null) 'appearance': appearance!.toJson(),
      };
}

class PaymentMethodsConfig {
  const PaymentMethodsConfig({this.applePay, this.googlePay});

  final ApplePayConfig? applePay;
  final GooglePayConfig? googlePay;

  Map<String, dynamic> toJson() => {
        if (applePay != null) 'applePay': applePay!.toJson(),
        if (googlePay != null) 'googlePay': googlePay!.toJson(),
      };
}

class OptionsConfig {
  const OptionsConfig({this.locale, this.style, this.appearance});

  final String? locale;
  final UserInterfaceStyle? style;
  final AppearanceConfig? appearance;

  Map<String, dynamic> toJson() => {
        if (locale != null) 'locale': locale,
        if (style != null) 'style': style!.value,
        if (appearance != null) 'appearance': appearance!.toJson(),
      };
}

class PaymentConfig {
  const PaymentConfig({
    required this.publicKey,
    this.card,
    this.paymentMethods,
    this.options,
  });

  final String publicKey;
  final CardConfig? card;
  final PaymentMethodsConfig? paymentMethods;
  final OptionsConfig? options;

  Map<String, dynamic> toJson() => {
        'publicKey': publicKey,
        if (card != null) 'card': card!.toJson(),
        if (paymentMethods != null) 'paymentMethods': paymentMethods!.toJson(),
        if (options != null) 'options': options!.toJson(),
      };
}

class PaymentIntent {
  const PaymentIntent({
    required this.orderPayload,
    required this.orderChecksum,
  });

  final String orderPayload;
  final String orderChecksum;

  Map<String, dynamic> toJson() => {
        'orderPayload': orderPayload,
        'orderChecksum': orderChecksum,
      };
}

class TransactionCustomer {
  const TransactionCustomer({
    this.id,
    this.siteId,
    this.identifier,
    this.firstName,
    this.lastName,
    this.country,
    this.state,
    this.city,
    this.zipCode,
    this.address,
    this.phone,
    this.email,
    this.isWhitelisted,
    this.isWhitelistedUntil,
    this.creationDate,
    this.creationTimestamp,
  });

  final String? id;
  final String? siteId;
  final String? identifier;
  final String? firstName;
  final String? lastName;
  final String? country;
  final String? state;
  final String? city;
  final String? zipCode;
  final String? address;
  final String? phone;
  final String? email;
  final bool? isWhitelisted;
  final String? isWhitelistedUntil;
  final String? creationDate;
  final int? creationTimestamp;
}

class Transaction {
  const Transaction({
    this.id,
    this.status,
    this.amount,
    this.currencyKey,
    this.amountInEuro,
    this.externalOrderId,
    this.description,
    this.customerData,
  });

  final String? id;
  final String? status;
  final String? amount;
  final String? currencyKey;
  final String? amountInEuro;
  final String? externalOrderId;
  final String? description;
  final TransactionCustomer? customerData;
}

class PaymentError {
  const PaymentError({required this.code, required this.message});

  final String code;
  final String message;
}

sealed class PaymentResult {
  const PaymentResult();
}

class PaymentResultComplete extends PaymentResult {
  const PaymentResultComplete(this.transaction);

  final Transaction transaction;
}

class PaymentResultFailed extends PaymentResult {
  const PaymentResultFailed(this.error);

  final PaymentError error;
}

class PaymentResultCanceled extends PaymentResult {
  const PaymentResultCanceled();
}

class WalletState {
  const WalletState({
    required this.isAvailable,
    required this.isReady,
    required this.isOrderConsumed,
    required this.isInteractionEnabled,
  });

  final bool isAvailable;
  final bool isReady;
  final bool isOrderConsumed;
  final bool isInteractionEnabled;
}
