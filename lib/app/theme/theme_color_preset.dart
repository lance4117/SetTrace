import 'package:flutter/material.dart';

enum ThemeColorPreset {
  teal,
  blue,
  violet,
  graphite;

  static ThemeColorPreset parse(Object? value) =>
      values.firstWhere((preset) => preset.name == value, orElse: () => teal);

  AccentPalette palette(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final (accent, pressed, soft, onAccent, onSoft) = switch (this) {
      teal when dark => (
        0xFF5DD9B6,
        0xFF41C6A3,
        0xFF203B35,
        0xFF102A22,
        0xFF5DD9B6,
      ),
      teal => (0xFF087F6B, 0xFF076D5C, 0xFFE2F2ED, 0xFFFFFFFF, 0xFF076D5C),
      blue when dark => (
        0xFF9BBDFF,
        0xFF82AAEF,
        0xFF1D3152,
        0xFF10264D,
        0xFFB6CEFF,
      ),
      blue => (0xFF245FC7, 0xFF1E50AA, 0xFFEAF0FC, 0xFFFFFFFF, 0xFF1E50AA),
      violet when dark => (
        0xFFCCB2FF,
        0xFFB89AEF,
        0xFF362746,
        0xFF2B1648,
        0xFFD8C5FF,
      ),
      violet => (0xFF7046B8, 0xFF603AA4, 0xFFF1EBFA, 0xFFFFFFFF, 0xFF603AA4),
      graphite when dark => (
        0xFFD6DDE3,
        0xFFB9C4CD,
        0xFF30383F,
        0xFF1C252D,
        0xFFD6DDE3,
      ),
      graphite => (0xFF303A43, 0xFF222B33, 0xFFE8ECEF, 0xFFFFFFFF, 0xFF303A43),
    };
    return AccentPalette(
      Color(accent),
      Color(pressed),
      Color(soft),
      Color(onAccent),
      Color(onSoft),
    );
  }
}

@immutable
class AccentPalette {
  const AccentPalette(
    this.accent,
    this.pressed,
    this.soft,
    this.onAccent,
    this.onSoft,
  );
  final Color accent, pressed, soft, onAccent, onSoft;
}
