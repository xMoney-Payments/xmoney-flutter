import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmoney/xmoney.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'package:xmoney/src/errors.dart';
import 'package:xmoney/src/native_event_router.dart';
import 'package:xmoney/src/native_events.dart';
import 'package:xmoney/src/parse_result.dart';
import 'package:xmoney/src/present_session.dart';
import 'package:xmoney/src/widgets/payment_element.dart' as payment_element;
import 'package:xmoney/src/widgets/wallet_pay_button.dart' as wallet_pay;

/// The order-update methods both controllers share.
abstract interface class _OrderUpdates {
  bool get isUpdateCurrent;
  Future<void> updateOrder(PaymentIntent intent);
  Future<PaymentIntent> updateOrderWith(
    Future<PaymentIntent> Function() createOrder,
  );
}

class _ElementOrders extends PaymentElementController implements _OrderUpdates {}

class _WalletOrders extends WalletPayButtonController implements _OrderUpdates {}

PaymentElementController _elementController(MethodChannel channel) =>
    _controller(channel, wallet: false) as PaymentElementController;

_OrderUpdates _controller(MethodChannel channel, {required bool wallet}) {
  if (wallet) {
    final controller = _WalletOrders();
    wallet_pay.attachWalletPayButtonControllerForTest(controller, channel);
    return controller;
  }
  final controller = _ElementOrders();
  payment_element.attachPaymentElementControllerForTest(controller, channel);
  return controller;
}

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

    test('maps onUpdateFailed', () {
      final event = mapNativeBridgeEvent({
        'type': 'onUpdateFailed',
        'code': 'LOAD_ERROR',
        'message': 'Failed to load',
      });
      expect(event, isA<PaymentSheetUpdateFailedEvent>());
      final failed = event! as PaymentSheetUpdateFailedEvent;
      expect(failed.code, 'LOAD_ERROR');
      expect(failed.message, 'Failed to load');
      final wallet = walletPayEventFromSheet(failed);
      expect(wallet, isA<WalletPayUpdateFailedEvent>());
      final update = wallet! as WalletPayUpdateFailedEvent;
      expect(update.code, 'LOAD_ERROR');
      expect(update.message, 'Failed to load');
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

  for (final wallet in [false, true]) {
    _orderUpdateTests(wallet: wallet);
  }
  _walletRelayTest();
}

void _orderUpdateTests({required bool wallet}) {
  final surface = wallet ? 'wallet button' : 'payment element';
  group('updateOrder on $surface', () {
    const channel = MethodChannel('xmoney/order_update/test');
    late List<String> calls;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('updateOrderWith resolves after createOrder', () async {
      final controller = _controller(channel, wallet: wallet);
      const intent = PaymentIntent(
        orderPayload: 'payload',
        orderChecksum: 'sum',
      );
      final bound = await controller.updateOrderWith(() async => intent);
      expect(bound.orderChecksum, 'sum');
      expect(calls, ['beginUpdateOrder', 'resolveOrder']);
    });

    test('updateOrderWith rejects when createOrder throws', () async {
      final controller = _controller(channel, wallet: wallet);
      await expectLater(
        controller.updateOrderWith(() async => throw StateError('nope')),
        throwsA(isA<StateError>()),
      );
      expect(calls, ['beginUpdateOrder', 'rejectOrder']);
    });

    testWidgets('didUpdateWidget skips an intent already sent', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final controller = _elementController(channel);
        const config = PaymentConfig(publicKey: 'pk_test_example');
        const first = PaymentIntent(orderPayload: 'a', orderChecksum: '1');
        const second = PaymentIntent(orderPayload: 'b', orderChecksum: '2');
        const third = PaymentIntent(orderPayload: 'c', orderChecksum: '3');

        await tester.pumpWidget(
          MaterialApp(
            home: PaymentElement(
              configuration: config,
              intent: first,
              controller: controller,
            ),
          ),
        );
        calls.clear();
        await controller.updateOrder(second);
        expect(calls, ['updateOrder']);

        calls.clear();
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentElement(
              configuration: config,
              intent: second,
              controller: controller,
            ),
          ),
        );
        await tester.pump();
        expect(calls, isEmpty);

        await tester.pumpWidget(
          MaterialApp(
            home: PaymentElement(
              configuration: config,
              intent: third,
              controller: controller,
            ),
          ),
        );
        await tester.pump();
        expect(calls, ['updateOrder']);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('begin failure during createOrder is one caught error', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              if (call.method == 'beginUpdateOrder') {
                throw PlatformException(
                  code: 'SUPERSEDED_UPDATE_ORDER',
                  message: 'Superseded by a newer updateOrder call',
                );
              }
              return null;
            });
        final controller = _controller(channel, wallet: wallet);
        var created = false;
        await expectLater(
          controller.updateOrderWith(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (!controller.isUpdateCurrent) throw StateError('superseded');
            created = true;
            return const PaymentIntent(orderPayload: 'p', orderChecksum: 'c');
          }),
          throwsA(
            isA<XMoneyPaymentError>().having(
              (error) => error.code,
              'code',
              'SUPERSEDED_UPDATE_ORDER',
            ),
          ),
        );
        expect(created, isFalse);
        expect(calls, isNot(contains('resolveOrder')));
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));
      expect(uncaught, isEmpty);
    });

    test(
      'a charge in progress is PAYMENT_IN_PROGRESS, not superseded',
      () async {
        final uncaught = <Object>[];
        await runZonedGuarded(() async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                calls.add(call.method);
                if (call.method == 'beginUpdateOrder') {
                  throw PlatformException(
                    code: 'PAYMENT_IN_PROGRESS',
                    message: 'Payment in progress',
                  );
                }
                return null;
              });
          final controller = _controller(channel, wallet: wallet);
          var created = false;
          var sawStale = false;
          await expectLater(
            controller.updateOrderWith(() async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              sawStale = !controller.isUpdateCurrent;
              if (sawStale) throw StateError('superseded');
              created = true;
              return const PaymentIntent(orderPayload: 'p', orderChecksum: 'c');
            }),
            throwsA(
              isA<XMoneyPaymentError>().having(
                (error) => error.code,
                'code',
                'PAYMENT_IN_PROGRESS',
              ),
            ),
          );
          expect(sawStale, isTrue);
          expect(created, isFalse);
          expect(calls, isNot(contains('resolveOrder')));
          await Future<void>.delayed(Duration.zero);
        }, (error, _) => uncaught.add(error));
        expect(uncaught, isEmpty);
      },
    );

    test('a newer updateOrderWith supersedes before the server call', () async {
      final controller = _controller(channel, wallet: wallet);
      var created = false;
      var sawStale = false;
      final first = controller.updateOrderWith(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        sawStale = !controller.isUpdateCurrent;
        if (!controller.isUpdateCurrent) throw StateError('superseded');
        created = true;
        return const PaymentIntent(orderPayload: 'a', orderChecksum: '1');
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = controller.updateOrderWith(
        () async => const PaymentIntent(orderPayload: 'b', orderChecksum: '2'),
      );

      final bound = await second;
      await expectLater(
        first,
        throwsA(
          isA<XMoneyPaymentError>().having(
            (error) => error.code,
            'code',
            'SUPERSEDED_UPDATE_ORDER',
          ),
        ),
      );
      expect(bound.orderChecksum, '2');
      expect(created, isFalse);
      expect(sawStale, isTrue);
      expect(calls.where((call) => call == 'resolveOrder'), ['resolveOrder']);
    });

    testWidgets('didUpdateWidget skips an intent still in flight', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'updateOrder') await gate.future;
            return null;
          });
      try {
        final controller = _elementController(channel);
        const config = PaymentConfig(publicKey: 'pk_test_example');
        const first = PaymentIntent(orderPayload: 'a', orderChecksum: '1');
        const second = PaymentIntent(orderPayload: 'b', orderChecksum: '2');

        await tester.pumpWidget(
          MaterialApp(
            home: PaymentElement(
              configuration: config,
              intent: first,
              controller: controller,
            ),
          ),
        );
        calls.clear();
        final pending = controller.updateOrder(second);
        await tester.pump();
        expect(calls, ['updateOrder']);

        calls.clear();
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentElement(
              configuration: config,
              intent: second,
              controller: controller,
            ),
          ),
        );
        await tester.pump();
        expect(calls, isEmpty);

        gate.complete();
        await pending;
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

void _walletRelayTest() {
  test('a wallet button relays a new intent without a second bind', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('xmoney/apple_pay_button/test');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    try {
      final controller =
          _controller(channel, wallet: true) as WalletPayButtonController;
      const first = PaymentIntent(orderPayload: 'a', orderChecksum: '1');
      const second = PaymentIntent(orderPayload: 'b', orderChecksum: '2');

      await controller.updateOrder(first);
      calls.clear();

      // The widget calls this from didUpdateWidget. The platform view is never
      // created in the test binding, so the call is driven here.
      controller.relayWidgetIntentForTest(second);
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['updateOrder']);
      expect(controller.sentChecksumForTest, '2');

      calls.clear();
      controller.relayWidgetIntentForTest(second);
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
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
