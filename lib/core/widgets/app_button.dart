import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onPressed,
    this.primary = true, this.height = 56});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: height < 48 ? 48 : height, width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? colors.accent : colors.surfaceAlt,
          foregroundColor: primary ? colors.onAccent : colors.textPrimary,
          disabledBackgroundColor: colors.surfaceAlt,
          disabledForegroundColor: colors.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
            side: primary ? BorderSide.none : BorderSide(color: colors.border),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
