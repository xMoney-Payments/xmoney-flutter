import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

/// Shared method-channel platform used by Android and iOS.
class MethodChannelXMoney extends XMoneyPlatform {
  MethodChannelXMoney() {
    // Plugin registration runs before main() creates the binding.
    scheduleMicrotask(() {
      WidgetsFlutterBinding.ensureInitialized();
      _flutterChannel.setMethodCallHandler(_handleFlutterCall);
    });
  }

  static const MethodChannel _hostChannel = MethodChannel('xmoney/host');
  static const MethodChannel _flutterChannel = MethodChannel('xmoney/flutter');
  static const MethodChannel _chvChannel = MethodChannel('xmoney/chv');

  Future<dynamic> _handleFlutterCall(MethodCall call) async {
    switch (call.method) {
      case 'onNativeEvent':
        final args = call.arguments as Map<Object?, Object?>?;
        final requestId = args?['requestId'] as String? ?? '';
        final eventJson = args?['eventJson'] as String? ?? '{}';
        final event = jsonDecode(eventJson) as Map<String, dynamic>;
        onNativeEvent?.call(requestId, event);
      case 'onCardHolderVerification':
        final args = call.arguments as Map<Object?, Object?>?;
        final chvId = args?['chvId'] as String? ?? '';
        final requestId = args?['requestId'] as String? ?? '';
        final resultJson = args?['resultJson'] as String? ?? '{}';
        final resultMap = jsonDecode(resultJson) as Map<String, dynamic>;
        final result = CardHolderVerificationResult(
          status: CardHolderMatchStatus.tryParse(
                resultMap['status'] as String?,
              ) ??
              CardHolderMatchStatus.notVerified,
          firstNameStatus: CardHolderMatchStatus.tryParse(
            resultMap['firstNameStatus'] as String?,
          ),
          middleNameStatus: CardHolderMatchStatus.tryParse(
            resultMap['middleNameStatus'] as String?,
          ),
          lastNameStatus: CardHolderMatchStatus.tryParse(
            resultMap['lastNameStatus'] as String?,
          ),
        );
        final handler = onCardHolderVerification;
        if (handler != null) {
          await handler(chvId, requestId, result);
        } else {
          answerCardHolderVerification(requestId, false);
        }
    }
    return null;
  }

  @override
  Future<void> initPaymentSheet(String configurationJson) =>
      _hostChannel.invokeMethod<void>('initPaymentSheet', configurationJson);

  @override
  Future<String> presentPaymentSheet(String intentJson) async {
    final result = await _hostChannel.invokeMethod<String>(
      'presentPaymentSheet',
      intentJson,
    );
    return result ?? '';
  }

  @override
  void dismissPaymentSheet() =>
      _hostChannel.invokeMethod<void>('dismissPaymentSheet');

  @override
  Future<void> initApplePay(String configurationJson) =>
      _hostChannel.invokeMethod<void>('initApplePay', configurationJson);

  @override
  Future<String> presentApplePay(String intentJson) async {
    final result =
        await _hostChannel.invokeMethod<String>('presentApplePay', intentJson);
    return result ?? '';
  }

  @override
  void dismissApplePay() => _hostChannel.invokeMethod<void>('dismissApplePay');

  @override
  Future<String> getApplePayState() async {
    final result =
        await _hostChannel.invokeMethod<String>('getApplePayState');
    return result ?? '{}';
  }

  @override
  Future<void> updateApplePayOrder(String intentJson) =>
      _hostChannel.invokeMethod<void>('updateApplePayOrder', intentJson);

  @override
  Future<void> initGooglePay(String configurationJson) =>
      _hostChannel.invokeMethod<void>('initGooglePay', configurationJson);

  @override
  Future<String> presentGooglePay(String intentJson) async {
    final result =
        await _hostChannel.invokeMethod<String>('presentGooglePay', intentJson);
    return result ?? '';
  }

  @override
  void dismissGooglePay() =>
      _hostChannel.invokeMethod<void>('dismissGooglePay');

  @override
  Future<String> getGooglePayState(String? intentJson) async {
    final result = await _hostChannel.invokeMethod<String>(
      'getGooglePayState',
      intentJson,
    );
    return result ?? '{}';
  }

  @override
  Future<void> updateGooglePayOrder(String intentJson) =>
      _hostChannel.invokeMethod<void>('updateGooglePayOrder', intentJson);

  @override
  void answerCardHolderVerification(String requestId, bool accepted) {
    _chvChannel.invokeMethod<void>('answerCardHolderVerification', {
      'requestId': requestId,
      'accepted': accepted,
    });
  }
}
