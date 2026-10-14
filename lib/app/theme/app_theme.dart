import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.controlBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentPressed,
    required this.accentSoft,
    required this.onAccent,
    required this.onAccentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
    required this.warning,
    required this.warningSoft,
    required this.disabledSurface,
    required this.disabledText,
  });
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color controlBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentPressed;
  final Color accentSoft;
  final Color onAccent;
  final Color onAccentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color onDanger;
  final Color warning;
  final Color warningSoft;
  final Color disabledSurface;
  final Color disabledText;
  static const light = AppColors(
    background: Color(0xFFF5F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF2F3),
    border: Color(0xFFDBE3E5),
    controlBorder: Color(0xFF71858C),
    textPrimary: Color(0xFF19262C),
    textSecondary: Color(0xFF586970),
    textTertiary: Color(0xFF586970),
    accent: Color(0xFF087F6B),
    accentPressed: Color(0xFF076D5C),
    accentSoft: Color(0xFFE2F2ED),
    onAccent: Color(0xFFFFFFFF),
    onAccentSoft: Color(0xFF076D5C),
    danger: Color(0xFFB13C35),
    dangerSoft: Color(0xFFFFF0EE),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFF855208),
    warningSoft: Color(0xFFFFF1D8),
    disabledSurface: Color(0xFFE5E9EB),
    disabledText: Color(0xFF63747B),
  );
  static const dark = AppColors(
    background: Color(0xFF111518),
    surface: Color(0xFF191E22),
    surfaceAlt: Color(0xFF242C31),
    border: Color(0xFF354047),
    controlBorder: Color(0xFF82969D),
    textPrimary: Color(0xFFF0F5F6),
    textSecondary: Color(0xFFABB9BF),
    textTertiary: Color(0xFFABB9BF),
    accent: Color(0xFF5DD9B6),
    accentPressed: Color(0xFF41C6A3),
    accentSoft: Color(0xFF203B35),
    onAccent: Color(0xFF102A22),
    onAccentSoft: Color(0xFF5DD9B6),
    danger: Color(0xFFFFB4AB),
    dangerSoft: Color(0xFF422923),
    onDanger: Color(0xFF111518),
    warning: Color(0xFFF0CA83),
    warningSoft: Color(0xFF3E3322),
    disabledSurface: Color(0xFF2C353B),
    disabledText: Color(0xFFA3B0B6),
  );
  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? controlBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentPressed,
    Color? accentSoft,
    Color? onAccent,
    Color? onAccentSoft,
    Color? danger,
    Color? dangerSoft,
    Color? onDanger,
    Color? warning,
    Color? warningSoft,
    Color? disabledSurface,
    Color? disabledText,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    border: border ?? this.border,
    controlBorder: controlBorder ?? this.controlBorder,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    accent: accent ?? this.accent,
    accentPressed: accentPressed ?? this.accentPressed,
    accentSoft: accentSoft ?? this.accentSoft,
    onAccent: onAccent ?? this.onAccent,
    onAccentSoft: onAccentSoft ?? this.onAccentSoft,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    onDanger: onDanger ?? this.onDanger,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    disabledSurface: disabledSurface ?? this.disabledSurface,
    disabledText: disabledText ?? this.disabledText,
  );
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      disabledSurface: Color.lerp(disabledSurface, other.disabledSurface, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

abstract final class AppSpace {
  static const double s1 = 4,
      s2 = 8,
      s3 = 12,
      s4 = 16,
      s5 = 20,
      s6 = 24,
      s8 = 32;
}

abstract final class AppRadius {
  static const double input = 12,
      button = 14,
      card = 16,
      dialog = 20,
      sheet = 24;
}

abstract final class AppTheme {
  static final light = _make(Brightness.light, AppColors.light);
  static final dark = _make(Brightness.dark, AppColors.dark);
  static ThemeData _make(Brightness brightness, AppColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.onAccentSoft,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.onAccentSoft,
      tertiary: c.warning,
      onTertiary: c.background,
      tertiaryContainer: c.warningSoft,
      onTertiaryContainer: c.warning,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainerHighest: c.surfaceAlt,
      surfaceTint: Colors.transparent,
      outline: c.controlBorder,
      outlineVariant: c.border,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      inversePrimary: c.accentSoft,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
      fontFamilyFallback: const ['Noto Sans SC', 'Roboto', 'sans-serif'],
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: c.controlBorder),
    );
    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      extensions: [c],
      dividerColor: c.border,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 14,
          height: 1.5,
          color: c.textSecondary,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: c.onAccentSoft,
          disabledForegroundColor: c.disabledText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: c.onAccentSoft,
          side: BorderSide(color: c.controlBorder),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: c.textSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: c.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: c.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: TextStyle(color: c.background, fontSize: 14),
        actionTextColor: brightness == Brightness.light
            ? AppColors.dark.accent
            : AppColors.light.accent,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: border,
        enabledBorder: border,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: border.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textSecondary),
        errorMaxLines: 4,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
