// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

const chvSheetId = 'chv_sheet';

final _callbacks =
    <String, bool Function(CardHolderVerificationResult result)>{};

var _listening = false;
int _chvCounter = 0;

String nextCardHolderVerificationId() {
  _chvCounter += 1;
  return 'chv_$_chvCounter';
}

void _ensureChvListener() {
  if (_listening) return;
  _listening = true;
  XMoneyPlatform
      .instance
      .onCardHolderVerification = (chvId, requestId, result) async {
    final callback = _callbacks[chvId];
    var accepted = false;
    if (callback != null) {
      try {
        accepted = callback(result);
      } catch (_) {
        accepted = false;
      }
    }
    XMoneyPlatform.instance.answerCardHolderVerification(requestId, accepted);
    return accepted;
  };
}

void registerCardHolderVerification(
  String chvId,
  bool Function(CardHolderVerificationResult result)? callback,
) {
  _ensureChvListener();
  if (callback != null) {
    _callbacks[chvId] = callback;
  } else {
    _callbacks.remove(chvId);
  }
}

void unregisterCardHolderVerification(String chvId) {
  _callbacks.remove(chvId);
}

Map<String, dynamic> toNativeConfiguration(
  PaymentConfig configuration,
  String chvId,
) {
  final verification = configuration.card?.cardHolderVerification;
  registerCardHolderVerification(chvId, verification?.onCardHolderVerification);
  final cloned =
      jsonDecode(jsonEncode(_configWithoutCallbacks(configuration)))
          as Map<String, dynamic>;
  if (verification != null) {
    final card = (cloned['card'] as Map<String, dynamic>?) ?? {};
    card['cardHolderVerification'] = {
      'name': {
        'firstName': verification.name.firstName,
        'middleName': verification.name.middleName ?? '',
        'lastName': verification.name.lastName,
      },
      'chvId': chvId,
    };
    cloned['card'] = card;
  }
  return cloned;
}

Map<String, dynamic> _configWithoutCallbacks(PaymentConfig configuration) {
  return {
    'publicKey': configuration.publicKey,
    if (configuration.card != null) 'card': configuration.card!.toJson(),
    if (configuration.paymentMethods != null)
      'paymentMethods': configuration.paymentMethods!.toJson(),
    if (configuration.options != null)
      'options': configuration.options!.toJson(),
  };
}

void resetCardHolderVerificationForTest() {
  _callbacks.clear();
  _listening = false;
  _chvCounter = 0;
}
