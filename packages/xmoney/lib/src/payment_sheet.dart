import 'dart:convert';

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'bridge_utils.dart';
import 'card_holder_verification.dart';
import 'errors.dart';
import 'native_event_router.dart';
import 'parse_result.dart';
import 'present_session.dart';

final _sheetSession = PresentSession();

/// Imperative Payment Sheet API.
///
/// The SDK owns the checkout UI, including the Pay button.
abstract final class PaymentSheet {
  /// Stores [configuration] for a later [present].
  static Future<void> init(PaymentConfig configuration) async {
    final json = jsonEncode(toNativeConfiguration(configuration, chvSheetId));
    await XMoneyPlatform.instance.initPaymentSheet(json);
  }

  /// Presents the sheet for [intent].
  ///
  /// [onEvent] receives ready and processing events for this call.
  /// A second [present] while a charge is in flight returns [PaymentResultCanceled].
  static Future<PaymentResult> present(
    PaymentIntent intent, {
    void Function(PaymentSheetEvent event)? onEvent,
  }) async {
    if (_sheetSession.inFlight && _sheetSession.isProcessing) {
      return const PaymentResultCanceled();
    }
    if (_sheetSession.begin() == 'canceled') {
      return const PaymentResultCanceled();
    }
    final generation = _sheetSession.generation;
    final requestId = nextBridgeRequestId();
    attachNativeEventHandler(requestId, generation, _sheetSession, onEvent);
    try {
      final payload = jsonEncode({...intent.toJson(), 'requestId': requestId});
      final raw = await XMoneyPlatform.instance.presentPaymentSheet(payload);
      return parsePaymentResult(raw);
    } catch (error) {
      return paymentResultFromUnknown(error);
    } finally {
      _sheetSession.finish(generation);
      detachNativeEventHandler(requestId);
    }
  }

  /// Closes an idle sheet. Waits when a charge is in flight; idle close still cancels.
  static void dismiss() => XMoneyPlatform.instance.dismissPaymentSheet();
}

/// Clears in-memory sheet session state. For tests.
void resetPaymentSheetStateForTest() => _sheetSession.reset();

/// Marks the current sheet session as processing. For tests.
void markPaymentSheetProcessingForTest() => _sheetSession.isProcessing = true;
