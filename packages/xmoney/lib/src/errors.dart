import 'package:flutter/services.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

/// SDK-authored messages for stable error codes.
const stableMessages = <String, String>{
  'NOT_LINKED': "The xmoney plugin is not linked.",
  'NOT_INITIALIZED': 'Call init before present.',
  'INVALID_PUBLIC_KEY': 'publicKey must include test or live.',
  'NO_PRESENTER': 'Unable to present from the current screen.',
  'PRESENT_ERROR': 'Failed to present',
  'LOAD_ERROR': 'Failed to load',
  'SUPERSEDED_UPDATE_ORDER': 'Superseded by a newer updateOrder call',
  'APPLE_PAY': 'Apple Pay is only available on iOS.',
  'GOOGLE_PAY': 'Google Pay is only available on Android.',
};

final _codeToken = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');
final _unsafeMessage = RegExp(
  r'orderPayload|orderChecksum|\bpan\b|\{',
  caseSensitive: false,
);

/// Returns a [PaymentError] safe to show in the merchant UI.
///
/// Drops messages that contain order bodies, PAN-like text, or raw JSON.
PaymentError sanitizePaymentError(String? code, String? message) {
  if (code != null && stableMessages.containsKey(code)) {
    return PaymentError(code: code, message: stableMessages[code]!);
  }
  final safeCode = code != null && _codeToken.hasMatch(code) ? code : 'UNKNOWN';
  final safeMessage =
      message != null &&
          message.isNotEmpty &&
          message.length <= 200 &&
          !_unsafeMessage.hasMatch(message)
      ? message
      : 'Payment failed';
  return PaymentError(code: safeCode, message: safeMessage);
}

/// Failure thrown by [PaymentElementController] and wallet updates.
///
/// [code] `NOT_LINKED` means the plugin is missing from the app.
class XMoneyPaymentError implements Exception, PaymentError {
  /// Creates an error with an SDK [code] and [message].
  XMoneyPaymentError(this.code, this.message);

  /// Stable error code, such as `NOT_LINKED`.
  @override
  final String code;

  /// SDK-authored message. Safe to display.
  @override
  final String message;

  /// `XMoneyPaymentError(code): message`.
  @override
  String toString() => 'XMoneyPaymentError($code): $message';

  /// Builds a sanitized error from a platform or payment failure.
  static XMoneyPaymentError from(Object? value) {
    if (value is XMoneyPaymentError) return value;
    String? code;
    String? message;
    if (value is PlatformException) {
      code = value.code;
      message = value.message;
    } else if (value is PaymentError) {
      code = value.code;
      message = value.message;
    } else if (value is Map) {
      code = value['code'] as String?;
      message = value['message'] as String?;
    }
    final sanitized = sanitizePaymentError(code, message);
    return XMoneyPaymentError(sanitized.code, sanitized.message);
  }
}

/// Maps an unknown platform failure to [PaymentResultFailed].
PaymentResult paymentResultFromUnknown(Object? value) {
  final error = XMoneyPaymentError.from(value);
  return PaymentResultFailed(error);
}
