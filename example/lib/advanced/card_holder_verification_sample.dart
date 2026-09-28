import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';

class CardHolderVerificationSample extends StatefulWidget {
  const CardHolderVerificationSample({
    required this.secrets,
    required this.onBack,
    super.key,
  });

  final DemoSecrets secrets;
  final VoidCallback onBack;

  @override
  State<CardHolderVerificationSample> createState() =>
      _CardHolderVerificationSampleState();
}

class _CardHolderVerificationSampleState
    extends State<CardHolderVerificationSample> {
  PaymentIntent? _intent;
  PaymentResult? _lastResult;
  String? _chvStatus;
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
      _chvStatus = null;
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
      title: 'Card holder verification',
      subtitle: 'Pre-pay name check via CardHolderVerification.',
      onBack: widget.onBack,
      showTestCards: true,
      nameCheckHint: true,
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
            if (_chvStatus != null) ...[
              const SizedBox(height: 12),
              ExampleStatusChip(text: _chvStatus!),
            ],
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
            else if (intent != null)
              MerchantReadyGate(
                ready: _ready,
                message: 'Preparing checkout…',
                child: PaymentElement(
                  configuration: PaymentConfig(
                    publicKey: widget.secrets.publicKey,
                    options: OptionsConfig(
                      style: exampleForcedStyle(dark),
                      appearance: exampleAppearance(),
                    ),
                    card: CardConfig(
                      savedCards: const SavedCardsConfig(enabled: true),
                      cardHolderVerification: CardHolderVerification(
                        name: const CardHolderName(
                          firstName: 'Test',
                          lastName: 'User',
                        ),
                        onCardHolderVerification: (result) {
                          setState(
                            () => _chvStatus = 'CHV: ${result.status.value}',
                          );
                          return result.status ==
                              CardHolderMatchStatus.matched;
                        },
                      ),
                    ),
                  ),
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
