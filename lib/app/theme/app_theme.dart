import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background, required this.surface, required this.surfaceAlt,
    required this.border, required this.textPrimary, required this.textSecondary,
    required this.textTertiary, required this.accent, required this.accentPressed,
    required this.accentSoft, required this.onAccent, required this.danger,
    required this.dangerSoft,
  });

  final Color background, surface, surfaceAlt, border;
  final Color textPrimary, textSecondary, textTertiary;
  final Color accent, accentPressed, accentSoft, onAccent, danger, dangerSoft;

  static const light = AppColors(
    background: Color(0xFFF6F7F8), surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF1F3), border: Color(0xFFD9DEE3),
    textPrimary: Color(0xFF161A1D), textSecondary: Color(0xFF66707A),
    textTertiary: Color(0xFF98A2AD), accent: Color(0xFF42D6A4),
    accentPressed: Color(0xFF24B986), accentSoft: Color(0xFFE8FBF4),
    onAccent: Color(0xFF0C1512), danger: Color(0xFFF06565),
    dangerSoft: Color(0xFFFFF0F0),
  );
  static const dark = AppColors(
    background: Color(0xFF111315), surface: Color(0xFF1B1E21),
    surfaceAlt: Color(0xFF24282C), border: Color(0xFF30353A),
    textPrimary: Color(0xFFF5F6F7), textSecondary: Color(0xFF9CA3A9),
    textTertiary: Color(0xFF596068), accent: Color(0xFF42D6A4),
    accentPressed: Color(0xFF24B986), accentSoft: Color(0xFF17221F),
    onAccent: Color(0xFF0C1512), danger: Color(0xFFFF6868),
    dangerSoft: Color(0xFF2A1719),
  );

  @override
  AppColors copyWith({Color? background, Color? surface, Color? surfaceAlt,
    Color? border, Color? textPrimary, Color? textSecondary,
    Color? textTertiary, Color? accent, Color? accentPressed,
    Color? accentSoft, Color? onAccent, Color? danger, Color? dangerSoft}) => AppColors(
      background: background ?? this.background, surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt, border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent, accentPressed: accentPressed ?? this.accentPressed,
      accentSoft: accentSoft ?? this.accentSoft, onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger, dangerSoft: dangerSoft ?? this.dangerSoft,
    );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

abstract final class AppSpace {
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 20, s6 = 24, s8 = 32;
}

abstract final class AppRadius {
  static const double input = 12, button = 14, card = 16;
}

abstract final class AppTheme {
  static final light = _make(Brightness.light, AppColors.light);
  static final dark = _make(Brightness.dark, AppColors.dark);

  static ThemeData _make(Brightness brightness, AppColors colors) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: colors.border),
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent, brightness: brightness, surface: colors.surface),
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background, foregroundColor: colors.textPrimary,
        elevation: 0, centerTitle: true),
      textTheme: base.textTheme.apply(
        bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: colors.surface, border: border,
        enabledBorder: border),
    );
  }
}
