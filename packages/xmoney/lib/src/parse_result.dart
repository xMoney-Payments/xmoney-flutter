// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'errors.dart';

TransactionCustomer? _pickCustomer(Object? value) {
  if (value is! Map) return null;
  return TransactionCustomer(
    id: value['id'] as String?,
    siteId: value['siteId'] as String?,
    identifier: value['identifier'] as String?,
    firstName: value['firstName'] as String?,
    lastName: value['lastName'] as String?,
    country: value['country'] as String?,
    state: value['state'] as String?,
    city: value['city'] as String?,
    zipCode: value['zipCode'] as String?,
    address: value['address'] as String?,
    phone: value['phone'] as String?,
    email: value['email'] as String?,
    isWhitelisted: value['isWhitelisted'] as bool?,
    isWhitelistedUntil: value['isWhitelistedUntil'] as String?,
    creationDate: value['creationDate'] as String?,
    creationTimestamp: (value['creationTimestamp'] as num?)?.toInt(),
  );
}

Transaction? _pickTransaction(Object? value) {
  if (value is! Map) return null;
  return Transaction(
    id: value['id'] as String?,
    status: value['status'] as String?,
    amount: value['amount'] as String?,
    currencyKey: value['currencyKey'] as String?,
    amountInEuro: value['amountInEuro'] as String?,
    externalOrderId: value['externalOrderId'] as String?,
    description: value['description'] as String?,
    customerData: _pickCustomer(value['customerData']),
  );
}

PaymentResult parsePaymentResult(Object? value) {
  Object? payload = value;
  if (value is String) {
    try {
      payload = jsonDecode(value);
    } catch (_) {
      return const PaymentResultFailed(
        PaymentError(code: 'UNKNOWN', message: 'Invalid payment result'),
      );
    }
  }
  if (payload is! Map) {
    return const PaymentResultFailed(
      PaymentError(code: 'UNKNOWN', message: 'Invalid payment result'),
    );
  }
  final statusRaw = payload['status'] as String?;
  if (statusRaw == 'canceled') {
    return const PaymentResultCanceled();
  }
  if (statusRaw == 'complete') {
    return PaymentResultComplete(
      _pickTransaction(payload['transaction']) ?? const Transaction(),
    );
  }
  if (statusRaw == 'failed') {
    final errorMap = payload['error'];
    if (errorMap is Map) {
      return PaymentResultFailed(
        sanitizePaymentError(
          errorMap['code'] as String?,
          errorMap['message'] as String?,
        ),
      );
    }
  }
  return const PaymentResultFailed(
    PaymentError(code: 'UNKNOWN', message: 'Payment failed'),
  );
}
