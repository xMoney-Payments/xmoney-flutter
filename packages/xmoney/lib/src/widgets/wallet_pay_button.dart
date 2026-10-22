import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import '../card_holder_verification.dart';
import '../native_events.dart';
import '../order_updater.dart';
import '../parse_result.dart';
import '../platform_target.dart';

const _appleViewType = 'xmoney/apple_pay_button';
const _googleViewType = 'xmoney/google_pay_button';

bool _configChanged(PaymentConfig? previous, PaymentConfig next) {
  if (previous == null) return false;
  return jsonEncode(previous.toJson()) != jsonEncode(next.toJson());
}

bool _buttonPropsChanged({
  required WalletAppearance? previousAppearance,
  required bool? previousEnabled,
  required WalletAppearance? appearance,
  required bool isEnabled,
}) {
  if (previousEnabled == null) return false;
  return jsonEncode(
            previousAppearance?.toJson() ?? const <String, dynamic>{},
          ) !=
          jsonEncode(appearance?.toJson() ?? const <String, dynamic>{}) ||
      previousEnabled != isEnabled;
}

bool _intentChanged(PaymentIntent? previous, PaymentIntent next) {
  if (previous == null) return false;
  return previous.orderChecksum != next.orderChecksum ||
      previous.orderPayload != next.orderPayload;
}

/// A configuration change rebuilds the native wallet, which rebinds [intent].
/// Appearance and enabled do not, so an intent change is sent on its own.
void _syncWallet({
  required WalletPayButtonController controller,
  required bool configurationChanged,
  required bool buttonPropsChanged,
  required bool intentChanged,
  required PaymentIntent intent,
  required void Function() pushProps,
}) {
  if (configurationChanged) {
    controller._rebuildFromWidget();
    pushProps();
    return;
  }
  if (buttonPropsChanged) pushProps();
  if (intentChanged) controller._relayWidgetIntent(intent);
}

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

  /// Values passed in the platform view's creation params. Later builds keep
  /// them so a view created before [didUpdateWidget] still matches this snapshot.
  PaymentIntent? _createdIntent;
  PaymentConfig? _createdConfiguration;
  WalletAppearance? _createdAppearance;
  bool? _createdEnabled;
  late final String _chvId;
  late final WalletPayButtonController _controller;

  @override
  void initState() {
    super.initState();
    _chvId = nextCardHolderVerificationId();
    _controller = widget.controller ?? WalletPayButtonController();
  }

  PaymentIntent _snapshotCreation() {
    if (_createdIntent == null) {
      _createdIntent = widget.intent;
      _createdConfiguration = widget.configuration;
      _createdAppearance = widget.appearance;
      _createdEnabled = widget.isEnabled;
    }
    return _createdIntent!;
  }

  void _catchUpAfterAttach() {
    _syncWallet(
      controller: _controller,
      configurationChanged: _configChanged(
        _createdConfiguration,
        widget.configuration,
      ),
      buttonPropsChanged: _buttonPropsChanged(
        previousAppearance: _createdAppearance,
        previousEnabled: _createdEnabled,
        appearance: widget.appearance,
        isEnabled: widget.isEnabled,
      ),
      intentChanged: _intentChanged(_createdIntent, widget.intent),
      intent: widget.intent,
      pushProps: _pushPropsToNative,
    );
  }

  @override
  void didUpdateWidget(covariant ApplePayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel == null) return;
    _syncWallet(
      controller: _controller,
      configurationChanged: _configChanged(
        oldWidget.configuration,
        widget.configuration,
      ),
      buttonPropsChanged: _buttonPropsChanged(
        previousAppearance: oldWidget.appearance,
        previousEnabled: oldWidget.isEnabled,
        appearance: widget.appearance,
        isEnabled: widget.isEnabled,
      ),
      intentChanged: _intentChanged(oldWidget.intent, widget.intent),
      intent: widget.intent,
      pushProps: _pushPropsToNative,
    );
  }

  void _pushPropsToNative() {
    final channel = _channel;
    if (channel == null) return;
    unawaited(
      channel
          .invokeMethod<void>('updateProps', {
            'configuration': toNativeConfiguration(
              widget.configuration,
              _chvId,
            ),
            'orderPayload': widget.intent.orderPayload,
            'orderChecksum': widget.intent.orderChecksum,
            'appearance': widget.appearance?.toJson(),
            'isEnabled': widget.isEnabled,
          })
          .then((_) {}, onError: (Object _) {}),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_appleViewType/$viewId');
    _channel = channel;
    _controller._attach(channel, () => mounted);
    channel.setMethodCallHandler(_onPlatformCall);
    _catchUpAfterAttach();
  }

  @override
  void dispose() {
    unregisterCardHolderVerification(_chvId);
    _channel?.setMethodCallHandler(null);
    _controller._detach();
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
          if (mapped != null) {
            widget.onEvent?.call(mapped);
            if (mapped is WalletPayProcessingEvent && !mapped.isProcessing) {
              _controller._retryDeferredIntent();
            }
          }
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
    final intent = _snapshotCreation();
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: UiKitView(
        viewType: _appleViewType,
        creationParams: {
          'configuration': toNativeConfiguration(
            _createdConfiguration!,
            _chvId,
          ),
          'orderPayload': intent.orderPayload,
          'orderChecksum': intent.orderChecksum,
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

  /// Values passed in the platform view's creation params. Later builds keep
  /// them so a view created before [didUpdateWidget] still matches this snapshot.
  PaymentIntent? _createdIntent;
  PaymentConfig? _createdConfiguration;
  WalletAppearance? _createdAppearance;
  bool? _createdEnabled;
  late final String _chvId;
  late final WalletPayButtonController _controller;

  @override
  void initState() {
    super.initState();
    _chvId = nextCardHolderVerificationId();
    _controller = widget.controller ?? WalletPayButtonController();
  }

  PaymentIntent _snapshotCreation() {
    if (_createdIntent == null) {
      _createdIntent = widget.intent;
      _createdConfiguration = widget.configuration;
      _createdAppearance = widget.appearance;
      _createdEnabled = widget.isEnabled;
    }
    return _createdIntent!;
  }

  void _catchUpAfterAttach() {
    _syncWallet(
      controller: _controller,
      configurationChanged: _configChanged(
        _createdConfiguration,
        widget.configuration,
      ),
      buttonPropsChanged: _buttonPropsChanged(
        previousAppearance: _createdAppearance,
        previousEnabled: _createdEnabled,
        appearance: widget.appearance,
        isEnabled: widget.isEnabled,
      ),
      intentChanged: _intentChanged(_createdIntent, widget.intent),
      intent: widget.intent,
      pushProps: _pushPropsToNative,
    );
  }

  @override
  void didUpdateWidget(covariant GooglePayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel == null) return;
    _syncWallet(
      controller: _controller,
      configurationChanged: _configChanged(
        oldWidget.configuration,
        widget.configuration,
      ),
      buttonPropsChanged: _buttonPropsChanged(
        previousAppearance: oldWidget.appearance,
        previousEnabled: oldWidget.isEnabled,
        appearance: widget.appearance,
        isEnabled: widget.isEnabled,
      ),
      intentChanged: _intentChanged(oldWidget.intent, widget.intent),
      intent: widget.intent,
      pushProps: _pushPropsToNative,
    );
  }

  void _pushPropsToNative() {
    final channel = _channel;
    if (channel == null) return;
    unawaited(
      channel
          .invokeMethod<void>('updateProps', {
            'configuration': toNativeConfiguration(
              widget.configuration,
              _chvId,
            ),
            'orderPayload': widget.intent.orderPayload,
            'orderChecksum': widget.intent.orderChecksum,
            'appearance': widget.appearance?.toJson(),
            'isEnabled': widget.isEnabled,
          })
          .then((_) {}, onError: (Object _) {}),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_googleViewType/$viewId');
    _channel = channel;
    _controller._attach(channel, () => mounted);
    channel.setMethodCallHandler(_onPlatformCall);
    _catchUpAfterAttach();
  }

  @override
  void dispose() {
    unregisterCardHolderVerification(_chvId);
    _channel?.setMethodCallHandler(null);
    _controller._detach();
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
          if (mapped != null) {
            widget.onEvent?.call(mapped);
            if (mapped is WalletPayProcessingEvent && !mapped.isProcessing) {
              _controller._retryDeferredIntent();
            }
          }
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
    final intent = _snapshotCreation();
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: AndroidView(
        viewType: _googleViewType,
        layoutDirection: Directionality.of(context),
        creationParams: {
          'configuration': toNativeConfiguration(
            _createdConfiguration!,
            _chvId,
          ),
          'orderPayload': intent.orderPayload,
          'orderChecksum': intent.orderChecksum,
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

/// Attaches a channel without a platform view. Widget tests use this.
@visibleForTesting
void attachWalletPayButtonControllerForTest(
  WalletPayButtonController controller,
  MethodChannel channel,
) {
  controller._attach(channel, () => true);
}

/// Lets widget tests drive [ApplePayButton.didUpdateWidget] and
/// [GooglePayButton.didUpdateWidget]. The platform view is never created
/// under the test binding, so a prop change would otherwise be skipped.
@visibleForTesting
void markWalletPlatformViewCreatedForTest(Element element) {
  final state = (element as StatefulElement).state;
  switch (state) {
    case _ApplePayButtonState():
      state._channel ??= const MethodChannel('xmoney/apple_pay_button/test');
      state._controller._attach(state._channel!, () => true);
    case _GooglePayButtonState():
      state._channel ??= const MethodChannel('xmoney/google_pay_button/test');
      state._controller._attach(state._channel!, () => true);
    default:
      throw ArgumentError.value(element, 'element', 'Expected a wallet button');
  }
}

/// Test-only access to [WalletPayButtonController] internals.
///
/// Not exported from `package:xmoney/xmoney.dart`, so it is not public API.
extension WalletPayButtonControllerTestHooks on WalletPayButtonController {
  /// The checksum of the last order handed to the native SDK.
  @visibleForTesting
  String? get sentChecksumForTest => _orders.sentChecksumForTest;

  /// What [ApplePayButton] and [GooglePayButton] call from `didUpdateWidget`.
  @visibleForTesting
  void relayWidgetIntentForTest(PaymentIntent intent) =>
      _relayWidgetIntent(intent);

  /// What the buttons call when a charge ends.
  @visibleForTesting
  void retryDeferredForTest() => _retryDeferredIntent();

  /// Drops the controller the way the widget does on dispose.
  @visibleForTesting
  void detachForTest() => _detach();
}

/// Updates the order or appearance of a mounted [ApplePayButton] or [GooglePayButton].
class WalletPayButtonController {
  final OrderUpdater _orders = OrderUpdater();

  void _attach(MethodChannel channel, bool Function() mounted) {
    _orders.attach(channel, mounted);
  }

  void _detach() => _orders.detach();

  /// Skips the rebind the widget would send for an intent already handed to
  /// the native SDK, including one still in flight.
  void _relayWidgetIntent(PaymentIntent intent) =>
      _orders.relayWidgetIntent(intent);

  /// Ends in-flight updates before a configuration change rebuilds the wallet.
  void _rebuildFromWidget() => _orders.forgetAndSupersede();

  void _retryDeferredIntent() => _orders.retryDeferred();

  /// Rebinds [intent] on the mounted wallet button.
  ///
  /// The button stays enabled while you create [intent]. Use [updateOrderWith]
  /// when the shopper changes the cart, so the button locks before your server
  /// responds.
  Future<void> updateOrder(PaymentIntent intent) => _orders.updateOrder(intent);

  /// Whether the [updateOrderWith] callback on the stack is still current.
  ///
  /// False once a newer update starts or the native lock for this call ends.
  /// Check it after a debounce so a superseded callback does not create an
  /// order. True outside an [updateOrderWith] callback.
  bool get isUpdateCurrent => _orders.isUpdateCurrent;

  /// Locks the wallet button, creates the next order, binds it, and returns it.
  ///
  /// The button is a no-op from this call until the new order is bound,
  /// including while [createOrder] talks to your server, so a fast tap cannot
  /// charge the previous order. If [createOrder] throws, the previous order
  /// stays payable and that error is rethrown. A newer update supersedes this
  /// one (`SUPERSEDED_UPDATE_ORDER`). After a debounce, check
  /// [isUpdateCurrent] and stop before calling your server when it is false.
  Future<PaymentIntent> updateOrderWith(
    Future<PaymentIntent> Function() createOrder,
  ) => _orders.updateOrderWith(createOrder);

  /// Restyles the mounted wallet button.
  Future<void> updateAppearance(WalletAppearance appearance) async =>
      _orders.invoke('updateAppearance', appearance.toJson());
}
