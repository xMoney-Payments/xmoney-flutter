import 'package:flutter/material.dart';

import 'example_colors.dart';

class ExampleThemeController extends ChangeNotifier {
  ExampleThemeController({this.dark = false});

  bool dark;

  void toggle() {
    dark = !dark;
    notifyListeners();
  }
}

class ExampleThemeScope extends InheritedNotifier<ExampleThemeController> {
  const ExampleThemeScope({
    required super.notifier,
    required this.palette,
    required super.child,
    super.key,
  });

  final ExamplePalette palette;

  static ExampleThemeController controllerOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExampleThemeScope>();
    assert(scope != null, 'ExampleThemeScope not found');
    return scope!.notifier!;
  }

  static ExamplePalette paletteOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExampleThemeScope>();
    assert(scope != null, 'ExampleThemeScope not found');
    return scope!.palette;
  }

  @override
  bool updateShouldNotify(ExampleThemeScope oldWidget) {
    return palette != oldWidget.palette;
  }
}

class ExampleThemeProvider extends StatefulWidget {
  const ExampleThemeProvider({
    required this.child,
    this.accent,
    this.onAccent,
    this.accentText,
    super.key,
  });

  final Widget child;
  final Color? accent;
  final Color? onAccent;
  final Color? accentText;

  @override
  State<ExampleThemeProvider> createState() => _ExampleThemeProviderState();
}

class _ExampleThemeProviderState extends State<ExampleThemeProvider> {
  ExampleThemeController? _owned;

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  ExampleThemeController _controllerFor(BuildContext context) {
    final parent =
        context.dependOnInheritedWidgetOfExactType<ExampleThemeScope>();
    if (parent?.notifier != null) return parent!.notifier!;
    return _owned ??= ExampleThemeController();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controllerFor(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final accent = widget.accent ?? ExampleColors.purple;
        final onAccent = widget.onAccent ?? Colors.white;
        // Dark surfaces use the brand fill so a dark accent text stays readable.
        final accentText = controller.dark ? accent : widget.accentText;
        final palette = controller.dark
            ? ExamplePalette.dark(
                accent: accent,
                onAccent: onAccent,
                accentText: accentText,
              )
            : ExamplePalette.light(
                accent: accent,
                onAccent: onAccent,
                accentText: accentText,
              );
        return ExampleThemeScope(
          notifier: controller,
          palette: palette,
          child: Theme(
            data: exampleThemeData(palette, dark: controller.dark),
            child: child!,
          ),
        );
      },
      child: widget.child,
    );
  }
}

ThemeData exampleThemeData(ExamplePalette palette, {required bool dark}) {
  final base = ColorScheme.fromSeed(
    seedColor: ExampleColors.purple,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      primary: ExampleColors.purple,
      onPrimary: Colors.white,
      primaryContainer:
          dark ? ExampleColors.purpleSoftDark : ExampleColors.purpleSoftLight,
      onPrimaryContainer:
          dark ? ExampleColors.purpleElectric : ExampleColors.purple,
      secondary: ExampleColors.lime,
      onSecondary: ExampleColors.limeDark,
      secondaryContainer: ExampleColors.limeHover,
      onSecondaryContainer: ExampleColors.limeDark,
      error: palette.error,
      onError: Colors.white,
      errorContainer: palette.dangerSoft,
      onErrorContainer: palette.error,
      surface: palette.card,
      onSurface: palette.text,
      onSurfaceVariant: palette.muted,
      outline: palette.hairline,
      outlineVariant: palette.hairline,
    ),
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    highlightColor: dark ? ExampleColors.darkHover : ExampleColors.lightHover,
    splashColor: ExampleColors.purple.withValues(alpha: dark ? 0.20 : 0.10),
  );
}

extension ExampleThemeContext on BuildContext {
  ExamplePalette get exampleColors => ExampleThemeScope.paletteOf(this);
  bool get exampleDark => ExampleThemeScope.controllerOf(this).dark;
  void toggleExampleTheme() => ExampleThemeScope.controllerOf(this).toggle();
}
