import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';

enum _PlaygroundMode { embedded, sheet, wallet }

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({
    required this.secrets,
    required this.onBack,
    super.key,
  });

  final DemoSecrets secrets;
  final VoidCallback onBack;

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  _PlaygroundMode _mode = _PlaygroundMode.embedded;
  var _amountMinor = sampleAmountMinor;
  var _savedCards = true;
  var _submitVisible = true;
  final _validation = ValidationMode.onTouched;
  final _grouping = CardGrouping.condensed;
  final _style = UserInterfaceStyle.automatic;
  final _locale = '';
  var _applePay = true;
  var _googlePay = true;
  final _submitType = SubmitButtonType.pay;

  PaymentIntent? _intent;
  PaymentResult? _lastResult;
  String? _error;
  var _loading = true;
  var _ready = false;
  var _consumed = false;
  Timer? _debounce;

  final _elementController = PaymentElementController();
  final _sheet = PaymentSheetController();

  @override
  void initState() {
    super.initState();
    _scheduleOrder(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  PaymentConfig _configuration(bool dark) {
    return PaymentConfig(
      publicKey: widget.secrets.publicKey,
      paymentMethods: PaymentMethodsConfig(
        applePay: ApplePayConfig(
          enabled: _applePay,
          appearance: exampleWalletAppearance(dark),
        ),
        googlePay: GooglePayConfig(
          enabled: _googlePay,
          appearance: exampleWalletAppearance(dark),
        ),
      ),
      card: CardConfig(
        savedCards: SavedCardsConfig(enabled: _savedCards),
        validationMode: _validation,
        inputs: CardInputsConfig(grouping: _grouping),
        submitButton: SubmitButtonConfig(
          visible: _submitVisible,
          type: _submitType,
        ),
      ),
      options: OptionsConfig(
        locale: _locale.isEmpty ? null : _locale,
        style: _style == UserInterfaceStyle.automatic
            ? exampleForcedStyle(dark)
            : _style,
        appearance: exampleAppearance(),
      ),
    );
  }

  void _scheduleOrder({required bool initial}) {
    if (_consumed) return;
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: initial ? 0 : 300), () async {
      if (initial) setState(() => _loading = true);
      setState(() => _error = null);
      try {
        final next = await DemoCheckoutBackend(widget.secrets)
            .createPaymentIntent(amountMinor: _amountMinor);
        if (!mounted) return;
        if (_intent != null && _mode == _PlaygroundMode.embedded) {
          await _elementController.updateOrder(next);
        }
        setState(() => _intent = next);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      } finally {
        if (initial && mounted) setState(() => _loading = false);
      }
    });
  }

  void _onConfigChanged() {
    setState(() {
      _ready = false;
      _lastResult = null;
    });
    _scheduleOrder(initial: _intent == null);
  }

  Future<void> _presentSheet() async {
    final intent = _intent;
    if (intent == null) return;
    setState(() => _loading = true);
    final dark = context.exampleDark;
    try {
      await _sheet.init(_configuration(dark));
      final result = await _sheet.present(intent);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _loading = false;
        _consumed = result is! PaymentResultCanceled;
      });
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
    final dark = context.exampleDark;
    final intent = _intent;
    final config = _configuration(dark);

    return Scaffold(
      backgroundColor: context.exampleColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            ExampleTopBar(
              title: 'Playground',
              subtitle: 'PaymentConfig toggles with a live checkout surface.',
              onBack: widget.onBack,
              showTestCards: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  ExampleSection(
                    title: 'Integration',
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: ExampleSegmentedRow<_PlaygroundMode>(
                          options: const [
                            (label: 'Element', value: _PlaygroundMode.embedded),
                            (label: 'Sheet', value: _PlaygroundMode.sheet),
                            (label: 'Wallet', value: _PlaygroundMode.wallet),
                          ],
                          value: _mode,
                          onChanged: (value) {
                            setState(() => _mode = value);
                            _onConfigChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExampleSection(
                    title: 'Card & wallets',
                    children: [
                      ExampleSwitchRow(
                        title: 'Saved cards',
                        subtitle: 'card.savedCards.enabled',
                        value: _savedCards,
                        onChanged: (v) {
                          setState(() => _savedCards = v);
                          _onConfigChanged();
                        },
                      ),
                      ExampleSwitchRow(
                        title: 'Submit button',
                        subtitle: 'card.submitButton.visible',
                        value: _submitVisible,
                        onChanged: (v) {
                          setState(() => _submitVisible = v);
                          _onConfigChanged();
                        },
                        showDivider: true,
                      ),
                      ExampleSwitchRow(
                        title: 'Apple Pay',
                        subtitle: 'paymentMethods.applePay.enabled',
                        value: _applePay,
                        onChanged: (v) {
                          setState(() => _applePay = v);
                          _onConfigChanged();
                        },
                        showDivider: true,
                      ),
                      ExampleSwitchRow(
                        title: 'Google Pay',
                        subtitle: 'paymentMethods.googlePay.enabled',
                        value: _googlePay,
                        onChanged: (v) {
                          setState(() => _googlePay = v);
                          _onConfigChanged();
                        },
                        showDivider: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExampleStepperRow(
                    title: 'Amount',
                    caption: 'Creates a new demo order',
                    valueLabel: formatMoney(
                      _amountMinor,
                      currency: widget.secrets.currency,
                    ),
                    onMinus: () {
                      setState(() {
                        _amountMinor =
                            (_amountMinor - 500).clamp(500, 999999);
                      });
                      _scheduleOrder(initial: false);
                    },
                    onPlus: () {
                      setState(() => _amountMinor += 500);
                      _scheduleOrder(initial: false);
                    },
                    minusEnabled: _amountMinor > 500,
                  ),
                  const SizedBox(height: 16),
                  if (_consumed && _lastResult != null) ...[
                    ExampleResultPanel(result: _lastResult!),
                    const SizedBox(height: 12),
                    ExampleButton(
                      label: 'Reset',
                      variant: ExampleButtonVariant.secondary,
                      onPressed: () => setState(() {
                        _consumed = false;
                        _lastResult = null;
                        _ready = false;
                        _scheduleOrder(initial: true);
                      }),
                    ),
                  ] else if (_loading && intent == null)
                    const ExampleLoader(message: 'Preparing checkout…')
                  else if (intent != null) ...[
                    if (_mode == _PlaygroundMode.sheet)
                      ExampleButton(
                        label: 'Present Payment Sheet',
                        loading: _loading,
                        onPressed: _presentSheet,
                      )
                    else if (_mode == _PlaygroundMode.wallet)
                      MerchantReadyGate(
                        ready: _ready,
                        message: Platform.isIOS
                            ? 'Preparing Apple Pay…'
                            : 'Preparing Google Pay…',
                        minHeight: 56,
                        child: SizedBox(
                          height: 56,
                          child: Platform.isIOS
                              ? ApplePayButton(
                                  configuration: config,
                                  intent: intent,
                                  onEvent: (e) {
                                    if (isNativeBoundWalletEvent(e)) {
                                      setState(() => _ready = true);
                                    }
                                  },
                                  onResult: (r) => setState(() {
                                    _lastResult = r;
                                    _consumed = r is! PaymentResultCanceled;
                                  }),
                                )
                              : GooglePayButton(
                                  configuration: config,
                                  intent: intent,
                                  onEvent: (e) {
                                    if (isNativeBoundWalletEvent(e)) {
                                      setState(() => _ready = true);
                                    }
                                  },
                                  onResult: (r) => setState(() {
                                    _lastResult = r;
                                    _consumed = r is! PaymentResultCanceled;
                                  }),
                                ),
                        ),
                      )
                    else
                      MerchantReadyGate(
                        ready: _ready,
                        message: 'Preparing checkout…',
                        child: PaymentElement(
                          key: ValueKey(Object.hash(
                            _savedCards,
                            _submitVisible,
                            _validation,
                            _grouping,
                            _style,
                            _locale,
                            _applePay,
                            _googlePay,
                            _submitType,
                            dark,
                          )),
                          controller: _elementController,
                          configuration: config,
                          intent: intent,
                          onEvent: (event) {
                            if (isNativeBoundElementEvent(event)) {
                              setState(() => _ready = true);
                            }
                          },
                          onResult: (result) {
                            setState(() {
                              _lastResult = result;
                              if (result is! PaymentResultCanceled) {
                                _consumed = true;
                              }
                            });
                          },
                        ),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ExampleStatusChip(
                      text: _error!,
                      kind: ExampleStatusKind.error,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
