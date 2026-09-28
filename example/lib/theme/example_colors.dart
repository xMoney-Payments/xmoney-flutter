import 'package:flutter/material.dart';

abstract final class ExampleColors {
  static const purple = Color(0xFF7C4DFF);
  static const purpleHover = Color(0xFF6D3FFF);
  static const purpleElectric = Color(0xFF9F55FF);
  static const purpleSoftLight = Color(0x1A7C4DFF);
  static const purpleSoftDark = Color(0x337C4DFF);
  static const lime = Color(0xFFDCFC97);
  static const limeHover = Color(0xFFC8F070);
  static const limeDark = Color(0xFF3C5708);
  static const lightBg = Color(0xFFF4F3FB);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF16141A);
  static const lightMuted = Color(0x8016141A);
  static const lightHairline = Color(0x0F16141A);
  static const lightHover = Color(0x0816141A);
  static const darkBg = Color(0xFF09090B);
  static const darkCard = Color(0xFF18181B);
  static const darkElevated = Color(0xFF1F1F23);
  static const darkText = Color(0xFFFAFAFA);
  static const darkMuted = Color(0xFFA1A1AA);
  static const darkHairline = Color(0x1FFFFFFF);
  static const darkHover = Color(0x0DFFFFFF);
  static const error = Color(0xFFFF4757);
  static const success = Color(0xFF059669);
  static const successSoftLight = Color(0x99D1FAE5);
  static const successSoftDark = Color(0x2610B981);
  static const dangerSoftLight = Color(0x99FEE2E2);
  static const dangerSoftDark = Color(0x26EF4444);
}

abstract final class AppearanceHex {
  static const lightMuted = '#8016141A';
  static const lightHairline = '#0F16141A';
  static const darkHairline = '#1FFFFFFF';
}

abstract final class ExampleRadii {
  static const pill = 9999.0;
  static const card = 24.0;
  static const inner = 16.0;
  static const small = 8.0;
}

class ExamplePalette {
  const ExamplePalette({
    required this.bg,
    required this.card,
    required this.elevated,
    required this.text,
    required this.muted,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.error,
    required this.success,
    required this.successSoft,
    required this.dangerSoft,
  });

  final Color bg;
  final Color card;
  final Color elevated;
  final Color text;
  final Color muted;
  final Color hairline;
  final Color accent;
  final Color onAccent;
  final Color accentText;
  final Color error;
  final Color success;
  final Color successSoft;
  final Color dangerSoft;

  static ExamplePalette light({
    Color accent = ExampleColors.purple,
    Color onAccent = Colors.white,
    Color? accentText,
  }) {
    return ExamplePalette(
      bg: ExampleColors.lightBg,
      card: ExampleColors.lightCard,
      elevated: ExampleColors.lightBg,
      text: ExampleColors.lightText,
      muted: ExampleColors.lightMuted,
      hairline: ExampleColors.lightHairline,
      accent: accent,
      onAccent: onAccent,
      accentText: accentText ?? accent,
      error: ExampleColors.error,
      success: ExampleColors.success,
      successSoft: ExampleColors.successSoftLight,
      dangerSoft: ExampleColors.dangerSoftLight,
    );
  }

  static ExamplePalette dark({
    Color accent = ExampleColors.purple,
    Color onAccent = Colors.white,
    Color? accentText,
  }) {
    return ExamplePalette(
      bg: ExampleColors.darkBg,
      card: ExampleColors.darkCard,
      elevated: ExampleColors.darkElevated,
      text: ExampleColors.darkText,
      muted: ExampleColors.darkMuted,
      hairline: ExampleColors.darkHairline,
      accent: accent,
      onAccent: onAccent,
      accentText: accentText ?? accent,
      error: ExampleColors.error,
      success: ExampleColors.success,
      successSoft: ExampleColors.successSoftDark,
      dangerSoft: ExampleColors.dangerSoftDark,
    );
  }
}
