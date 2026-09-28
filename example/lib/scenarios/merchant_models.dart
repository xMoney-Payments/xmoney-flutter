import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../sample_helpers.dart';
import '../theme/example_colors.dart';

enum MerchantCatalogStyle { menu, plans, grid }

enum MerchantPaySurface { sheet, embedded }

class MerchantProduct {
  const MerchantProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.blurb,
    required this.priceMinor,
    required this.imageAsset,
  });

  final String id;
  final String name;
  final String category;
  final String blurb;
  final int priceMinor;
  final String imageAsset;
}

class MerchantLine {
  const MerchantLine({required this.product, required this.quantity});

  final MerchantProduct product;
  final int quantity;
}

class MerchantBrand {
  const MerchantBrand({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emptyHint,
    required this.catalogStyle,
    required this.paySurface,
    required this.products,
    required this.appearance,
    required this.accent,
    required this.onAccent,
    this.accentText,
  });

  final String id;
  final String name;
  final String tagline;
  final String emptyHint;
  final MerchantCatalogStyle catalogStyle;
  final MerchantPaySurface paySurface;
  final List<MerchantProduct> products;
  final AppearanceConfig appearance;
  final Color accent;
  final Color onAccent;
  final Color? accentText;
}

int lineTotal(MerchantLine line) => line.product.priceMinor * line.quantity;

int itemCount(List<MerchantLine> lines) =>
    lines.fold(0, (sum, line) => sum + line.quantity);

int subtotalMinor(List<MerchantLine> lines) =>
    lines.fold(0, (sum, line) => sum + lineTotal(line));

List<MerchantLine> toLines(
  List<MerchantProduct> products,
  Map<String, int> quantities,
) {
  return products
      .map((product) {
        final quantity = quantities[product.id] ?? 0;
        if (quantity <= 0) return null;
        return MerchantLine(product: product, quantity: quantity);
      })
      .whereType<MerchantLine>()
      .toList();
}

String _img(String file) => 'assets/products/$file';

MerchantProduct _p({
  required String id,
  required String name,
  required String category,
  required String blurb,
  required int priceMinor,
  required String image,
}) {
  return MerchantProduct(
    id: id,
    name: name,
    category: category,
    blurb: blurb,
    priceMinor: priceMinor,
    imageAsset: _img(image),
  );
}

const hearthTerracotta = Color(0xFFC45C26);

final lumenBrand = MerchantBrand(
  id: 'lumen',
  name: 'Lumen',
  tagline: 'Modern essentials. Pay with Payment Sheet.',
  emptyHint: 'Add a few Lumen pieces from the store, then pay with Payment Sheet.',
  catalogStyle: MerchantCatalogStyle.grid,
  paySurface: MerchantPaySurface.sheet,
  appearance: exampleAppearance(),
  accent: ExampleColors.purple,
  onAccent: Colors.white,
  products: [
    _p(id: 'earbuds', name: 'Aura Earbuds', category: 'Audio', blurb: 'Spatial audio, 32-hour case', priceMinor: 12900, image: 'product_earbuds.png'),
    _p(id: 'lamp', name: 'Arc Desk Lamp', category: 'Lighting', blurb: 'Dimmable, brushed aluminum', priceMinor: 8900, image: 'product_lamp.png'),
    _p(id: 'pour-over', name: 'Stone Pour-Over', category: 'Kitchen', blurb: 'Matte ceramic, 600 ml', priceMinor: 4200, image: 'product_pourover.png'),
    _p(id: 'throw', name: 'Merino Throw', category: 'Home', blurb: 'Undyed wool, 140 × 200', priceMinor: 7500, image: 'product_throw.png'),
    _p(id: 'notebooks', name: 'Oak Notebooks', category: 'Stationery', blurb: 'Set of three, linen cover', priceMinor: 2400, image: 'product_notebooks.png'),
    _p(id: 'weekender', name: 'Canvas Weekender', category: 'Travel', blurb: 'Vegetable-tanned straps', priceMinor: 11800, image: 'product_weekender.png'),
    _p(id: 'diffuser', name: 'Ceramic Diffuser', category: 'Wellness', blurb: 'Ultrasonic, 4-hour timer', priceMinor: 5400, image: 'product_diffuser.png'),
    _p(id: 'bottle', name: 'Steel Bottle', category: 'Everyday', blurb: 'Double-wall, 750 ml', priceMinor: 3200, image: 'product_bottle.png'),
  ],
);

final hearthBrand = MerchantBrand(
  id: 'hearth',
  name: 'Hearth',
  tagline: 'Neighbourhood café. Pay in-page with Embedded Element.',
  emptyHint: 'Add a coffee or a plate from the board, then check out in this screen.',
  catalogStyle: MerchantCatalogStyle.menu,
  paySurface: MerchantPaySurface.embedded,
  appearance: exampleAppearance(primary: '#C45C26'),
  accent: hearthTerracotta,
  onAccent: Colors.white,
  products: [
    _p(id: 'espresso', name: 'House Espresso', category: 'Drinks', blurb: 'Single origin, 18g', priceMinor: 350, image: 'product_espresso.png'),
    _p(id: 'cortado', name: 'Oat Cortado', category: 'Drinks', blurb: 'Equal parts, steamed oat', priceMinor: 420, image: 'product_cortado.png'),
    _p(id: 'cold-brew', name: 'Cold Brew', category: 'Drinks', blurb: '16-hour steep, served over ice', priceMinor: 480, image: 'product_coldbrew.png'),
    _p(id: 'grain-bowl', name: 'Seasonal Grain Bowl', category: 'Kitchen', blurb: 'Farro, greens, citrus tahini', priceMinor: 1400, image: 'product_grainbowl.png'),
    _p(id: 'tartine', name: 'Smoked Salmon Tartine', category: 'Kitchen', blurb: 'Rye, crème fraîche, dill', priceMinor: 1250, image: 'product_tartine.png'),
    _p(id: 'croissant', name: 'Butter Croissant', category: 'Bakery', blurb: 'Laminated overnight', priceMinor: 380, image: 'product_croissant.png'),
    _p(id: 'morning-bun', name: 'Almond Morning Bun', category: 'Bakery', blurb: 'Orange blossom, toasted nuts', priceMinor: 440, image: 'product_morningbun.png'),
    _p(id: 'loaf', name: 'Citrus Loaf', category: 'Bakery', blurb: 'Olive oil, slice', priceMinor: 410, image: 'product_loaf.png'),
  ],
);

final pulseBrand = MerchantBrand(
  id: 'pulse',
  name: 'Pulse',
  tagline: 'Studio memberships and classes. Embedded checkout.',
  emptyHint: 'Choose a pack or a drop-in, then pay with the form on the next screen.',
  catalogStyle: MerchantCatalogStyle.plans,
  paySurface: MerchantPaySurface.embedded,
  appearance: exampleAppearance(
    primary: '#3C5708',
    primaryDark: '#DCFC97',
    buttonBackground: '#DCFC97',
    buttonText: '#3C5708',
  ),
  accent: ExampleColors.lime,
  onAccent: ExampleColors.limeDark,
  accentText: ExampleColors.limeDark,
  products: [
    _p(id: 'unlimited', name: 'Monthly Unlimited', category: 'Membership', blurb: 'All classes, guest pass once a month', priceMinor: 7900, image: 'product_pulse_unlimited.png'),
    _p(id: 'pack-5', name: '5-Class Pack', category: 'Packs', blurb: 'Use within 8 weeks', priceMinor: 9500, image: 'product_pulse_pack.png'),
    _p(id: 'drop-in', name: 'Drop-in Class', category: 'Classes', blurb: 'Any public session today', priceMinor: 2200, image: 'product_pulse_dropin.png'),
    _p(id: 'reformer', name: 'Reformer Intro', category: 'Classes', blurb: '50 minutes, small group', priceMinor: 4500, image: 'product_pulse_reformer.png'),
    _p(id: 'recovery', name: 'Recovery Session', category: 'Wellness', blurb: 'Stretch + breathwork', priceMinor: 3800, image: 'product_pulse_recovery.png'),
    _p(id: 'swim', name: 'Lane Swim Pass', category: 'Wellness', blurb: 'Morning lanes, 10 entries', priceMinor: 6000, image: 'product_pulse_swim.png'),
    _p(id: 'heart', name: 'Heart-Rate Lab', category: 'Classes', blurb: 'Guided intervals, 40 minutes', priceMinor: 2800, image: 'product_pulse_heart.png'),
  ],
);

final merchantBrands = {
  'lumen': lumenBrand,
  'hearth': hearthBrand,
  'pulse': pulseBrand,
};
