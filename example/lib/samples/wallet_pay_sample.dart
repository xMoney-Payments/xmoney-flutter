import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';

class WalletPaySample extends StatefulWidget {
  const WalletPaySample({
    required this.secrets,
    required this.onBack,
    this.onPayWithCard,
    super.key,
  });

  final DemoSecrets secrets;
  final VoidCallback onBack;
  final VoidCallback? onPayWithCard;

  @override
  State<WalletPaySample> createState() => _WalletPaySampleState();
}

class _WalletPaySampleState extends State<WalletPaySample> {
  PaymentIntent? _intent;
  PaymentResult? _lastResult;
  String? _error;
  var _loading = true;
  var _ready = false;
  var _available = true;
  var _consumed = false;

  bool get _ios => Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastResult = null;
      _ready = false;
      _consumed = false;
      _intent = null;
    });
    try {
      final intent =
          await DemoCheckoutBackend(widget.secrets).createPaymentIntent();
      if (!mounted) return;
      setState(() => _intent = intent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.exampleDark;
    final intent = _intent;
    final preparing = _ios ? 'Preparing Apple Pay…' : 'Preparing Google Pay…';
    final config = defaultPaymentConfig(
      widget.secrets,
      dark: dark,
      savedCardsEnabled: false,
    );

    return SampleScaffold(
      title: _ios ? 'Apple Pay' : 'Google Pay',
      subtitle: 'Standalone wallet button in your screen.',
      onBack: widget.onBack,
      showTestCards: true,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SampleOrderCard(
              title: widget.secrets.description,
              amount: formatMoney(
                sampleAmountMinor,
                currency: widget.secrets.currency,
              ),
            ),
            const SizedBox(height: 16),
            if (_consumed && _lastResult != null) ...[
              ExampleResultPanel(result: _lastResult!),
              const SizedBox(height: 16),
              ExampleButton(
                label: 'New payment',
                variant: ExampleButtonVariant.secondary,
                onPressed: _loadOrder,
              ),
            ] else if (_loading && intent == null)
              ExampleLoader(message: preparing)
            else if (intent != null) ...[
              MerchantReadyGate(
                ready: _ready,
                message: preparing,
                minHeight: 56,
                child: SizedBox(
                  height: 56,
                  child: _ios
                      ? ApplePayButton(
                          configuration: config,
                          intent: intent,
                          onEvent: _onWalletEvent,
                          onResult: _onWalletResult,
                        )
                      : GooglePayButton(
                          configuration: config,
                          intent: intent,
                          onEvent: _onWalletEvent,
                          onResult: _onWalletResult,
                        ),
                ),
              ),
              if (_lastResult is PaymentResultCanceled && !_consumed) ...[
                const SizedBox(height: 12),
                ExampleStatusChip(
                  text: _ios
                      ? 'You closed Apple Pay before finishing.'
                      : 'You closed Google Pay before finishing.',
                ),
              ],
              if (_ready && !_available) ...[
                const SizedBox(height: 12),
                ExampleStatusChip(
                  text: _ios
                      ? 'Apple Pay isn’t available on this device.'
                      : 'Google Pay isn’t available on this device.',
                ),
                if (widget.onPayWithCard != null) ...[
                  const SizedBox(height: 12),
                  ExampleButton(
                    label: 'Pay with card',
                    variant: ExampleButtonVariant.secondary,
                    onPressed: () => widget.onPayWithCard?.call(),
                  ),
                ],
              ],
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

  void _onWalletEvent(WalletPayEvent event) {
    if (isNativeBoundWalletEvent(event)) {
      setState(() => _ready = true);
    }
    if (event is WalletPayAvailabilityEvent) {
      setState(() {
        _available = event.isAvailable && event.isReady;
        if (event.isOrderConsumed) _consumed = true;
      });
    }
  }

  void _onWalletResult(PaymentResult result) {
    final bindError = bindFailureMessage(result);
    if (bindError != null) {
      setState(() {
        _error = bindError;
        _ready = true;
      });
    }
    setState(() => _lastResult = result);
    if (result is! PaymentResultCanceled) {
      setState(() => _consumed = true);
    }
  }
}
