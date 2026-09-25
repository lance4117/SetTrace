import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const labels = ['计划', '记录', '设置'];
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(child: Material(
            color: selected ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(height: 48, child: Center(child: Text(
                labels[i],
                style: TextStyle(
                  color: selected ? colors.accentPressed : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ))),
            ),
          ));
        })),
      ),
    );
  }
}
