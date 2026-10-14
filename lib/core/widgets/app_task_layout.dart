import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Keeps the current task reachable without covering the scrollable content.
/// The action region can itself scroll for unusually large translated labels.
class AppTaskLayout extends StatelessWidget {
  const AppTaskLayout({super.key, required this.body, required this.actions});
  final Widget body, actions;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.maxWidth >= 700 ||
            (constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 480);
        Widget actionRegion(double maxHeight) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: actions,
            ),
          ),
        );
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              VerticalDivider(width: 1, color: context.appColors.border),
              SizedBox(
                width: (constraints.maxWidth * 0.38).clamp(240, 360),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: actionRegion(constraints.maxHeight),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: body),
            Divider(height: 1, color: context.appColors.border),
            actionRegion(constraints.maxHeight * 0.48),
          ],
        );
      },
    ),
  );
}
