import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/features/settings/settings_page.dart';

void main() {
  testWidgets('settings offers system, light and dark modes', (tester) async {
    ThemeMode selected = ThemeMode.system;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: SettingsPage(mode: selected,
        onModeChanged: (value) => selected = value))));
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    await tester.tap(find.text('深色'));
    expect(selected, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(Scaffold)))
      .extension<AppColors>(), isNotNull);
  });
}
