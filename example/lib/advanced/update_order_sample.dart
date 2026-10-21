import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';

const _amountStep = 500;
const _amountMin = 500;

class UpdateOrderSample extends StatefulWidget {
  const UpdateOrderSample({
    required this.secrets,
    required this.onBack,
    super.key,
  });

  final DemoSecrets secrets;
  final VoidCallback onBack;

  @override
  State<UpdateOrderSample> createState() => _UpdateOrderSampleState();
}

class _UpdateOrderSampleState extends State<UpdateOrderSample> {
  final _controller = PaymentElementController();
  var _amountMinor = sampleAmountMinor;
  PaymentIntent? _intent;
  PaymentResult? _lastResult;
  String? _error;
  var _loading = true;
  var _ready = false;
  var _canPay = true;
  var _consumed = false;
  var _orderRequest = 0;

  @override
  void initState() {
    super.initState();
    _scheduleOrder(initial: true);
  }

  @override
  void didUpdateWidget(covariant UpdateOrderSample oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _orderRequest++;
    super.dispose();
  }

  void _scheduleOrder({required bool initial}) {
    if (_consumed) return;
    final request = ++_orderRequest;
    final amount = _amountMinor;
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    if (_intent != null) {
      _replaceOrder(request, amount, debounce: !initial, initial: initial);
    } else {
      _loadOrder(request, amount, initial: initial);
    }
  }

  Future<void> _loadOrder(
    int request,
    int amount, {
    required bool initial,
  }) async {
    try {
      final next = await DemoCheckoutBackend(
        widget.secrets,
      ).createPaymentIntent(amountMinor: amount);
      if (!mounted || request != _orderRequest) return;
      setState(() {
        _intent = next;
        _canPay = false;
      });
    } catch (e) {
      if (!mounted || request != _orderRequest) return;
      setState(() => _error = e.toString());
    } finally {
      if (initial && mounted && request == _orderRequest) {
        setState(() => _loading = false);
      }
    }
  }

  /// Locks Pay immediately, then binds the order created after the debounce.
  Future<void> _replaceOrder(
    int request,
    int amount, {
    required bool debounce,
    required bool initial,
  }) async {
    try {
      final next = await _controller.updateOrderWith(() async {
        if (debounce) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        if (!_controller.isUpdateCurrent) throw StateError('superseded');
        return DemoCheckoutBackend(
          widget.secrets,
        ).createPaymentIntent(amountMinor: amount);
      });
      if (!mounted || request != _orderRequest) return;
      setState(() => _intent = next);
    } catch (e) {
      if (!mounted || request != _orderRequest || isSupersededUpdate(e)) return;
      setState(() => _error = e.toString());
    } finally {
      if (initial && mounted && request == _orderRequest) {
        setState(() => _loading = false);
      }
    }
  }

  void _changeAmount(int delta) {
    setState(() {
      _amountMinor = (_amountMinor + delta).clamp(_amountMin, 999999);
    });
    _scheduleOrder(initial: false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.exampleDark;
    final intent = _intent;
    return SampleScaffold(
      title: 'Update order',
      subtitle: 'updateOrder() a new PaymentIntent — Pay locked until Ready.',
      onBack: widget.onBack,
      showTestCards: true,
      child: SingleChildScrollView(
        child: Column(
          children: [
            ExampleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: context.exampleColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExampleStepperRow(
                    title: 'Demo total',
                    valueLabel: formatMoney(
                      _amountMinor,
                      currency: widget.secrets.currency,
                    ),
                    onMinus: () => _changeAmount(-_amountStep),
                    onPlus: () => _changeAmount(_amountStep),
                    minusEnabled: _amountMinor > _amountMin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_consumed && _lastResult != null) ...[
              ExampleResultPanel(result: _lastResult!),
              const SizedBox(height: 16),
              ExampleButton(
                label: 'New payment',
                variant: ExampleButtonVariant.secondary,
                onPressed: () => setState(() {
                  _consumed = false;
                  _lastResult = null;
                  _amountMinor = sampleAmountMinor;
                  _scheduleOrder(initial: true);
                }),
              ),
            ] else if (_loading && intent == null)
              const ExampleLoader(message: 'Preparing checkout…')
            else if (intent != null)
              MerchantReadyGate(
                ready: _ready,
                message: 'Preparing checkout…',
                child: PaymentElement(
                  controller: _controller,
                  configuration: defaultPaymentConfig(
                    widget.secrets,
                    dark: dark,
                  ),
                  intent: intent,
                  onEvent: (event) {
                    if (isNativeBoundElementEvent(event)) {
                      setState(() {
                        _ready = true;
                        _canPay = true;
                      });
                    }
                    if (event is PaymentElementAvailabilityEvent) {
                      setState(() {
                        _canPay = event.isInteractionEnabled;
                      });
                    }
                  },
                  onResult: (result) {
                    setState(() => _lastResult = result);
                    if (result is! PaymentResultCanceled) {
                      setState(() => _consumed = true);
                    }
                  },
                ),
              ),
            if (!_consumed && intent != null) ...[
              const SizedBox(height: 12),
              ExampleStatusChip(
                text: _canPay && _ready
                    ? 'Ready — change amount to exercise updateOrder().'
                    : 'Waiting for native checkout to bind…',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              ExampleStatusChip(text: _error!, kind: ExampleStatusKind.error),
            ],
          ],
        ),
      ),
    );
  }
}
