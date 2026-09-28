import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmoney/xmoney.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'package:xmoney/src/errors.dart';
import 'package:xmoney/src/native_event_router.dart';
import 'package:xmoney/src/native_events.dart';
import 'package:xmoney/src/parse_result.dart';
import 'package:xmoney/src/present_session.dart';

void main() {
  group('parsePaymentResult', () {
    test('parses complete', () {
      const raw =
          '{"status":"complete","transaction":{"id":"tx_1","amount":"10.00"}}';
      final result = parsePaymentResult(raw);
      expect(result, isA<PaymentResultComplete>());
      expect((result as PaymentResultComplete).transaction.id, 'tx_1');
    });

    test('parses canceled', () {
      final result = parsePaymentResult('{"status":"canceled"}');
      expect(result, isA<PaymentResultCanceled>());
    });

    test('sanitizes failed messages', () {
      final result = parsePaymentResult(
        '{"status":"failed","error":{"code":"APPLE_PAY","message":"ignored"}}',
      );
      expect(result, isA<PaymentResultFailed>());
      expect(
        (result as PaymentResultFailed).error.message,
        stableMessages['APPLE_PAY'],
      );
    });
  });

  group('PresentSession', () {
    test('second present while processing is canceled', () {
      final session = PresentSession();
      expect(session.begin(), 'go');
      session.isProcessing = true;
      expect(session.begin(), 'canceled');
    });
  });

  group('sanitizePaymentError', () {
    test('blocks unsafe messages', () {
      final error = sanitizePaymentError(
        'PAYMENT_ERROR',
        '{"orderPayload":"secret"}',
      );
      expect(error.message, 'Payment failed');
    });
  });

  group('XMoneyPaymentError', () {
    test('preserves PlatformException codes', () {
      final error = XMoneyPaymentError.from(
        PlatformException(
          code: 'NOT_INITIALIZED',
          message: 'Call init before present.',
        ),
      );
      expect(error.code, 'NOT_INITIALIZED');
      expect(error.message, stableMessages['NOT_INITIALIZED']);
    });
  });

  group('native events', () {
    test('availability is not mapped as processing', () {
      final event = mapNativeBridgeEvent({'type': 'onAvailability'});
      expect(event, isNull);
    });

    test('embedded availability flags parse', () {
      final flags = mapEmbeddedAvailabilityFlags({
        'type': 'onAvailability',
        'isOrderConsumed': true,
        'isInteractionEnabled': false,
      });
      expect(flags?.isOrderConsumed, isTrue);
      expect(flags?.isInteractionEnabled, isFalse);
    });
  });

  group('native event router', () {
    test('routes events by request id', () {
      resetNativeEventRouterForTest();
      final session = PresentSession();
      session.begin();
      PaymentSheetEvent? received;
      attachNativeEventHandler(
        'req_1',
        session.generation,
        session,
        (event) => received = event,
      );
      ensureNativeEventRouter();
      XMoneyPlatform.instance.onNativeEvent?.call('req_1', {'type': 'onReady'});
      expect(received, isA<PaymentSheetReadyEvent>());
      detachNativeEventHandler('req_1');
      resetNativeEventRouterForTest();
      session.reset();
    });
  });

  group('ApplePay', () {
    test('returns failed on non-iOS targets in VM', () async {
      final result = await ApplePay.present(
        const PaymentIntent(orderPayload: 'p', orderChecksum: 'c'),
      );
      expect(result, isA<PaymentResultFailed>());
      expect((result as PaymentResultFailed).error.code, 'APPLE_PAY');
    });
  });
}
