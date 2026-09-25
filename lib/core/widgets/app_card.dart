import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child,
    this.padding = const EdgeInsets.all(16), this.onTap,
    this.backgroundColor, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor, borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: backgroundColor ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: borderColor ?? colors.border)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
