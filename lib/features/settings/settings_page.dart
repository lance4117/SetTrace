import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.mode, required this.onModeChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('设置', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      Text('外观', style: TextStyle(color: colors.textSecondary)),
      const SizedBox(height: 12),
      AppCard(child: RadioGroup<ThemeMode>(groupValue: mode,
        onChanged: (selected) {
          if (selected != null) onModeChanged(selected);
        }, child: Column(children: [
        for (final (value, label) in [
          (ThemeMode.system, '跟随系统'),
          (ThemeMode.light, '浅色'),
          (ThemeMode.dark, '深色'),
        ])
          RadioListTile<ThemeMode>(title: Text(label), value: value,
            contentPadding: EdgeInsets.zero),
      ]))),
      const SizedBox(height: 16),
      Text('训练数据仅保存在本机。',
        style: TextStyle(color: colors.textTertiary, fontSize: 12)),
    ]));
  }
}
