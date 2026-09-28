import 'dart:convert';

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'bridge_utils.dart';
import 'card_holder_verification.dart';
import 'errors.dart';
import 'native_event_router.dart';
import 'parse_result.dart';
import 'platform_target.dart';
import 'present_session.dart';
import 'wallet_state.dart';

final _appleSession = PresentSession();

/// Apple Pay on iOS.
///
/// [present] on Android returns [PaymentResultFailed] with code `APPLE_PAY`.
/// [ApplePayButton] renders nothing on Android.
abstract final class ApplePay {
  /// Stores [configuration] for a later [present]. No-op on Android.
  static Future<void> init(PaymentConfig configuration) async {
    if (!isIOS) return;
    final json = jsonEncode(toNativeConfiguration(configuration, chvSheetId));
    await XMoneyPlatform.instance.initApplePay(json);
  }

  /// Opens the Apple Pay sheet for [intent].
  ///
  /// [onEvent] receives ready and processing events for this call.
  /// On Android this returns [PaymentResultFailed] with code `APPLE_PAY`.
  static Future<PaymentResult> present(
    PaymentIntent intent, {
    void Function(ApplePayEvent event)? onEvent,
  }) async {
    if (!isIOS) {
      return PaymentResultFailed(
        PaymentError(code: 'APPLE_PAY', message: stableMessages['APPLE_PAY']!),
      );
    }
    if (_appleSession.begin(assumeProcessing: true) == 'canceled') {
      return const PaymentResultCanceled();
    }
    final generation = _appleSession.generation;
    final requestId = nextBridgeRequestId();
    attachNativeEventHandler(requestId, generation, _appleSession, onEvent);
    try {
      final payload = jsonEncode({...intent.toJson(), 'requestId': requestId});
      final raw = await XMoneyPlatform.instance.presentApplePay(payload);
      return parsePaymentResult(raw);
    } catch (error) {
      return paymentResultFromUnknown(error);
    } finally {
      _appleSession.finish(generation);
      detachNativeEventHandler(requestId);
    }
  }

  /// Rebinds [intent] on the sheet opened by [present].
  ///
  /// Throws [XMoneyPaymentError] on Android, and before [present] has opened a session.
  static Future<void> updateOrder(PaymentIntent intent) async {
    if (!isIOS) {
      throw XMoneyPaymentError('APPLE_PAY', stableMessages['APPLE_PAY']!);
    }
    await XMoneyPlatform.instance.updateApplePayOrder(
      jsonEncode(intent.toJson()),
    );
  }

  /// Closes the sheet before authorization. No-op on Android and during token submit.
  static void dismiss() {
    if (isIOS) {
      XMoneyPlatform.instance.dismissApplePay();
    }
  }

  /// Whether this device can use Apple Pay.
  ///
  /// On Android every flag is false except [WalletState.isInteractionEnabled].
  static Future<WalletState> getState() async {
    if (!isIOS) {
      return const WalletState(
        isAvailable: false,
        isReady: false,
        isOrderConsumed: false,
        isInteractionEnabled: true,
      );
    }
    final raw = await XMoneyPlatform.instance.getApplePayState();
    return parseWalletState(raw);
  }
}
