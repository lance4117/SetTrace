import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_color_controller.dart';
import '../../app/theme/theme_color_preset.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/localization.dart';

class ThemeColorSection extends StatelessWidget {
  const ThemeColorSection({super.key, this.controller});
  final ThemeColorController? controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller ?? kAlwaysDismissedAnimation,
    builder: (context, _) {
      final l = context.l10n;
      final c = context.appColors;
      final selected = controller?.selected ?? ThemeColorPreset.teal;
      final names = [
        l.themeColorTeal,
        l.themeColorBlue,
        l.themeColorViolet,
        l.themeColorGraphite,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(l.themeColor, style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Keep the swatches on one row regardless of text scale.
                    // Extremely narrow containers still preserve touch targets.
                    final columns = constraints.maxWidth >= 4 * 52 + 24 ? 4 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;
                    return Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label: l.themeColor,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in ThemeColorPreset.values)
                            SizedBox(
                              width: width,
                              child: _ColorOption(
                                preset: preset,
                                semanticName: preset == ThemeColorPreset.teal
                                    ? l.themeColorDefault
                                    : names[preset.index],
                                selected: selected == preset,
                                onTap: controller == null
                                    ? null
                                    : () => controller!.select(preset),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller?.failedTarget != null
                        ? l.themeColorSaveFailed
                        : controller?.saving == true
                        ? l.themeColorSaving
                        : l.themeColorHint,
                    key: const ValueKey('theme-color-status'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: controller?.failedTarget != null
                          ? c.danger
                          : c.textSecondary,
                    ),
                  ),
                ),
                if (controller?.failedTarget != null)
                  TextButton(
                    onPressed: controller!.saving ? null : controller!.retry,
                    child: Text(l.retry),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ColorOption extends StatefulWidget {
  const _ColorOption({
    required this.preset,
    required this.semanticName,
    required this.selected,
    this.onTap,
  });
  final ThemeColorPreset preset;
  final String semanticName;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ColorOption> createState() => _ColorOptionState();
}

class _ColorOptionState extends State<_ColorOption> {
  bool focused = false;
  ThemeColorPreset get preset => widget.preset;
  String get semanticName => widget.semanticName;
  bool get selected => widget.selected;
  VoidCallback? get onTap => widget.onTap;
  @override
  Widget build(BuildContext context) {
    final p = preset.palette(Theme.of(context).brightness);
    return Semantics(
      key: ValueKey('theme-color-${preset.name}'),
      label: semanticName,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onFocusChange: (value) => setState(() => focused = value),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused
                    ? context.appColors.controlBorder
                    : Colors.transparent,
                width: 2,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? p.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.accent,
                      ),
                      child: selected
                          ? Icon(Icons.check, size: 22, color: p.onAccent)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
