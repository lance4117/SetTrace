import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/localization.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final labels = [
      context.l10n.plansTab,
      context.l10n.historyTab,
      context.l10n.settings,
    ];
    const icons = [
      Icons.fitness_center_outlined,
      Icons.history_outlined,
      Icons.settings_outlined,
    ];
    return Material(
      color: c.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.4,
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(3, (i) {
                  final selected = i == index;
                  return Expanded(
                    child: Semantics(
                      selected: selected,
                      button: true,
                      child: Material(
                        color: selected ? c.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                    icons[i],
                                    size: 22,
                                    color: selected
                                        ? c.onAccentSoft
                                        : c.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selected
                                        ? c.onAccentSoft
                                        : c.textSecondary,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
