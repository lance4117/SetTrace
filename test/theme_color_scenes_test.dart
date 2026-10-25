import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/l10n/localization.dart';

import 'support/focus_scenes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final preset in ThemeColorPreset.values) {
    for (final brightness in Brightness.values) {
      for (final id in [
        'P05',
        'W03',
        'W06',
        'X02',
        'H05',
        'C04',
        'D01',
        'D13',
      ]) {
        testWidgets('$preset $brightness $id shared theme', (t) async {
          SharedPreferences.setMockInitialValues({
            'app_notice_seen_version': 3,
          });
          final scene = (await t.runAsync(
            () => FocusScene.create(
              id,
              const Locale('en'),
              factory: databaseFactoryFfi,
            ),
          ))!;
          scene.dark = brightness == Brightness.dark;
          try {
            await t.pumpWidget(
              MaterialApp(
                theme: AppTheme.forPreset(brightness, preset),
                locale: scene.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: scene.page,
              ),
            );
            await settleFocus(t);
            await prepareFocusScene(t, scene);
            expect(t.takeException(), isNull);
            final element = t.element(find.byType(Scaffold).first);
            expect(
              Theme.of(element).colorScheme.primary,
              preset.palette(brightness).accent,
            );
            expect(
              element.appColors.onAccent,
              preset.palette(brightness).onAccent,
            );
          } finally {
            await t.pumpWidget(const SizedBox());
            await t.runAsync(scene.close);
          }
        });
      }
    }
  }
}
