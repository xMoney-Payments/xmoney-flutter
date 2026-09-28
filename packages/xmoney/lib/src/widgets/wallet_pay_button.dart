import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import '../card_holder_verification.dart';
import '../errors.dart';
import '../native_events.dart';
import '../parse_result.dart';
import '../platform_target.dart';

const _appleViewType = 'xmoney/apple_pay_button';
const _googleViewType = 'xmoney/google_pay_button';

/// Apple Pay button (iOS only). Renders nothing on Android.
class ApplePayButton extends StatefulWidget {
  /// Mounts an Apple Pay button for [intent] using [configuration].
  const ApplePayButton({
    required this.configuration,
    required this.intent,
    this.controller,
    this.appearance,
    this.isEnabled = true,
    this.onEvent,
    this.onResult,
    super.key,
  });

  /// Publishable key and Apple Pay options.
  final PaymentConfig configuration;

  /// Signed order from your server.
  final PaymentIntent intent;

  /// Optional handle for [WalletPayButtonController.updateOrder].
  final WalletPayButtonController? controller;

  /// Button color, radius, and label. Omit for the native default.
  final WalletAppearance? appearance;

  /// When false, the button does not start a payment.
  final bool isEnabled;

  /// Ready, processing, and availability while the button is mounted.
  final void Function(WalletPayEvent event)? onEvent;

  /// Terminal payment result. Session tokens are not included.
  final void Function(PaymentResult result)? onResult;

  @override
  State<ApplePayButton> createState() => _ApplePayButtonState();
}

class _ApplePayButtonState extends State<ApplePayButton> {
  MethodChannel? _channel;
  late final String _chvId;

  @override
  void initState() {
    super.initState();
    _chvId = nextCardHolderVerificationId();
  }

  @override
  void didUpdateWidget(covariant ApplePayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel == null) return;
    if (oldWidget.intent.orderChecksum != widget.intent.orderChecksum ||
        oldWidget.intent.orderPayload != widget.intent.orderPayload) {
      widget.controller?.updateOrder(widget.intent);
    }
    if (oldWidget.appearance != widget.appearance ||
        oldWidget.isEnabled != widget.isEnabled ||
        oldWidget.configuration.publicKey != widget.configuration.publicKey) {
      _pushPropsToNative();
    }
  }

  void _pushPropsToNative() {
    _channel?.invokeMethod<void>('updateProps', {
      'configuration': toNativeConfiguration(widget.configuration, _chvId),
      'orderPayload': widget.intent.orderPayload,
      'orderChecksum': widget.intent.orderChecksum,
      'appearance': widget.appearance?.toJson(),
      'isEnabled': widget.isEnabled,
    });
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_appleViewType/$viewId');
    _channel = channel;
    widget.controller?._attach(channel, () => mounted);
    channel.setMethodCallHandler(_onPlatformCall);
  }

  @override
  void dispose() {
    unregisterCardHolderVerification(_chvId);
    _channel?.setMethodCallHandler(null);
    widget.controller?._detach();
    super.dispose();
  }

  Future<void> _onPlatformCall(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>?;
    switch (call.method) {
      case 'onEvent':
        final eventJson = args?['event'] as String? ?? '{}';
        final event = jsonDecode(eventJson) as Map<String, dynamic>;
        final ready = mapNativeBridgeEvent(event);
        if (ready != null) {
          final mapped = walletPayEventFromSheet(ready);
          if (mapped != null) widget.onEvent?.call(mapped);
        }
        final availability = mapWalletAvailability(event);
        if (availability != null) widget.onEvent?.call(availability);
      case 'onResult':
        final resultJson = args?['result'] as String? ?? '{}';
        widget.onResult?.call(parsePaymentResult(resultJson));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isIOS) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: UiKitView(
        viewType: _appleViewType,
        creationParams: {
          'configuration': toNativeConfiguration(widget.configuration, _chvId),
          'orderPayload': widget.intent.orderPayload,
          'orderChecksum': widget.intent.orderChecksum,
          'appearance': widget.appearance?.toJson(),
          'isEnabled': widget.isEnabled,
        },
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const {
          Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
        },
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}

/// Google Pay button (Android only). Renders nothing on iOS.
class GooglePayButton extends StatefulWidget {
  /// Mounts a Google Pay button for [intent] using [configuration].
  const GooglePayButton({
    required this.configuration,
    required this.intent,
    this.controller,
    this.appearance,
    this.isEnabled = true,
    this.onEvent,
    this.onResult,
    super.key,
  });

  /// Publishable key and Google Pay options.
  final PaymentConfig configuration;

  /// Signed order from your server.
  final PaymentIntent intent;

  /// Optional handle for [WalletPayButtonController.updateOrder].
  final WalletPayButtonController? controller;

  /// Button color, radius, and label. Omit for the native default.
  final WalletAppearance? appearance;

  /// When false, the button does not start a payment.
  final bool isEnabled;

  /// Ready, processing, and availability while the button is mounted.
  final void Function(WalletPayEvent event)? onEvent;

  /// Terminal payment result. Session tokens are not included.
  final void Function(PaymentResult result)? onResult;

  @override
  State<GooglePayButton> createState() => _GooglePayButtonState();
}

class _GooglePayButtonState extends State<GooglePayButton> {
  MethodChannel? _channel;
  late final String _chvId;

  @override
  void initState() {
    super.initState();
    _chvId = nextCardHolderVerificationId();
  }

  @override
  void didUpdateWidget(covariant GooglePayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel == null) return;
    if (oldWidget.intent.orderChecksum != widget.intent.orderChecksum ||
        oldWidget.intent.orderPayload != widget.intent.orderPayload) {
      widget.controller?.updateOrder(widget.intent);
    }
    if (oldWidget.appearance != widget.appearance ||
        oldWidget.isEnabled != widget.isEnabled ||
        oldWidget.configuration.publicKey != widget.configuration.publicKey) {
      _pushPropsToNative();
    }
  }

  void _pushPropsToNative() {
    _channel?.invokeMethod<void>('updateProps', {
      'configuration': toNativeConfiguration(widget.configuration, _chvId),
      'orderPayload': widget.intent.orderPayload,
      'orderChecksum': widget.intent.orderChecksum,
      'appearance': widget.appearance?.toJson(),
      'isEnabled': widget.isEnabled,
    });
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_googleViewType/$viewId');
    _channel = channel;
    widget.controller?._attach(channel, () => mounted);
    channel.setMethodCallHandler(_onPlatformCall);
  }

  @override
  void dispose() {
    unregisterCardHolderVerification(_chvId);
    _channel?.setMethodCallHandler(null);
    widget.controller?._detach();
    super.dispose();
  }

  Future<void> _onPlatformCall(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>?;
    switch (call.method) {
      case 'onEvent':
        final eventJson = args?['event'] as String? ?? '{}';
        final event = jsonDecode(eventJson) as Map<String, dynamic>;
        final ready = mapNativeBridgeEvent(event);
        if (ready != null) {
          final mapped = walletPayEventFromSheet(ready);
          if (mapped != null) widget.onEvent?.call(mapped);
        }
        final availability = mapWalletAvailability(event);
        if (availability != null) widget.onEvent?.call(availability);
      case 'onResult':
        final resultJson = args?['result'] as String? ?? '{}';
        widget.onResult?.call(parsePaymentResult(resultJson));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAndroid) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: AndroidView(
        viewType: _googleViewType,
        layoutDirection: Directionality.of(context),
        creationParams: {
          'configuration': toNativeConfiguration(widget.configuration, _chvId),
          'orderPayload': widget.intent.orderPayload,
          'orderChecksum': widget.intent.orderChecksum,
          'appearance': widget.appearance?.toJson(),
          'isEnabled': widget.isEnabled,
        },
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const {
          Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
        },
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}

/// Updates the order or appearance of a mounted [ApplePayButton] or [GooglePayButton].
class WalletPayButtonController {
  MethodChannel? _channel;
  bool Function()? _mounted;

  void _attach(MethodChannel channel, bool Function() mounted) {
    _channel = channel;
    _mounted = mounted;
  }

  void _detach() {
    _channel = null;
    _mounted = null;
  }

  /// Rebinds [intent] on the mounted wallet button.
  Future<void> updateOrder(PaymentIntent intent) async {
    if (_channel == null || _mounted?.call() != true) {
      throw XMoneyPaymentError(
        'NOT_INITIALIZED',
        stableMessages['NOT_INITIALIZED']!,
      );
    }
    try {
      await _channel!.invokeMethod<void>('updateOrder', intent.toJson());
    } on PlatformException catch (error) {
      throw XMoneyPaymentError.from(error);
    }
  }

  /// Restyles the mounted wallet button.
  Future<void> updateAppearance(WalletAppearance appearance) async {
    if (_channel == null || _mounted?.call() != true) {
      throw XMoneyPaymentError(
        'NOT_INITIALIZED',
        stableMessages['NOT_INITIALIZED']!,
      );
    }
    try {
      await _channel!.invokeMethod<void>(
        'updateAppearance',
        appearance.toJson(),
      );
    } on PlatformException catch (error) {
      throw XMoneyPaymentError.from(error);
    }
  }
}
