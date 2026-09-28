import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';

class MerchantConfirmSample extends StatefulWidget {
  const MerchantConfirmSample({
    required this.secrets,
    required this.onBack,
    super.key,
  });

  final DemoSecrets secrets;
  final VoidCallback onBack;

  @override
  State<MerchantConfirmSample> createState() => _MerchantConfirmSampleState();
}

class _MerchantConfirmSampleState extends State<MerchantConfirmSample> {
  final _controller = PaymentElementController();
  PaymentIntent? _intent;
  PaymentResult? _lastResult;
  String? _error;
  var _loading = true;
  var _ready = false;
  var _consumed = false;

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
    return SampleScaffold(
      title: 'Merchant Pay button',
      subtitle: 'Embedded form, your CTA via confirm().',
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
              const ExampleLoader(message: 'Preparing checkout…')
            else if (intent != null) ...[
              MerchantReadyGate(
                ready: _ready,
                message: 'Preparing checkout…',
                child: PaymentElement(
                  controller: _controller,
                  configuration: defaultPaymentConfig(
                    widget.secrets,
                    dark: dark,
                  ).copyWithSubmitHidden(),
                  intent: intent,
                  onEvent: (event) {
                    if (isNativeBoundElementEvent(event)) {
                      setState(() => _ready = true);
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
              const SizedBox(height: 16),
              ExampleButton(
                label: 'Pay',
                enabled: _ready,
                onPressed: () => _controller.confirm(),
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

extension on PaymentConfig {
  PaymentConfig copyWithSubmitHidden() {
    return PaymentConfig(
      publicKey: publicKey,
      card: CardConfig(
        savedCards: card?.savedCards,
        cardHolderVerification: card?.cardHolderVerification,
        inputs: card?.inputs,
        validationMode: card?.validationMode,
        submitButton: const SubmitButtonConfig(visible: false),
      ),
      paymentMethods: paymentMethods,
      options: options,
    );
  }
}
