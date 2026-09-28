// ignore_for_file: public_member_api_docs

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

PaymentSheetEvent? mapNativeBridgeEvent(Map<String, dynamic> event) {
  final type = event['type'] as String?;
  if (type == 'onReady' || type == 'ready') {
    return const PaymentSheetReadyEvent();
  }
  if (type == 'onProcessing' || type == 'processing') {
    return PaymentSheetProcessingEvent(event['isProcessing'] as bool? ?? true);
  }
  return null;
}

WalletPayEvent? walletPayEventFromSheet(PaymentSheetEvent event) {
  return switch (event) {
    PaymentSheetReadyEvent() => const WalletPayReadyEvent(),
    PaymentSheetProcessingEvent(:final isProcessing) =>
      WalletPayProcessingEvent(isProcessing),
  };
}

WalletPayAvailabilityEvent? mapWalletAvailability(Map<String, dynamic> event) {
  if (event['type'] != 'onAvailability' && event['type'] != 'availability') {
    return null;
  }
  return WalletPayAvailabilityEvent(
    isAvailable: event['isAvailable'] as bool? ?? false,
    isReady: event['isReady'] as bool? ?? false,
    isOrderConsumed: event['isOrderConsumed'] as bool? ?? false,
    isInteractionEnabled: event['isInteractionEnabled'] as bool? ?? true,
  );
}

({bool isOrderConsumed, bool isInteractionEnabled})?
mapEmbeddedAvailabilityFlags(Map<String, dynamic> event) {
  if (event['type'] != 'onAvailability' && event['type'] != 'availability') {
    return null;
  }
  return (
    isOrderConsumed: event['isOrderConsumed'] as bool? ?? false,
    isInteractionEnabled: event['isInteractionEnabled'] as bool? ?? true,
  );
}
