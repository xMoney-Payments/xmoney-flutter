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
import '../errors.dart';
import '../native_events.dart';
import '../parse_result.dart';
import '../platform_target.dart';

/// Events emitted by [PaymentElement].
sealed class PaymentElementEvent {
  /// Base type for embedded form events.
  const PaymentElementEvent();
}

/// The embedded form finished binding and can be shown.
final class PaymentElementReadyEvent extends PaymentElementEvent {
  /// The form is bound.
  const PaymentElementReadyEvent();
}

/// An in-flight charge. [PaymentElementController.updateOrder] does not emit this.
final class PaymentElementProcessingEvent extends PaymentElementEvent {
  /// An in-flight charge. [isProcessing] is false when it settles.
  const PaymentElementProcessingEvent(this.isProcessing);

  /// Whether a charge is in flight.
  final bool isProcessing;
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

  /// False during [PaymentElementController.updateOrder] and while a charge is in flight.
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

  /// Ready, processing, and availability while the form is mounted.
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
    final intentChanged =
        oldWidget.intent.orderChecksum != widget.intent.orderChecksum ||
        oldWidget.intent.orderPayload != widget.intent.orderPayload;
    final configChanged =
        oldWidget.configuration.publicKey != widget.configuration.publicKey ||
        !_configEquivalent(oldWidget.configuration, widget.configuration);
    if (intentChanged && !configChanged) {
      _controller?.updateOrder(widget.intent);
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
    return {
      'configuration': toNativeConfiguration(widget.configuration, _chvId),
      'orderPayload': widget.intent.orderPayload,
      'orderChecksum': widget.intent.orderChecksum,
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

/// Controls an embedded [PaymentElement].
class PaymentElementController {
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

  void _updateFromWidget(
    PaymentConfig configuration,
    PaymentIntent intent,
    String chvId,
  ) {
    _invoke('updateAll', {
      'configuration': toNativeConfiguration(configuration, chvId),
      'orderPayload': intent.orderPayload,
      'orderChecksum': intent.orderChecksum,
    });
  }

  /// Submits the selected card. Wallet buttons use their own native UI.
  Future<void> confirm() async => _invoke('confirm');

  /// Rebinds [intent] on the mounted form. Pay stays disabled until bind finishes.
  Future<void> updateOrder(PaymentIntent intent) async =>
      _invoke('updateOrder', {
        'orderPayload': intent.orderPayload,
        'orderChecksum': intent.orderChecksum,
      });

  /// Restyles the mounted form without remounting.
  Future<void> updateAppearance(AppearanceConfig appearance) async =>
      _invoke('updateAppearance', {'appearance': appearance.toJson()});

  /// Sets UI language and pay-button amount punctuation.
  Future<void> updateLocale(String locale) async =>
      _invoke('updateLocale', {'locale': locale});

  /// Sets light, dark, or automatic chrome on the mounted form.
  Future<void> updateStyle(UserInterfaceStyle style) async =>
      _invoke('updateStyle', {'style': style.value});

  /// Restyles the Apple Pay or Google Pay button on the mounted form.
  Future<void> updateWalletAppearance({
    ApplePayConfig? applePay,
    GooglePayConfig? googlePay,
  }) async => _invoke('updateWalletAppearance', {
    if (applePay?.appearance != null)
      'applePay': applePay!.appearance!.toJson(),
    if (googlePay?.appearance != null)
      'googlePay': googlePay!.appearance!.toJson(),
  });

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    if (_channel == null || _mounted?.call() != true) {
      throw XMoneyPaymentError(
        'NOT_INITIALIZED',
        stableMessages['NOT_INITIALIZED']!,
      );
    }
    try {
      await _channel!.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      throw XMoneyPaymentError.from(error);
    }
  }
}
