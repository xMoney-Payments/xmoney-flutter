import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import '../card_holder_verification.dart';
import '../native_events.dart';
import '../order_updater.dart';
import '../parse_result.dart';
import '../platform_target.dart';

/// Events emitted by [PaymentElement].
sealed class PaymentElementEvent {
  /// Base type for embedded form events.
  const PaymentElementEvent();
}

/// The embedded form has drawn and can be shown.
///
/// Fires once per mount, after the first draw, and not on a failure screen.
/// A failed first load does not emit this event.
final class PaymentElementReadyEvent extends PaymentElementEvent {
  /// The form has drawn.
  const PaymentElementReadyEvent();
}

/// An in-flight charge. [PaymentElementController.updateOrder] does not emit this.
final class PaymentElementProcessingEvent extends PaymentElementEvent {
  /// An in-flight charge. [isProcessing] is false when it settles.
  const PaymentElementProcessingEvent(this.isProcessing);

  /// Whether a charge is in flight.
  final bool isProcessing;
}

/// Binding a new order failed after an order was already bound.
///
/// Pay stays locked on the previous order until
/// [PaymentElementController.updateOrder] succeeds.
final class PaymentElementUpdateFailedEvent extends PaymentElementEvent {
  /// A failed rebind. [code] and [message] are SDK-authored.
  const PaymentElementUpdateFailedEvent({
    required this.code,
    required this.message,
  });

  /// Stable error code, such as `LOAD_ERROR`.
  final String code;

  /// SDK-authored message. Safe to display.
  final String message;
}

/// Pay and wallet availability for the mounted element.
final class PaymentElementAvailabilityEvent extends PaymentElementEvent {
  /// Availability after bind, an order update, or a result.
  const PaymentElementAvailabilityEvent({
    required this.isOrderConsumed,
    required this.isInteractionEnabled,
  });

  /// True after a terminal result consumes the order checksum.
  final bool isOrderConsumed;

  /// False during [PaymentElementController.updateOrder], while a charge is in
  /// flight, and after a failed rebind until a later update succeeds.
  final bool isInteractionEnabled;
}

const _viewType = 'xmoney/payment_element';

/// Embedded Payment Element (card, saved cards, Apple Pay on iOS, and Google Pay on Android).
class PaymentElement extends StatefulWidget {
  /// Mounts the native form for [intent] using [configuration].
  const PaymentElement({
    required this.configuration,
    required this.intent,
    this.controller,
    this.onEvent,
    this.onResult,
    super.key,
  });

  /// Publishable key, wallets, and card options.
  final PaymentConfig configuration;

  /// Signed order from your server.
  final PaymentIntent intent;

  /// Optional handle for [PaymentElementController.confirm] and later updates.
  final PaymentElementController? controller;

  /// Ready, processing, update failure, and availability while the form is mounted.
  final void Function(PaymentElementEvent event)? onEvent;

  /// Terminal payment result. Session tokens are not included.
  final void Function(PaymentResult result)? onResult;

  @override
  State<PaymentElement> createState() => _PaymentElementState();
}

class _PaymentElementState extends State<PaymentElement>
    with WidgetsBindingObserver {
  PaymentElementController? _controller;
  MethodChannel? _channel;

  /// Intent and configuration passed in the platform view's creation params.
  /// Later builds keep them so a view created before [didUpdateWidget] still
  /// matches this snapshot.
  PaymentIntent? _createdIntent;
  PaymentConfig? _createdConfiguration;
  AndroidViewController? _androidViewController;
  TextDirection? _layoutDirection;
  late final String _chvId;
  final _platformKey = GlobalKey();
  double _height = 120;

  /// Space added under the form so the host scroll view can move the focused
  /// field clear of the keyboard. Stays 0 when that scroll view already ends
  /// above the keyboard.
  double _keyboardLift = 0;

  /// Bottom of the focused field in the platform view's coordinates.
  double? _fieldLocalBottom;

  /// Screen Y where the keyboard starts. Null while it is closed.
  double? _activeKeyboardTop;
  double? _appliedFieldLocal;

  /// Native keyboard events take over once they arrive. Metrics are the
  /// fallback for hosts whose inset updates before the platform view reports.
  var _nativeKeyboard = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final direction = Directionality.of(context);
    if (_layoutDirection == direction) return;
    _layoutDirection = direction;
    final controller = _androidViewController;
    if (controller != null) {
      unawaited(controller.setLayoutDirection(direction));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chvId = nextCardHolderVerificationId();
    _controller = widget.controller ?? PaymentElementController();
  }

  @override
  void didChangeMetrics() {
    if (_nativeKeyboard) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _nativeKeyboard) return;
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      _applyKeyboard(
        visible: inset > 0,
        keyboardTop: _keyboardTopFromInset(inset),
      );
    });
  }

  @override
  void didUpdateWidget(covariant PaymentElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_channel == null) return;
    final intentChanged =
        oldWidget.intent.orderChecksum != widget.intent.orderChecksum ||
        oldWidget.intent.orderPayload != widget.intent.orderPayload;
    final configChanged =
        oldWidget.configuration.publicKey != widget.configuration.publicKey ||
        !_configEquivalent(oldWidget.configuration, widget.configuration);
    if (intentChanged && !configChanged) {
      _controller?._relayWidgetIntent(widget.intent);
    } else if (configChanged || intentChanged) {
      _controller?._updateFromWidget(
        widget.configuration,
        widget.intent,
        _chvId,
      );
    }
  }

  bool _configEquivalent(PaymentConfig a, PaymentConfig b) {
    return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('$_viewType/$viewId');
    _channel = channel;
    _controller!._attach(channel, () => mounted);
    channel.setMethodCallHandler(_onPlatformCall);
    final createdConfig = _createdConfiguration;
    if (createdConfig != null &&
        !_configEquivalent(createdConfig, widget.configuration)) {
      _controller!._updateFromWidget(
        widget.configuration,
        widget.intent,
        _chvId,
      );
      return;
    }
    final created = _createdIntent;
    if (created != null &&
        (created.orderChecksum != widget.intent.orderChecksum ||
            created.orderPayload != widget.intent.orderPayload)) {
      _controller!._relayWidgetIntent(widget.intent);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unregisterCardHolderVerification(_chvId);
    _channel?.setMethodCallHandler(null);
    _controller?._detach();
    super.dispose();
  }

  Future<void> _onPlatformCall(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>?;
    switch (call.method) {
      case 'onEvent':
        final eventJson = args?['event'] as String? ?? '{}';
        final event = jsonDecode(eventJson) as Map<String, dynamic>;
        final bridge = mapNativeBridgeEvent(event);
        if (bridge != null) {
          switch (bridge) {
            case PaymentSheetReadyEvent():
              widget.onEvent?.call(const PaymentElementReadyEvent());
            case PaymentSheetProcessingEvent(:final isProcessing):
              widget.onEvent?.call(PaymentElementProcessingEvent(isProcessing));
              if (!isProcessing) _controller?._retryDeferredIntent();
            case PaymentSheetUpdateFailedEvent(:final code, :final message):
              widget.onEvent?.call(
                PaymentElementUpdateFailedEvent(code: code, message: message),
              );
          }
        }
        final availability = mapEmbeddedAvailabilityFlags(event);
        if (availability != null) {
          widget.onEvent?.call(
            PaymentElementAvailabilityEvent(
              isOrderConsumed: availability.isOrderConsumed,
              isInteractionEnabled: availability.isInteractionEnabled,
            ),
          );
        }
      case 'onResult':
        final resultJson = args?['result'] as String? ?? '{}';
        widget.onResult?.call(parsePaymentResult(resultJson));
      case 'onHeight':
        final height = (args?['height'] as num?)?.toDouble();
        if (height != null && mounted) {
          setState(() => _height = height);
        }
      case 'onKeyboard':
        _nativeKeyboard = true;
        final visible = args?['visible'] == true;
        final keyboardTop = (args?['keyboardTop'] as num?)?.toDouble();
        final fieldTop = (args?['fieldTop'] as num?)?.toDouble();
        final fieldBottom = (args?['fieldBottom'] as num?)?.toDouble();
        _captureField(fieldTop, fieldBottom);
        _applyKeyboard(visible: visible, keyboardTop: keyboardTop);
    }
  }

  double? _keyboardTopFromInset(double inset) {
    if (inset <= 0) return null;
    return MediaQuery.sizeOf(context).height - inset;
  }

  void _captureField(double? fieldTop, double? fieldBottom) {
    if (fieldTop == null || fieldBottom == null) return;
    final box = _platformKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final originY = box.localToGlobal(Offset.zero).dy;
    _fieldLocalBottom = fieldBottom - originY;
  }

  void _applyKeyboard({required bool visible, required double? keyboardTop}) {
    if (!mounted) return;
    if (!visible || keyboardTop == null) {
      _fieldLocalBottom = null;
      _activeKeyboardTop = null;
      _appliedFieldLocal = null;
      if (_keyboardLift != 0) {
        setState(() => _keyboardLift = 0);
      }
      return;
    }
    final lift = _liftForKeyboard(keyboardTop);
    final sameField = _fieldLocalBottom == null
        ? _appliedFieldLocal == null
        : _appliedFieldLocal != null &&
              (_fieldLocalBottom! - _appliedFieldLocal!).abs() < 1;
    final samePlace =
        _activeKeyboardTop != null &&
        (keyboardTop - _activeKeyboardTop!).abs() < 1 &&
        sameField &&
        (lift - _keyboardLift).abs() <= 1;
    if (samePlace) return;
    _activeKeyboardTop = keyboardTop;
    _appliedFieldLocal = _fieldLocalBottom;
    if ((lift - _keyboardLift).abs() > 1) {
      setState(() => _keyboardLift = lift);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollAboveKeyboard(keyboardTop);
    });
  }

  double _liftForKeyboard(double keyboardTop) {
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached || !viewport.hasSize) {
      return 0;
    }
    final bottom = viewport.localToGlobal(Offset(0, viewport.size.height)).dy;
    final overlap = bottom - keyboardTop;
    if (overlap <= 1) return 0;
    return overlap;
  }

  void _scrollAboveKeyboard(double keyboardTop, {int attempt = 0}) {
    if (_activeKeyboardTop == null) return;
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (position == null || !position.hasContentDimensions) {
      return;
    }
    final box = _platformKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport = scrollable!.context.findRenderObject() as RenderBox?;
    if (box == null ||
        viewport == null ||
        !box.attached ||
        !box.hasSize ||
        !viewport.attached ||
        !viewport.hasSize) {
      return;
    }
    final originY = box.localToGlobal(Offset.zero).dy;
    final fieldBottom = _fieldLocalBottom != null
        ? originY + _fieldLocalBottom!
        : originY + box.size.height;
    final viewportBottom = viewport
        .localToGlobal(Offset(0, viewport.size.height))
        .dy;
    final visibleBottom = math.min(keyboardTop, viewportBottom);
    final overlap = fieldBottom + 16 - visibleBottom;
    if (overlap <= 1) return;
    final desired = position.pixels + overlap;
    if (desired > position.maxScrollExtent + 1 && attempt < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollAboveKeyboard(keyboardTop, attempt: attempt + 1);
      });
    }
    final target = desired.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 1) return;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Map<String, dynamic> _creationParams() {
    if (_createdIntent == null) {
      _createdIntent = widget.intent;
      _createdConfiguration = widget.configuration;
    }
    final intent = _createdIntent!;
    return {
      'configuration': toNativeConfiguration(_createdConfiguration!, _chvId),
      'orderPayload': intent.orderPayload,
      'orderChecksum': intent.orderChecksum,
    };
  }

  Widget _buildPlatformView() {
    final params = _creationParams();
    const codec = StandardMessageCodec();
    const recognizers = {
      Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
    };
    if (isAndroid) {
      return PlatformViewLink(
        viewType: _viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: recognizers,
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          final controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _viewType,
            layoutDirection: _layoutDirection ?? Directionality.of(context),
            creationParams: _creationParams(),
            creationParamsCodec: codec,
            onFocus: () => params.onFocusChanged(true),
          );
          _androidViewController = controller;
          return controller
            ..addOnPlatformViewCreatedListener((id) {
              params.onPlatformViewCreated(id);
              _onPlatformViewCreated(id);
            })
            ..create();
        },
      );
    }
    return UiKitView(
      viewType: _viewType,
      creationParams: params,
      creationParamsCodec: codec,
      gestureRecognizers: recognizers,
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: _platformKey,
          height: _height,
          width: double.infinity,
          child: _buildPlatformView(),
        ),
        SizedBox(height: _keyboardLift),
      ],
    );
  }
}

/// Attaches a channel without a platform view. Widget tests use this.
@visibleForTesting
void attachPaymentElementControllerForTest(
  PaymentElementController controller,
  MethodChannel channel,
) {
  controller._attach(channel, () => true);
}

/// Lets widget tests drive [PaymentElement.didUpdateWidget]. The platform
/// view is never created under the test binding, so an intent change would
/// otherwise be skipped.
@visibleForTesting
void markPaymentElementPlatformViewCreatedForTest(Element element) {
  final state = (element as StatefulElement).state as _PaymentElementState;
  state._channel ??= const MethodChannel('xmoney/payment_element/test');
}

/// Controls an embedded [PaymentElement].
class PaymentElementController {
  final OrderUpdater _orders = OrderUpdater();

  void _attach(MethodChannel channel, bool Function() mounted) {
    _orders.attach(channel, mounted);
  }

  void _detach() => _orders.detach();

  /// Skips the rebind [PaymentElement] would send for an intent this
  /// controller already handed to the native SDK, including one still in flight.
  void _relayWidgetIntent(PaymentIntent intent) =>
      _orders.relayWidgetIntent(intent);

  void _retryDeferredIntent() => _orders.retryDeferred();

  void _updateFromWidget(
    PaymentConfig configuration,
    PaymentIntent intent,
    String chvId,
  ) {
    _orders.forgetAndSupersede();
    _orders.invokeQuietly('updateAll', {
      'configuration': toNativeConfiguration(configuration, chvId),
      'orderPayload': intent.orderPayload,
      'orderChecksum': intent.orderChecksum,
    });
  }

  /// Submits the selected card. Wallet buttons use their own native UI.
  Future<void> confirm() async => _orders.invoke('confirm');

  /// Rebinds [intent] on the mounted form. Pay stays disabled until bind finishes.
  ///
  /// After a failed rebind, Pay stays locked on the previous order until a
  /// later [updateOrder] succeeds.
  ///
  /// Pay stays enabled while you create [intent]. Use [updateOrderWith] when
  /// the shopper changes the cart, so Pay locks before your server responds.
  Future<void> updateOrder(PaymentIntent intent) => _orders.updateOrder(intent);

  /// Whether the [updateOrderWith] callback on the stack is still current.
  ///
  /// False once a newer update starts or the native lock for this call ends.
  /// Check it after a debounce so a superseded callback does not create an
  /// order. True outside an [updateOrderWith] callback.
  bool get isUpdateCurrent => _orders.isUpdateCurrent;

  /// Locks Pay, creates the next order, binds it, and returns it.
  ///
  /// Pay, confirm, and wallet buttons are no-ops from this call until the new
  /// order is bound, including while [createOrder] talks to your server. If
  /// [createOrder] throws, the previous order stays payable and that error is
  /// rethrown. A newer update supersedes this one
  /// (`SUPERSEDED_UPDATE_ORDER`). After a debounce, check [isUpdateCurrent]
  /// and stop before calling your server when it is false.
  Future<PaymentIntent> updateOrderWith(
    Future<PaymentIntent> Function() createOrder,
  ) => _orders.updateOrderWith(createOrder);

  /// Restyles the mounted form without remounting.
  Future<void> updateAppearance(AppearanceConfig appearance) async =>
      _orders.invoke('updateAppearance', {'appearance': appearance.toJson()});

  /// Sets UI language and pay-button amount punctuation.
  Future<void> updateLocale(String locale) async =>
      _orders.invoke('updateLocale', {'locale': locale});

  /// Sets light, dark, or automatic chrome on the mounted form.
  Future<void> updateStyle(UserInterfaceStyle style) async =>
      _orders.invoke('updateStyle', {'style': style.value});

  /// Restyles the Apple Pay or Google Pay button on the mounted form.
  Future<void> updateWalletAppearance({
    ApplePayConfig? applePay,
    GooglePayConfig? googlePay,
  }) async => _orders.invoke('updateWalletAppearance', {
    if (applePay?.appearance != null)
      'applePay': applePay!.appearance!.toJson(),
    if (googlePay?.appearance != null)
      'googlePay': googlePay!.appearance!.toJson(),
  });
}
