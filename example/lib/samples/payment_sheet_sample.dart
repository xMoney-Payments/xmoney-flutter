import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';

class PaymentSheetSample extends StatefulWidget {
  const PaymentSheetSample({required this.secrets, required this.onBack, super.key});

  final DemoSecrets secrets;
  final VoidCallback onBack;

  @override
  State<PaymentSheetSample> createState() => _PaymentSheetSampleState();
}

class _PaymentSheetSampleState extends State<PaymentSheetSample> {
  final _sheet = PaymentSheetController();
  PaymentResult? _lastResult;
  PaymentIntent? _heldIntent;
  var _consumed = false;
  String? _error;
  var _loading = false;

  Future<void> _present(PaymentIntent intent) async {
    var processed = false;
    setState(() => _heldIntent = intent);
    final dark = context.exampleDark;
    await _sheet.init(defaultPaymentConfig(widget.secrets, dark: dark));
    final result = await _sheet.present(intent, onEvent: (event) {
      if (event is PaymentSheetProcessingEvent && event.isProcessing) {
        processed = true;
      }
    });
    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _loading = false;
      _consumed = orderConsumed(result, processed);
      if (_consumed) _heldIntent = null;
    });
  }

  Future<void> _onPay() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final backend = DemoCheckoutBackend(widget.secrets);
      final intent =
          _heldIntent ?? await backend.createPaymentIntent();
      await _present(intent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SampleScaffold(
      title: 'Payment Sheet',
      subtitle: 'SDK owns the full checkout UI.',
      onBack: widget.onBack,
      showTestCards: true,
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (!_consumed) ...[
              SampleOrderCard(
                title: widget.secrets.description,
                amount: formatMoney(
                  sampleAmountMinor,
                  currency: widget.secrets.currency,
                ),
              ),
              const SizedBox(height: 16),
              ExampleButton(
                label: _lastResult is PaymentResultCanceled ? 'Continue' : 'Pay',
                loading: _loading,
                onPressed: _onPay,
              ),
              if (_lastResult is PaymentResultCanceled) ...[
                const SizedBox(height: 12),
                const ExampleStatusChip(
                  text: 'You closed checkout before finishing.',
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              ExampleStatusChip(
                text: _error!,
                kind: ExampleStatusKind.error,
              ),
            ],
            if (_consumed && _lastResult != null) ...[
              ExampleResultPanel(result: _lastResult!),
              const SizedBox(height: 16),
              ExampleButton(
                label: 'New payment',
                variant: ExampleButtonVariant.secondary,
                onPressed: () => setState(() {
                  _lastResult = null;
                  _heldIntent = null;
                  _consumed = false;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
