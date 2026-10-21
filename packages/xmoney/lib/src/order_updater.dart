import 'dart:async';

import 'package:flutter/services.dart';
import 'package:xmoney_platform_interface/xmoney_platform_interface.dart';

import 'errors.dart';

/// Zone value for the [OrderUpdater.updateOrderWith] call that is running
/// [OrderUpdater.isUpdateCurrent].
final Object updateZoneKey = Object();

/// Shared order rebinding for the payment element and the wallet buttons.
///
/// The native SDKs lock Pay before the server creates the next order. Dart
/// futures cannot be cancelled, so [isUpdateCurrent] tells the callback when
/// a newer update has replaced it.
class OrderUpdater {
  MethodChannel? _channel;
  bool Function()? _mounted;
  String? _sentPayload;
  String? _sentChecksum;
  String? _pendingPayload;
  String? _pendingChecksum;
  var _updateSeq = 0;
  final Set<int> _lostLock = {};
  static var _nextRequest = 0;

  /// The checksum of the last order handed to the native SDK.
  String? get sentChecksumForTest => _sentChecksum;

  /// Called when the widget drops this controller. In-flight updates end.
  void detach() {
    _updateSeq++;
    _channel = null;
    _mounted = null;
    _sentPayload = null;
    _sentChecksum = null;
    _pendingPayload = null;
    _pendingChecksum = null;
    _lostLock.clear();
  }

  /// Called when the platform view is created.
  void attach(MethodChannel channel, bool Function() mounted) {
    _channel = channel;
    _mounted = mounted;
  }

  /// Skips the rebind a widget would send for an intent already handed to the
  /// native SDK, including one still in flight.
  void relayWidgetIntent(PaymentIntent intent) {
    if (_sameIntent(_sentPayload, _sentChecksum, intent) ||
        _sameIntent(_pendingPayload, _pendingChecksum, intent)) {
      return;
    }
    updateOrder(intent);
  }

  /// Drops remembered intents and supersedes in-flight updates. Used before a
  /// full rebuild of the native surface.
  void forgetAndSupersede() {
    _updateSeq++;
    _sentPayload = null;
    _sentChecksum = null;
    _pendingPayload = null;
    _pendingChecksum = null;
  }

  /// Rebinds [intent]. Pay stays disabled until the bind finishes.
  ///
  /// After a failed rebind, Pay stays locked on the previous order until a
  /// later [updateOrder] succeeds.
  ///
  /// Pay stays enabled while you create [intent]. Use [updateOrderWith] when
  /// the shopper changes the cart, so Pay locks before your server responds.
  Future<void> updateOrder(PaymentIntent intent) async {
    final seq = ++_updateSeq;
    _holdPending(intent);
    try {
      await _invoke('updateOrder', {
        'orderPayload': intent.orderPayload,
        'orderChecksum': intent.orderChecksum,
      });
    } on Object {
      _dropPending(intent, seq);
      rethrow;
    }
    if (seq == _updateSeq) _remember(intent);
  }

  /// Whether the [updateOrderWith] callback on the stack is still current.
  ///
  /// False once a newer update starts or the native lock for this call ends.
  /// Check it after a debounce so a superseded callback does not create an
  /// order. True outside an [updateOrderWith] callback.
  bool get isUpdateCurrent {
    final seq = Zone.current[updateZoneKey] as int?;
    return seq == null || (seq == _updateSeq && !_lostLock.contains(seq));
  }

  /// Locks Pay, creates the next order, binds it, and returns it.
  ///
  /// Pay is a no-op from this call until the new order is bound, including
  /// while [createOrder] talks to your server. If [createOrder] throws, the
  /// previous order stays payable and that error is rethrown. A newer update
  /// supersedes this one (`SUPERSEDED_UPDATE_ORDER`). After a debounce, check
  /// [isUpdateCurrent] and stop before calling your server when it is false.
  Future<PaymentIntent> updateOrderWith(
    Future<PaymentIntent> Function() createOrder,
  ) async {
    _ensureAttached();
    final seq = ++_updateSeq;
    final requestId = '${identityHashCode(this)}-${_nextRequest++}';
    final begin = _invoke('beginUpdateOrder', {'requestId': requestId});
    // Handled immediately so a lock that fails while [createOrder] is still
    // running is not reported as an uncaught error.
    final beginOutcome = begin.then<Object?>(
      (_) => null,
      onError: (Object error) {
        _lostLock.add(seq);
        return error;
      },
    );

    PaymentIntent? intent;
    Object? createError;
    StackTrace? createStack;
    try {
      intent = await runZoned(createOrder, zoneValues: {updateZoneKey: seq});
    } on Object catch (error, stack) {
      createError = error;
      createStack = stack;
    }

    try {
      if (seq != _updateSeq) {
        await _rejectQuietly(requestId);
        await beginOutcome;
        throw _supersededUpdate();
      }
      if (_lostLock.contains(seq)) {
        await _rejectQuietly(requestId);
        throw (await beginOutcome)!;
      }
      if (createError != null) {
        await _rejectQuietly(requestId);
        await beginOutcome;
        Error.throwWithStackTrace(createError, createStack!);
      }
      final bound = intent!;
      _holdPending(bound);
      try {
        await _invoke('resolveOrder', {
          'requestId': requestId,
          'orderPayload': bound.orderPayload,
          'orderChecksum': bound.orderChecksum,
        });
        final beginError = await beginOutcome;
        if (beginError != null) throw beginError;
        if (!_isSeqCurrent(seq)) throw _supersededUpdate();
      } on Object {
        if (_sameIntent(_pendingPayload, _pendingChecksum, bound)) {
          _pendingPayload = null;
          _pendingChecksum = null;
        }
        rethrow;
      }
      _remember(bound);
      return bound;
    } finally {
      _lostLock.remove(seq);
    }
  }

  /// Sends [method] to the native surface.
  Future<void> invoke(String method, [Map<String, dynamic>? args]) =>
      _invoke(method, args);

  void _remember(PaymentIntent intent) {
    _sentPayload = intent.orderPayload;
    _sentChecksum = intent.orderChecksum;
    if (_pendingPayload == intent.orderPayload &&
        _pendingChecksum == intent.orderChecksum) {
      _pendingPayload = null;
      _pendingChecksum = null;
    }
  }

  void _holdPending(PaymentIntent intent) {
    _pendingPayload = intent.orderPayload;
    _pendingChecksum = intent.orderChecksum;
  }

  void _dropPending(PaymentIntent intent, int seq) {
    if (seq == _updateSeq &&
        _pendingPayload == intent.orderPayload &&
        _pendingChecksum == intent.orderChecksum) {
      _pendingPayload = null;
      _pendingChecksum = null;
    }
  }

  bool _sameIntent(String? payload, String? checksum, PaymentIntent intent) {
    return payload == intent.orderPayload && checksum == intent.orderChecksum;
  }

  bool _isSeqCurrent(int seq) => seq == _updateSeq && !_lostLock.contains(seq);

  XMoneyPaymentError _supersededUpdate() {
    return XMoneyPaymentError(
      'SUPERSEDED_UPDATE_ORDER',
      stableMessages['SUPERSEDED_UPDATE_ORDER']!,
    );
  }

  Future<void> _rejectQuietly(String requestId) async {
    try {
      await _invoke('rejectOrder', {'requestId': requestId});
    } on Object {
      // The caller throws the merchant error or SUPERSEDED_UPDATE_ORDER.
    }
  }

  void _ensureAttached() {
    if (_channel == null || _mounted?.call() != true) {
      throw XMoneyPaymentError(
        'NOT_INITIALIZED',
        stableMessages['NOT_INITIALIZED']!,
      );
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    _ensureAttached();
    try {
      await _channel!.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      throw XMoneyPaymentError.from(error);
    }
  }
}
