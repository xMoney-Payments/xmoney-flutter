import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xmoney/xmoney.dart';

import '../backend/demo_checkout_backend.dart';
import '../sample_helpers.dart';
import '../theme/example_colors.dart';
import '../theme/example_theme.dart';
import '../ui/example_components.dart';
import 'merchant_models.dart';

enum _StoreRoute { catalog, cart, checkout, receipt }

class MerchantStore extends StatelessWidget {
  const MerchantStore({
    required this.brand,
    required this.secrets,
    required this.onLeave,
    super.key,
  });

  final MerchantBrand brand;
  final DemoSecrets secrets;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ExampleThemeProvider(
      accent: brand.accent,
      onAccent: brand.onAccent,
      accentText: brand.accentText,
      child: _MerchantStoreInner(
        brand: brand,
        secrets: secrets,
        onLeave: onLeave,
      ),
    );
  }
}

class _MerchantStoreInner extends StatefulWidget {
  const _MerchantStoreInner({
    required this.brand,
    required this.secrets,
    required this.onLeave,
  });

  final MerchantBrand brand;
  final DemoSecrets secrets;
  final VoidCallback onLeave;

  @override
  State<_MerchantStoreInner> createState() => _MerchantStoreInnerState();
}

class _MerchantStoreInnerState extends State<_MerchantStoreInner> {
  _StoreRoute _route = _StoreRoute.catalog;
  PaymentResult? _receiptResult;
  final _quantities = <String, int>{};

  List<MerchantLine> get _lines => toLines(widget.brand.products, _quantities);

  void _setQty(String id, int qty) {
    setState(() {
      if (qty <= 0) {
        _quantities.remove(id);
      } else {
        _quantities[id] = qty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: switch (_route) {
          _StoreRoute.catalog => _CatalogView(
              brand: widget.brand,
              lines: _lines,
              quantityOf: (id) => _quantities[id] ?? 0,
              onBack: widget.onLeave,
              onAdd: (id) => _setQty(id, (_quantities[id] ?? 0) + 1),
              onOpenCart: () => setState(() => _route = _StoreRoute.cart),
            ),
          _StoreRoute.cart => _CartView(
              brand: widget.brand,
              lines: _lines,
              onBack: () => setState(() => _route = _StoreRoute.catalog),
              onQty: _setQty,
              onCheckout: () => setState(() => _route = _StoreRoute.checkout),
            ),
          _StoreRoute.checkout =>
            widget.brand.paySurface == MerchantPaySurface.sheet
                ? _SheetCheckout(
                    brand: widget.brand,
                    secrets: widget.secrets,
                    lines: _lines,
                    onBack: () => setState(() => _route = _StoreRoute.cart),
                    onFinished: (result) => setState(() {
                      _receiptResult = result;
                      _route = _StoreRoute.receipt;
                    }),
                  )
                : _EmbeddedCheckout(
                    brand: widget.brand,
                    secrets: widget.secrets,
                    lines: _lines,
                    onQty: _setQty,
                    onBack: () => setState(() => _route = _StoreRoute.cart),
                    onFinished: (result) => setState(() {
                      _receiptResult = result;
                      _route = _StoreRoute.receipt;
                    }),
                  ),
          _StoreRoute.receipt => _ReceiptView(
              brand: widget.brand,
              lines: _lines,
              result: _receiptResult!,
              onDone: () => setState(() {
                _quantities.clear();
                _receiptResult = null;
                _route = _StoreRoute.catalog;
              }),
              onRetry: () => setState(() {
                _receiptResult = null;
                _route = _StoreRoute.checkout;
              }),
              onBackToCart: () => setState(() {
                _receiptResult = null;
                _route = _StoreRoute.cart;
              }),
            ),
        },
      ),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({
    required this.brand,
    required this.lines,
    required this.quantityOf,
    required this.onBack,
    required this.onAdd,
    required this.onOpenCart,
  });

  final MerchantBrand brand;
  final List<MerchantLine> lines;
  final int Function(String id) quantityOf;
  final VoidCallback onBack;
  final ValueChanged<String> onAdd;
  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    final count = itemCount(lines);
    return Column(
      children: [
        ExampleTopBar(
          title: brand.name,
          subtitle: brand.tagline,
          onBack: onBack,
          showThemeToggle: false,
          showWordmark: true,
          actions: _CartBadge(count: count, onPress: onOpenCart),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (brand.catalogStyle == MerchantCatalogStyle.grid)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final product in brand.products)
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 52) / 2,
                        child: _ProductCard(
                          product: product,
                          quantity: quantityOf(product.id),
                          onAdd: () => onAdd(product.id),
                          compact: true,
                        ),
                      ),
                  ],
                )
              else
                for (final entry in _grouped(brand.products).entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(
                        color: context.exampleColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  for (final product in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProductCard(
                        product: product,
                        quantity: quantityOf(product.id),
                        onAdd: () => onAdd(product.id),
                      ),
                    ),
                ],
            ],
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ExampleButton(
              label:
                  'Cart · $count ${count == 1 ? 'item' : 'items'} · ${formatMoney(subtotalMinor(lines))}',
              onPressed: onOpenCart,
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    this.compact = false,
  });

  final MerchantProduct product;
  final int quantity;
  final VoidCallback onAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final photo = SizedBox(
      width: compact ? double.infinity : 72,
      height: compact ? 120 : 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ExampleRadii.inner),
        child: Image.asset(
          product.imageAsset,
          fit: BoxFit.cover,
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          product.blurb,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                formatMoney(product.priceMinor),
                style: TextStyle(
                  color: colors.accentText,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            ExampleAddChip(quantity: quantity, onPressed: onAdd),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(ExampleRadii.card),
        border: Border.all(color: colors.hairline),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                photo,
                const SizedBox(height: 10),
                details,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                photo,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count, required this.onPress});

  final int count;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return IconButton(
      onPressed: onPress,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.shopping_bag_outlined, color: colors.text),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: TextStyle(
                    color: colors.onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartView extends StatelessWidget {
  const _CartView({
    required this.brand,
    required this.lines,
    required this.onBack,
    required this.onQty,
    required this.onCheckout,
  });

  final MerchantBrand brand;
  final List<MerchantLine> lines;
  final VoidCallback onBack;
  final void Function(String id, int qty) onQty;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final empty = lines.isEmpty;
    final count = itemCount(lines);
    return Column(
      children: [
        ExampleTopBar(
          title: 'Cart',
          subtitle: empty ? 'No items yet.' : '$count items',
          onBack: onBack,
          showThemeToggle: false,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (empty)
                ExampleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your bag is empty',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        brand.emptyHint,
                        style: TextStyle(color: colors.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ExampleButton(
                        label: 'Continue shopping',
                        variant: ExampleButtonVariant.secondary,
                        onPressed: onBack,
                      ),
                    ],
                  ),
                )
              else ...[
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CartLine(line: line, onQty: onQty),
                  ),
                _Totals(lines: lines),
              ],
            ],
          ),
        ),
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: ExampleButton(
              label: 'Checkout · ${formatMoney(subtotalMinor(lines))}',
              onPressed: onCheckout,
            ),
          ),
      ],
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.line, required this.onQty});

  final MerchantLine line;
  final void Function(String id, int qty) onQty;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final id = line.product.id;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ExampleRadii.inner),
            child: Image.asset(line.product.imageAsset, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.product.name,
                  style: TextStyle(
                      color: colors.text, fontWeight: FontWeight.w600)),
              Text(formatMoney(line.product.priceMinor),
                  style: TextStyle(color: colors.muted)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onPressed: () => onQty(id, line.quantity - 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${line.quantity}',
                        style: TextStyle(
                            color: colors.text, fontWeight: FontWeight.w600)),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onPressed: () => onQty(id, line.quantity + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(formatMoney(lineTotal(line)),
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 18, color: colors.text),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.lines});

  final List<MerchantLine> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final total = formatMoney(subtotalMinor(lines));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subtotal', style: TextStyle(color: colors.muted)),
            Text(total, style: TextStyle(color: colors.text)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total',
                style:
                    TextStyle(color: colors.text, fontWeight: FontWeight.w700)),
            Text(total,
                style:
                    TextStyle(color: colors.text, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _SheetCheckout extends StatefulWidget {
  const _SheetCheckout({
    required this.brand,
    required this.secrets,
    required this.lines,
    required this.onBack,
    required this.onFinished,
  });

  final MerchantBrand brand;
  final DemoSecrets secrets;
  final List<MerchantLine> lines;
  final VoidCallback onBack;
  final ValueChanged<PaymentResult> onFinished;

  @override
  State<_SheetCheckout> createState() => _SheetCheckoutState();
}

class _SheetCheckoutState extends State<_SheetCheckout> {
  final _sheet = PaymentSheetController();
  PaymentIntent? _heldIntent;
  String? _error;
  var _loading = false;
  var _revealed = false;

  String get _description {
    final count = itemCount(widget.lines);
    return '${widget.brand.name} · $count ${count == 1 ? 'item' : 'items'}';
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (_heldIntent != null) {
      setState(() {
        _revealed = true;
        _error = null;
      });
      return;
    }
    try {
      final intent =
          await DemoCheckoutBackend(widget.secrets).createPaymentIntent(
        amountMinor: subtotalMinor(widget.lines),
        description: _description,
      );
      if (!mounted) return;
      setState(() {
        _heldIntent = intent;
        _revealed = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _pay() async {
    final intent = _heldIntent;
    if (intent == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final dark = context.exampleDark;
    try {
      await _sheet.init(defaultPaymentConfig(
        widget.secrets,
        dark: dark,
        appearance: widget.brand.appearance,
      ));
      final result = await _sheet.present(intent);
      if (!mounted) return;
      setState(() => _loading = false);
      final consumed = orderConsumed(
        result,
        result is! PaymentResultCanceled,
      );
      if (consumed) {
        _heldIntent = null;
        widget.onFinished(result);
      }
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
    final total = formatMoney(subtotalMinor(widget.lines));
    return Column(
      children: [
        ExampleTopBar(
          title: 'Checkout',
          subtitle: _description,
          onBack: widget.onBack,
          showThemeToggle: false,
          showTestCards: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              if (_revealed)
                ExampleCard(
                  child: Column(
                    children: [
                      for (final line in widget.lines) _SummaryLine(line: line),
                      _Totals(lines: widget.lines),
                    ],
                  ),
                )
              else if (_error == null)
                const ExampleCheckoutSkeleton(showOrder: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_revealed) ...[
                if (_error != null) ...[
                  ExampleStatusChip(
                      text: _error!, kind: ExampleStatusKind.error),
                  const SizedBox(height: 12),
                ],
                ExampleButton(
                  label: 'Pay · $total',
                  loading: _loading,
                  onPressed: _pay,
                ),
              ] else if (_error != null) ...[
                ExampleStatusChip(text: _error!, kind: ExampleStatusKind.error),
                const SizedBox(height: 12),
                ExampleButton(
                  label: 'Try again',
                  variant: ExampleButtonVariant.secondary,
                  onPressed: () {
                    setState(() => _error = null);
                    _prepare();
                  },
                ),
              ] else
                const ExampleCheckoutSkeleton(
                  showOrder: false,
                  showPayButton: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmbeddedCheckout extends StatefulWidget {
  const _EmbeddedCheckout({
    required this.brand,
    required this.secrets,
    required this.lines,
    required this.onQty,
    required this.onBack,
    required this.onFinished,
  });

  final MerchantBrand brand;
  final DemoSecrets secrets;
  final List<MerchantLine> lines;
  final void Function(String id, int qty) onQty;
  final VoidCallback onBack;
  final ValueChanged<PaymentResult> onFinished;

  @override
  State<_EmbeddedCheckout> createState() => _EmbeddedCheckoutState();
}

class _EmbeddedCheckoutState extends State<_EmbeddedCheckout> {
  final _controller = PaymentElementController();
  PaymentIntent? _intent;
  String? _error;
  var _ready = false;
  Timer? _debounce;

  int get _total => subtotalMinor(widget.lines);

  String get _description {
    final count = itemCount(widget.lines);
    return '${widget.brand.name} · $count ${count == 1 ? 'item' : 'items'}';
  }

  @override
  void initState() {
    super.initState();
    _scheduleOrder(initial: true);
  }

  @override
  void didUpdateWidget(covariant _EmbeddedCheckout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_total != subtotalMinor(oldWidget.lines)) {
      _scheduleOrder(initial: false);
    }
  }

  void _scheduleOrder({required bool initial}) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: initial ? 0 : 300), () async {
      final backend = DemoCheckoutBackend(widget.secrets);
      try {
        final next = await backend.createPaymentIntent(
          amountMinor: _total,
          description: _description,
        );
        if (!mounted) return;
        if (_intent != null) {
          await _controller.updateOrder(next);
        }
        setState(() {
          _error = null;
          _intent = next;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.exampleDark;
    final intent = _intent;
    return Column(
      children: [
        ExampleTopBar(
          title: 'Checkout',
          subtitle: _description,
          onBack: widget.onBack,
          showThemeToggle: false,
          showTestCards: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              if (_ready)
                ExampleCard(
                  child: Column(
                    children: [
                      for (final line in widget.lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CartLine(
                            line: line,
                            onQty: widget.onQty,
                          ),
                        ),
                      _Totals(lines: widget.lines),
                    ],
                  ),
                )
              else if (_error == null)
                const ExampleCheckoutSkeleton(showOrder: true),
              const SizedBox(height: 16),
              if (intent != null)
                MerchantReadyGate(
                  ready: _ready,
                  message: 'Preparing checkout…',
                  placeholder: const ExampleCheckoutSkeleton(
                    showOrder: false,
                    showForm: true,
                  ),
                  child: PaymentElement(
                    controller: _controller,
                    configuration: defaultPaymentConfig(
                      widget.secrets,
                      dark: dark,
                      appearance: widget.brand.appearance,
                    ),
                    intent: intent,
                    onEvent: (event) {
                      // Availability is emitted while the native form is still
                      // loading. Reveal only after the SDK reports ready.
                      if (event is PaymentElementReadyEvent) {
                        setState(() => _ready = true);
                      }
                    },
                    onResult: (result) {
                      final bindError = bindFailureMessage(result);
                      if (bindError != null) {
                        setState(() {
                          _error = bindError;
                          _ready = true;
                        });
                      }
                      if (orderConsumed(
                        result,
                        result is! PaymentResultCanceled,
                      )) {
                        widget.onFinished(result);
                      }
                    },
                  ),
                )
              else if (_error == null)
                const ExampleCheckoutSkeleton(showOrder: false, showForm: true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ExampleStatusChip(text: _error!, kind: ExampleStatusKind.error),
                const SizedBox(height: 12),
                ExampleButton(
                  label: 'Try again',
                  variant: ExampleButtonVariant.secondary,
                  onPressed: () {
                    setState(() => _error = null);
                    _scheduleOrder(initial: true);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptView extends StatelessWidget {
  const _ReceiptView({
    required this.brand,
    required this.lines,
    required this.result,
    required this.onDone,
    required this.onRetry,
    required this.onBackToCart,
  });

  final MerchantBrand brand;
  final List<MerchantLine> lines;
  final PaymentResult result;
  final VoidCallback onDone;
  final VoidCallback onRetry;
  final VoidCallback onBackToCart;

  @override
  Widget build(BuildContext context) {
    final ok = result is PaymentResultComplete;
    return Column(
      children: [
        ExampleTopBar(
          title: ok ? 'Thank you' : 'Payment',
          subtitle: brand.name,
          onBack: onBackToCart,
          showThemeToggle: false,
          showWordmark: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ExampleResultPanel(result: result),
              const SizedBox(height: 12),
              ExampleCard(
                child: Column(
                  children: [
                    for (final line in lines) _SummaryLine(line: line),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (ok)
                ExampleButton(label: 'Done', onPressed: onDone)
              else ...[
                ExampleButton(label: 'Try again', onPressed: onRetry),
                const SizedBox(height: 12),
                ExampleButton(
                  label: 'Back to cart',
                  variant: ExampleButtonVariant.secondary,
                  onPressed: onBackToCart,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Map<String, List<MerchantProduct>> _grouped(List<MerchantProduct> products) {
  final grouped = <String, List<MerchantProduct>>{};
  for (final product in products) {
    grouped.putIfAbsent(product.category, () => []).add(product);
  }
  return grouped;
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line});

  final MerchantLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${line.product.name} × ${line.quantity}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(lineTotal(line)),
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
