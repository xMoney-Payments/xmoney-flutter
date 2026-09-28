// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

WalletState parseWalletState(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  return WalletState(
    isAvailable: map['isAvailable'] as bool? ?? false,
    isReady: map['isReady'] as bool? ?? false,
    isOrderConsumed: map['isOrderConsumed'] as bool? ?? false,
    isInteractionEnabled: map['isInteractionEnabled'] as bool? ?? true,
  );
}
