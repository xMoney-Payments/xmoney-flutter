import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'advanced/card_holder_verification_sample.dart';
import 'advanced/merchant_confirm_sample.dart';
import 'advanced/update_order_sample.dart';
import 'backend/demo_checkout_backend.dart';
import 'menu_screen.dart';
import 'playground/playground_screen.dart';
import 'samples/payment_element_sample.dart';
import 'samples/payment_sheet_sample.dart';
import 'samples/wallet_pay_sample.dart';
import 'scenarios/merchant_models.dart';
import 'scenarios/merchant_store.dart';
import 'theme/example_theme.dart';

class XMoneyExampleApp extends StatelessWidget {
  const XMoneyExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExampleThemeProvider(
      child: _ExampleMaterialApp(),
    );
  }
}

class _ExampleMaterialApp extends StatelessWidget {
  const _ExampleMaterialApp();

  @override
  Widget build(BuildContext context) {
    final dark = context.exampleDark;
    return MaterialApp(
      title: 'xMoney · Flutter',
      debugShowCheckedModeBanner: false,
      theme: exampleThemeData(context.exampleColors, dark: dark),
      home: const ExampleRoot(),
    );
  }
}

class ExampleRoot extends StatefulWidget {
  const ExampleRoot({super.key});

  @override
  State<ExampleRoot> createState() => _ExampleRootState();
}

class _ExampleRootState extends State<ExampleRoot> {
  DemoSecrets? _secrets;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSecrets();
  }

  Future<void> _loadSecrets() async {
    try {
      final raw = await rootBundle.loadString('secrets.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _secrets = DemoSecrets.fromJson(map));
    } on FlutterError {
      setState(() {
        _loadError = 'Copy secrets.json.example to secrets.json';
      });
    } catch (error) {
      setState(() => _loadError = error.toString());
    }
  }

  void _open(MenuDestination destination) {
    final secrets = _secrets;
    if (secrets == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _screenFor(destination, secrets),
      ),
    );
  }

  Widget _screenFor(MenuDestination destination, DemoSecrets secrets) {
    void pop() => Navigator.of(context).pop();

    switch (destination) {
      case MenuDestination.sheet:
        return PaymentSheetSample(secrets: secrets, onBack: pop);
      case MenuDestination.element:
        return PaymentElementSample(secrets: secrets, onBack: pop);
      case MenuDestination.wallet:
        return WalletPaySample(
          secrets: secrets,
          onBack: pop,
          onPayWithCard: () {
            pop();
            _open(MenuDestination.element);
          },
        );
      case MenuDestination.lumen:
        return MerchantStore(
          brand: lumenBrand,
          secrets: secrets,
          onLeave: pop,
        );
      case MenuDestination.hearth:
        return MerchantStore(
          brand: hearthBrand,
          secrets: secrets,
          onLeave: pop,
        );
      case MenuDestination.pulse:
        return MerchantStore(
          brand: pulseBrand,
          secrets: secrets,
          onLeave: pop,
        );
      case MenuDestination.merchantPay:
        return MerchantConfirmSample(secrets: secrets, onBack: pop);
      case MenuDestination.updateOrder:
        return UpdateOrderSample(secrets: secrets, onBack: pop);
      case MenuDestination.chv:
        return CardHolderVerificationSample(secrets: secrets, onBack: pop);
      case MenuDestination.playground:
        return PlaygroundScreen(secrets: secrets, onBack: pop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    if (_loadError != null) {
      return ColoredBox(
        color: colors.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _loadError!,
              style: TextStyle(color: colors.error),
            ),
          ),
        ),
      );
    }
    if (_secrets == null) {
      return ColoredBox(
        color: colors.bg,
        child: Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
      );
    }
    return MenuScreen(secrets: _secrets!, onOpen: _open);
  }
}
