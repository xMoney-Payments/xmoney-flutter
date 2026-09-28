import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/payment_models.dart';

typedef XMoneyNativeEventHandler = void Function(
  String requestId,
  Map<String, dynamic> event,
);

typedef XMoneyCardHolderVerificationHandler = Future<bool> Function(
  String chvId,
  String requestId,
  CardHolderVerificationResult result,
);

abstract class XMoneyPlatform extends PlatformInterface {
  XMoneyPlatform() : super(token: _token);

  static final Object _token = Object();

  static XMoneyPlatform _instance = _UnimplementedXMoneyPlatform();

  static XMoneyPlatform get instance => _instance;

  static set instance(XMoneyPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  XMoneyNativeEventHandler? onNativeEvent;
  XMoneyCardHolderVerificationHandler? onCardHolderVerification;

  Future<void> initPaymentSheet(String configurationJson);

  Future<String> presentPaymentSheet(String intentJson);

  void dismissPaymentSheet();

  Future<void> initApplePay(String configurationJson);

  Future<String> presentApplePay(String intentJson);

  void dismissApplePay();

  Future<String> getApplePayState();

  Future<void> updateApplePayOrder(String intentJson);

  Future<void> initGooglePay(String configurationJson);

  Future<String> presentGooglePay(String intentJson);

  void dismissGooglePay();

  Future<String> getGooglePayState(String? intentJson);

  Future<void> updateGooglePayOrder(String intentJson);

  void answerCardHolderVerification(String requestId, bool accepted);
}

class _UnimplementedXMoneyPlatform extends XMoneyPlatform {
  Never _throw() => throw UnsupportedError(
        "The xmoney plugin is not linked. Add xmoney to pubspec.yaml and "
        'rebuild the app.',
      );

  @override
  Future<void> initPaymentSheet(String configurationJson) async => _throw();

  @override
  Future<String> presentPaymentSheet(String intentJson) async => _throw();

  @override
  void dismissPaymentSheet() => _throw();

  @override
  Future<void> initApplePay(String configurationJson) async => _throw();

  @override
  Future<String> presentApplePay(String intentJson) async => _throw();

  @override
  void dismissApplePay() => _throw();

  @override
  Future<String> getApplePayState() async => _throw();

  @override
  Future<void> updateApplePayOrder(String intentJson) async => _throw();

  @override
  Future<void> initGooglePay(String configurationJson) async => _throw();

  @override
  Future<String> presentGooglePay(String intentJson) async => _throw();

  @override
  void dismissGooglePay() => _throw();

  @override
  Future<String> getGooglePayState(String? intentJson) async => _throw();

  @override
  Future<void> updateGooglePayOrder(String intentJson) async => _throw();

  @override
  void answerCardHolderVerification(String requestId, bool accepted) =>
      _throw();
}
