import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.height = 56,
    this.variant,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary, busy;
  final double height;
  final AppButtonVariant? variant;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final kind =
        variant ??
        (primary ? AppButtonVariant.primary : AppButtonVariant.secondary);
    final (background, foreground) = switch (kind) {
      AppButtonVariant.primary => (c.accent, c.onAccent),
      AppButtonVariant.secondary => (c.accentSoft, c.onAccentSoft),
      AppButtonVariant.outline => (c.surface, c.onAccentSoft),
      AppButtonVariant.danger => (c.danger, c.onDanger),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height.clamp(
          kind == AppButtonVariant.primary ? 56 : 48,
          double.infinity,
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: c.disabledSurface,
            disabledForegroundColor: c.disabledText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              side: kind == AppButtonVariant.outline
                  ? BorderSide(color: c.controlBorder)
                  : BorderSide.none,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) ...[
                ExcludeSemantics(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.disabledText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
