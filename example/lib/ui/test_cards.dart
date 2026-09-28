import 'package:flutter/material.dart';

import '../theme/example_theme.dart';
import 'example_components.dart';

class DemoTestCard {
  const DemoTestCard({
    required this.pan,
    required this.expiry,
    required this.cvv,
    required this.threeDS,
    required this.success,
    required this.status,
  });

  final String pan;
  final String expiry;
  final String cvv;
  final String threeDS;
  final bool success;
  final String status;
}

const demoTestCards = [
  DemoTestCard(
    pan: '5555 5555 5555 5599',
    expiry: '12/34',
    cvv: '123',
    threeDS: '00000',
    success: true,
    status: 'Success (3DS2)',
  ),
  DemoTestCard(
    pan: '4111 1111 1111 1111',
    expiry: '12/26',
    cvv: '123',
    threeDS: '00000',
    success: true,
    status: 'Success (3DS2 Frictionless)',
  ),
  DemoTestCard(
    pan: '5168 4948 9505 5780',
    expiry: '12/26',
    cvv: '123',
    threeDS: '00000',
    success: false,
    status: 'Fail (3DS2 Frictionless)',
  ),
  DemoTestCard(
    pan: '4000 0011 1111 1118',
    expiry: '12/30',
    cvv: '123',
    threeDS: '00000',
    success: true,
    status: 'Success (3DS2 Attempt)',
  ),
];

class TestCardsAction extends StatelessWidget {
  const TestCardsAction({this.nameCheckHint = false, super.key});

  final bool nameCheckHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return TextButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TestCardsSheet(nameCheckHint: nameCheckHint),
        ),
      ),
      child: Text(
        'Test cards',
        style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class TestCardsSheet extends StatelessWidget {
  const TestCardsSheet({this.nameCheckHint = false, super.key});

  final bool nameCheckHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Material(
      color: colors.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colors.text),
                  ),
                  Expanded(
                    child: Text(
                      'Test cards',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (nameCheckHint)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ExampleStatusChip(
                  text:
                      'For name check demos use first name Test and last name User.',
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final card in demoTestCards) ...[
                    _TestCardTile(card: card),
                    const SizedBox(height: 12),
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

class _TestCardTile extends StatelessWidget {
  const _TestCardTile({required this.card});

  final DemoTestCard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return ExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.status,
                  style: TextStyle(
                    color: card.success ? colors.success : colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => copyToClipboard(context, card.pan.replaceAll(' ', '')),
                icon: Icon(Icons.copy, color: colors.muted, size: 20),
              ),
            ],
          ),
          _Row(label: 'PAN', value: card.pan),
          _Row(label: 'Expiry', value: card.expiry),
          _Row(label: 'CVV', value: card.cvv),
          _Row(label: '3DS', value: card.threeDS),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(color: colors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
