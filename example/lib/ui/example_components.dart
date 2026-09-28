import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmoney/xmoney.dart';
import '../theme/example_colors.dart';
import '../theme/example_theme.dart';
import 'example_wordmark.dart';
import 'test_cards.dart';

class ExampleCard extends StatelessWidget {
  const ExampleCard({required this.child, this.padding = 20, super.key});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(ExampleRadii.card),
        border: Border.all(color: colors.hairline),
      ),
      child: child,
    );
  }
}

class ExampleButton extends StatelessWidget {
  const ExampleButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.variant = ExampleButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;
  final ExampleButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final primary = variant == ExampleButtonVariant.primary;
    final disabled = !enabled || loading;
    final content = primary ? colors.onAccent : colors.text;
    final showShadow = primary && !disabled;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ExampleRadii.pill),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.28),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.38),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Material(
          color: primary ? colors.accent : colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ExampleRadii.pill),
            side:
                primary ? BorderSide.none : BorderSide(color: colors.hairline),
          ),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(ExampleRadii.pill),
            child: SizedBox(
              height: 52,
              child: Center(
                child: loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: content,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Processing…',
                            style: TextStyle(
                              color: content,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          color: content,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ExampleButtonVariant { primary, secondary }

class ExampleStatusChip extends StatelessWidget {
  const ExampleStatusChip({
    required this.text,
    this.kind = ExampleStatusKind.neutral,
    super.key,
  });

  final String text;
  final ExampleStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final container = switch (kind) {
      ExampleStatusKind.error => colors.dangerSoft,
      ExampleStatusKind.success => colors.successSoft,
      ExampleStatusKind.neutral => colors.elevated,
    };
    final tint = switch (kind) {
      ExampleStatusKind.error => colors.error,
      ExampleStatusKind.success => colors.success,
      ExampleStatusKind.neutral => colors.muted,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(ExampleRadii.inner),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: tint, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

enum ExampleStatusKind { neutral, error, success }

class SampleOrderCard extends StatelessWidget {
  const SampleOrderCard({this.title, this.amount, super.key});

  final String? title;
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return ExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER',
            style: TextStyle(
              color: colors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title ?? 'Checkout item',
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (amount != null) ...[
            const SizedBox(height: 4),
            Text(
              amount!,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExampleLoader extends StatelessWidget {
  const ExampleLoader({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: ExampleColors.purple,
            ),
          ),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: colors.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

class ExampleAddChip extends StatelessWidget {
  const ExampleAddChip({
    required this.quantity,
    required this.onPressed,
    super.key,
  });

  final int quantity;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final filled = quantity > 0;
    return Material(
      color: filled ? colors.accent.withValues(alpha: 0.12) : colors.accent,
      borderRadius: BorderRadius.circular(ExampleRadii.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ExampleRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            filled ? '$quantity' : 'Add',
            style: TextStyle(
              color: filled ? colors.accentText : colors.onAccent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class MerchantReadyGate extends StatefulWidget {
  const MerchantReadyGate({
    required this.ready,
    required this.message,
    required this.child,
    this.placeholder,
    this.minHeight = 160,
    super.key,
  });

  final bool ready;
  final String message;
  final Widget child;
  final Widget? placeholder;

  /// Layout height offered to the native view while it is clipped offstage.
  final double minHeight;

  @override
  State<MerchantReadyGate> createState() => _MerchantReadyGateState();
}

class _MerchantReadyGateState extends State<MerchantReadyGate> {
  var _hasBound = false;

  @override
  void didUpdateWidget(covariant MerchantReadyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready) _hasBound = true;
  }

  @override
  void initState() {
    super.initState();
    _hasBound = widget.ready;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.placeholder ?? ExampleLoader(message: widget.message);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasBound)
          widget.child
        else
          SizedBox(
            width: double.infinity,
            height: 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: widget.minHeight,
                maxHeight: widget.minHeight < 4000 ? 4000 : widget.minHeight,
                child: IgnorePointer(child: widget.child),
              ),
            ),
          ),
        if (!_hasBound) placeholder,
      ],
    );
  }
}

class ExampleCheckoutSkeleton extends StatefulWidget {
  const ExampleCheckoutSkeleton({
    this.showOrder = true,
    this.showForm = false,
    this.showPayButton = false,
    super.key,
  });

  final bool showOrder;
  final bool showForm;
  final bool showPayButton;

  @override
  State<ExampleCheckoutSkeleton> createState() =>
      _ExampleCheckoutSkeletonState();
}

class _ExampleCheckoutSkeletonState extends State<ExampleCheckoutSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _alpha = Tween<double>(begin: 0.08, end: 0.16)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.fastOutSlowIn));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Semantics(
      container: true,
      label: 'Loading checkout',
      child: AnimatedBuilder(
        animation: _alpha,
        builder: (context, _) {
          final bone = colors.text.withValues(alpha: _alpha.value);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(16, [
              if (widget.showOrder) _orderBones(colors, bone),
              if (widget.showForm) _formBones(colors, bone),
              if (widget.showPayButton) _payBone(bone),
            ]),
          );
        },
      ),
    );
  }

  Widget _orderBones(ExamplePalette colors, Color bone) {
    return ExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced(12, [
          Align(
            alignment: Alignment.centerLeft,
            child: _bone(bone, height: 12, width: 56),
          ),
          for (var i = 0; i < 3; i++)
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: _bone(bone, height: 16),
                  ),
                ),
                _bone(bone, height: 16, width: 64),
              ],
            ),
          Divider(height: 1, thickness: 1, color: colors.hairline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bone(bone, height: 14, width: 72),
              _bone(bone, height: 14, width: 48),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bone(bone, height: 18, width: 48),
              _bone(bone, height: 18, width: 72),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _formBones(ExamplePalette colors, Color bone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced(12, [
        _bone(bone, height: 56, radius: ExampleRadii.inner),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Container(height: 1, color: colors.hairline)),
              const SizedBox(width: 14),
              _bone(bone, height: 10, width: 24),
              const SizedBox(width: 14),
              Expanded(child: Container(height: 1, color: colors.hairline)),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ExampleRadii.card),
            border: Border.all(color: colors.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ExampleRadii.card),
            child: Column(
              children: [
                _bone(bone, height: 52, radius: 0),
                Divider(height: 1, thickness: 1, color: colors.hairline),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(child: _bone(bone, height: 52, radius: 0)),
                      Container(width: 1, height: 52, color: colors.hairline),
                      Expanded(child: _bone(bone, height: 52, radius: 0)),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: colors.hairline),
                _bone(bone, height: 52, radius: 0),
              ],
            ),
          ),
        ),
        _bone(bone, height: 52, radius: ExampleRadii.pill),
      ]),
    );
  }

  Widget _payBone(Color bone) {
    return _bone(bone, height: 52, radius: ExampleRadii.pill);
  }

  Widget _bone(
    Color color, {
    required double height,
    double? width,
    double radius = 8,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  List<Widget> _spaced(double gap, List<Widget> children) {
    return [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ];
  }
}

class ExampleThemeToggle extends StatelessWidget {
  const ExampleThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final dark = context.exampleDark;
    return IconButton(
      onPressed: context.toggleExampleTheme,
      tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          color: colors.text),
    );
  }
}

class ExampleTopBar extends StatelessWidget {
  const ExampleTopBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.showThemeToggle = true,
    this.showTestCards = false,
    this.showWordmark = false,
    this.nameCheckHint = false,
    this.actions,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showThemeToggle;
  final bool showTestCards;
  final bool showWordmark;
  final bool nameCheckHint;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showWordmark) ...[
            const ExampleWordmark(),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: Icon(Icons.chevron_left, color: colors.text, size: 28),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showTestCards) TestCardsAction(nameCheckHint: nameCheckHint),
              if (actions != null) actions!,
              if (showThemeToggle) const ExampleThemeToggle(),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(color: colors.muted, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class SampleScaffold extends StatelessWidget {
  const SampleScaffold({
    required this.title,
    required this.onBack,
    required this.child,
    this.subtitle,
    this.showTestCards = false,
    this.nameCheckHint = false,
    this.showThemeToggle = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget child;
  final bool showTestCards;
  final bool nameCheckHint;
  final bool showThemeToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExampleTopBar(
              title: title,
              subtitle: subtitle,
              onBack: onBack,
              showTestCards: showTestCards,
              nameCheckHint: nameCheckHint,
              showThemeToggle: showThemeToggle,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExampleResultPanel extends StatelessWidget {
  const ExampleResultPanel({required this.result, super.key});

  final PaymentResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    final hero = _resultHero(result);
    final rows = _resultRows(result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExampleCard(
          child: Column(
            children: [
              if (hero.icon != null)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hero.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(hero.icon, color: hero.iconTint, size: 28),
                ),
              if (hero.icon != null) const SizedBox(height: 12),
              Text(
                hero.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hero.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ExampleCard(
          padding: 0,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: colors.hairline, indent: 20),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].label,
                          style: TextStyle(color: colors.muted, fontSize: 14),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          rows[i].value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultHero {
  const _ResultHero({
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconTint,
    this.iconBg,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Color? iconTint;
  final Color? iconBg;
}

class _KvRow {
  const _KvRow(this.label, this.value);
  final String label;
  final String value;
}

_ResultHero _resultHero(PaymentResult result) {
  return switch (result) {
    PaymentResultComplete() => const _ResultHero(
        title: 'Payment complete',
        subtitle: 'Your payment went through.',
        icon: Icons.check,
        iconTint: ExampleColors.purple,
        iconBg: Color(0x1F7C4DFF),
      ),
    PaymentResultFailed() => const _ResultHero(
        title: 'Payment didn’t go through',
        subtitle: 'Something went wrong. You can try again.',
        icon: Icons.close,
        iconTint: ExampleColors.error,
        iconBg: Color(0x1FFF4757),
      ),
    PaymentResultCanceled() => const _ResultHero(
        title: 'Payment canceled',
        subtitle: 'You closed checkout before finishing.',
      ),
  };
}

List<_KvRow> _resultRows(PaymentResult result) {
  if (result is PaymentResultComplete) {
    final tx = result.transaction;
    final customer = tx.customerData;
    final name = [
      customer?.firstName,
      customer?.lastName,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ');
    final rows = <_KvRow>[
      _KvRow('Status',
          tx.status?.trim().isNotEmpty == true ? tx.status! : 'Complete'),
    ];
    final amount = _formatResultAmount(tx.amount, tx.currencyKey);
    if (amount != null) rows.add(_KvRow('Amount', amount));
    if (tx.id?.trim().isNotEmpty == true) {
      rows.add(_KvRow('Transaction', tx.id!));
    }
    if (name.isNotEmpty) rows.add(_KvRow('Customer', name));
    if (customer?.email?.trim().isNotEmpty == true) {
      rows.add(_KvRow('Email', customer!.email!));
    }
    return rows;
  }
  if (result is PaymentResultFailed) {
    return [
      _KvRow(
          'Error',
          result.error.message.isNotEmpty
              ? result.error.message
              : result.error.code),
    ];
  }
  return const [_KvRow('Status', 'Canceled')];
}

String? _formatResultAmount(String? amount, String? currency) {
  final raw = amount?.trim();
  if (raw == null || raw.isEmpty) return null;
  final cur = (currency ?? '').toUpperCase();
  return switch (cur) {
    'EUR' => '€$raw',
    'USD' => '\$$raw',
    'GBP' => '£$raw',
    _ => cur.isNotEmpty ? '$raw $cur' : raw,
  };
}

class ExampleSection extends StatelessWidget {
  const ExampleSection({
    required this.title,
    required this.children,
    this.caption,
    super.key,
  });

  final String title;
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return ExampleCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(color: colors.muted, fontSize: 13),
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class ExampleSwitchRow extends StatelessWidget {
  const ExampleSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.showDivider = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Column(
      children: [
        if (showDivider) Divider(height: 1, color: colors.hairline, indent: 20),
        Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(subtitle,
                          style: TextStyle(color: colors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  activeTrackColor: ExampleColors.purple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ExampleSegmentedRow<T extends Object> extends StatelessWidget {
  const ExampleSegmentedRow({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<({String label, T value})> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(ExampleRadii.inner),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Material(
                color: option.value == value ? colors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(ExampleRadii.small),
                child: InkWell(
                  onTap: () => onChanged(option.value),
                  borderRadius: BorderRadius.circular(ExampleRadii.small),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            option.value == value ? colors.text : colors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ExampleStepperRow extends StatelessWidget {
  const ExampleStepperRow({
    required this.title,
    required this.valueLabel,
    required this.onMinus,
    required this.onPlus,
    this.caption,
    this.minusEnabled = true,
    this.plusEnabled = true,
    super.key,
  });

  final String title;
  final String? caption;
  final String valueLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool minusEnabled;
  final bool plusEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: colors.text, fontWeight: FontWeight.w600)),
                if (caption != null)
                  Text(caption!,
                      style: TextStyle(color: colors.muted, fontSize: 13)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.hairline),
              borderRadius: BorderRadius.circular(ExampleRadii.inner),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  icon: Icons.remove,
                  enabled: minusEnabled,
                  onPressed: onMinus,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(valueLabel,
                      style: TextStyle(
                          color: colors.text, fontWeight: FontWeight.w600)),
                ),
                _StepButton(
                  icon: Icons.add,
                  enabled: plusEnabled,
                  onPressed: onPlus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18, color: colors.text),
      ),
    );
  }
}

class ExampleOptionRow<T> extends StatelessWidget {
  const ExampleOptionRow({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.caption,
    this.showDivider = false,
    super.key,
  });

  final String title;
  final String? caption;
  final List<({String label, T value})> options;
  final ({String label, T value}) value;
  final ValueChanged<({String label, T value})> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.exampleColors;
    return Column(
      children: [
        if (showDivider) Divider(height: 1, color: colors.hairline, indent: 20),
        InkWell(
          onTap: () => _showPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: colors.text, fontWeight: FontWeight.w600)),
                      if (caption != null)
                        Text(caption!,
                            style:
                                TextStyle(color: colors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Text(value.label,
                    style: TextStyle(color: colors.muted, fontSize: 14)),
                Icon(Icons.chevron_right, color: colors.muted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final colors = context.exampleColors;
    final picked = await showModalBottomSheet<({String label, T value})>(
      context: context,
      backgroundColor: colors.card,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title,
                    style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
              for (final option in options)
                ListTile(
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: option.value == value.value
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) onChanged(picked);
  }
}

void copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
  );
}
