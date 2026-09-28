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

final _googleSession = PresentSession();

/// Google Pay on Android.
///
/// [present] on iOS returns [PaymentResultFailed] with code `GOOGLE_PAY`.
/// [GooglePayButton] renders nothing on iOS.
abstract final class GooglePay {
  /// Stores [configuration] for a later [present]. No-op on iOS.
  static Future<void> init(PaymentConfig configuration) async {
    if (!isAndroid) return;
    final json = jsonEncode(toNativeConfiguration(configuration, chvSheetId));
    await XMoneyPlatform.instance.initGooglePay(json);
  }

  /// Opens the Google Pay sheet for [intent].
  ///
  /// [onEvent] receives ready and processing events for this call.
  /// On iOS this returns [PaymentResultFailed] with code `GOOGLE_PAY`.
  static Future<PaymentResult> present(
    PaymentIntent intent, {
    void Function(GooglePayEvent event)? onEvent,
  }) async {
    if (!isAndroid) {
      return PaymentResultFailed(
        PaymentError(
          code: 'GOOGLE_PAY',
          message: stableMessages['GOOGLE_PAY']!,
        ),
      );
    }
    if (_googleSession.begin(assumeProcessing: true) == 'canceled') {
      return const PaymentResultCanceled();
    }
    final generation = _googleSession.generation;
    final requestId = nextBridgeRequestId();
    attachNativeEventHandler(requestId, generation, _googleSession, onEvent);
    try {
      final payload = jsonEncode({...intent.toJson(), 'requestId': requestId});
      final raw = await XMoneyPlatform.instance.presentGooglePay(payload);
      return parsePaymentResult(raw);
    } catch (error) {
      return paymentResultFromUnknown(error);
    } finally {
      _googleSession.finish(generation);
      detachNativeEventHandler(requestId);
    }
  }

  /// Rebinds [intent] on the overlay opened by [present].
  ///
  /// Throws [XMoneyPaymentError] on iOS, and when no overlay is open.
  static Future<void> updateOrder(PaymentIntent intent) async {
    if (!isAndroid) {
      throw XMoneyPaymentError('GOOGLE_PAY', stableMessages['GOOGLE_PAY']!);
    }
    await XMoneyPlatform.instance.updateGooglePayOrder(
      jsonEncode(intent.toJson()),
    );
  }

  /// Closes the overlay before authorization. No-op on iOS.
  static void dismiss() {
    if (isAndroid) {
      XMoneyPlatform.instance.dismissGooglePay();
    }
  }

  /// Whether this device can use Google Pay for [intent].
  ///
  /// Pass [intent] when the native check needs the signed order.
  /// On iOS every flag is false except [WalletState.isInteractionEnabled].
  static Future<WalletState> getState([PaymentIntent? intent]) async {
    if (!isAndroid) {
      return const WalletState(
        isAvailable: false,
        isReady: false,
        isOrderConsumed: false,
        isInteractionEnabled: true,
      );
    }
    final raw = await XMoneyPlatform.instance.getGooglePayState(
      intent == null ? null : jsonEncode(intent.toJson()),
    );
    return parseWalletState(raw);
  }
}
