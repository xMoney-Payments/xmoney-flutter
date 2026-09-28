import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xmoney_example/backend/demo_checkout_backend.dart';
import 'package:xmoney_example/menu_screen.dart';
import 'package:xmoney_example/theme/example_theme.dart';

void main() {
  testWidgets('menu lists integration samples', (WidgetTester tester) async {
    final secrets = DemoSecrets(
      publicKey: 'pk_test',
      apiKey: 'sk_test',
      apiBase: 'https://demo.example',
      currency: 'EUR',
      description: 'Demo',
    );

    await tester.pumpWidget(
      ExampleThemeProvider(
        child: MaterialApp(
          home: MenuScreen(secrets: secrets, onOpen: (_) {}),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable).first;
    const labels = [
      'Payment Sheet',
      'Embedded Payment Element',
      'Lumen shop',
      'Merchant Pay button',
      'Playground',
    ];

    for (final label in labels) {
      await tester.scrollUntilVisible(
        find.text(label),
        500,
        scrollable: scrollable,
      );
      expect(find.text(label), findsOneWidget);
    }
  });
}
