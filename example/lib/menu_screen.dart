import 'dart:io';

import 'package:flutter/material.dart';

import 'backend/demo_checkout_backend.dart';
import 'theme/example_theme.dart';
import 'ui/example_components.dart';

enum MenuDestination {
  sheet,
  element,
  wallet,
  lumen,
  hearth,
  pulse,
  merchantPay,
  updateOrder,
  chv,
  playground,
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({required this.secrets, required this.onOpen, super.key});

  final DemoSecrets secrets;
  final ValueChanged<MenuDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    const sections = [
      ('Integrations', 1.0),
      ('Example app', 1.0),
      ('Advanced', 1.0),
      ('Internal', 0.7),
    ];

    final items = _menuItems(secrets);

    return Material(
      color: colors.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExampleTopBar(
              title: 'Examples',
              subtitle:
                  'Copy-paste samples, merchant scenarios, and an internal playground.',
              showWordmark: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  for (final (section, opacity) in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Text(
                        section.toUpperCase(),
                        style: TextStyle(
                          color: colors.muted.withValues(alpha: opacity),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    for (final entry in items.where((i) => i.section == section))
                      _MenuRow(item: entry, onTap: () => onOpen(entry.destination)),
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

class _MenuItem {
  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.section,
    required this.destination,
    this.thumbnail,
  });

  final String title;
  final String subtitle;
  final String section;
  final MenuDestination destination;
  final String? thumbnail;
}

List<_MenuItem> _menuItems(DemoSecrets secrets) {
  final walletTitle = Platform.isIOS ? 'Apple Pay' : 'Google Pay';
  final walletSubtitle = 'Standalone wallet button';
  final elementSubtitle = Platform.isIOS
      ? 'Card, saved cards, and Apple Pay in your layout'
      : 'Card, saved cards, and Google Pay in your layout';

  return [
    const _MenuItem(
      title: 'Payment Sheet',
      subtitle: 'Drop-in checkout sheet — copy-paste starting point',
      section: 'Integrations',
      destination: MenuDestination.sheet,
    ),
    _MenuItem(
      title: 'Embedded Payment Element',
      subtitle: elementSubtitle,
      section: 'Integrations',
      destination: MenuDestination.element,
    ),
    _MenuItem(
      title: walletTitle,
      subtitle: walletSubtitle,
      section: 'Integrations',
      destination: MenuDestination.wallet,
    ),
    const _MenuItem(
      title: 'Lumen shop',
      subtitle: 'Lifestyle store — catalog, cart, Payment Sheet',
      section: 'Example app',
      destination: MenuDestination.lumen,
      thumbnail: 'assets/products/product_earbuds.png',
    ),
    const _MenuItem(
      title: 'Hearth Café',
      subtitle: 'Food menu — cart and Embedded checkout',
      section: 'Example app',
      destination: MenuDestination.hearth,
      thumbnail: 'assets/products/product_espresso.png',
    ),
    const _MenuItem(
      title: 'Pulse Studio',
      subtitle: 'Memberships and classes — Embedded checkout',
      section: 'Example app',
      destination: MenuDestination.pulse,
      thumbnail: 'assets/products/product_pulse_unlimited.png',
    ),
    const _MenuItem(
      title: 'Merchant Pay button',
      subtitle: 'Embedded form, your CTA via confirm()',
      section: 'Advanced',
      destination: MenuDestination.merchantPay,
    ),
    const _MenuItem(
      title: 'Update order',
      subtitle: 'updateOrder() a new PaymentIntent on a mounted Element',
      section: 'Advanced',
      destination: MenuDestination.updateOrder,
    ),
    const _MenuItem(
      title: 'Card holder verification',
      subtitle: 'Pre-pay name check via CardHolderVerification',
      section: 'Advanced',
      destination: MenuDestination.chv,
    ),
    const _MenuItem(
      title: 'Playground',
      subtitle: 'Every PaymentConfig option — SDK development',
      section: 'Internal',
      destination: MenuDestination.playground,
    ),
  ];
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final _MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  if (item.thumbnail != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        item.thumbnail!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: TextStyle(color: colors.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.muted, size: 20),
                ],
              ),
            ),
            Divider(height: 1, color: colors.hairline, indent: 20),
          ],
        ),
      ),
    );
  }
}
