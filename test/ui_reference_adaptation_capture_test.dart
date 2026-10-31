import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/l10n/localization.dart';

import 'support/focus_scenes.dart';
import 'ui_reference_capture_test.dart' as reference;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(reference.loadReferenceFonts);
  final profiles = [
    ('A01', 'W01', const Size(360, 800), 1.0, ThemeColorPreset.teal),
    ('A02', 'W01', const Size(360, 640), 1.6, ThemeColorPreset.teal),
    ('A04', 'P03', const Size(740, 390), 1.6, ThemeColorPreset.teal),
    ('A05', 'H01', const Size(768, 1024), 1.3, ThemeColorPreset.teal),
    ('A01', 'C01', const Size(430, 932), 1.3, ThemeColorPreset.blue),
    ('A02', 'W01', const Size(430, 932), 1.6, ThemeColorPreset.violet),
    ('A05', 'H01', const Size(768, 600), 1.6, ThemeColorPreset.graphite),
  ];
  for (final language in ['zh', 'en']) {
    for (final dark in [false, true]) {
      for (final profile in profiles) {
        testWidgets(
          'adaptation ${profile.$1} ${profile.$2} ${profile.$3} $language $dark',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = profile.$3;
            SharedPreferences.setMockInitialValues({});
            final scene = await t.runAsync(
              () => FocusScene.create(
                profile.$2,
                Locale(language),
                factory: databaseFactoryFfi,
              ),
            );
            try {
              scene!.dark = dark;
              if (profile.$1 == 'A02') {
                await t.runAsync(
                  () => scene.database.db.update('session_exercises', {
                    'name_snapshot': 'Long exercise name for adaptive wrapping and clear controls',
                  }),
                );
                scene.session = await t.runAsync(
                  () async =>
                      (await scene.workouts.getSession(scene.session!.id))!,
                );
              }
              await t.pumpWidget(
                RepaintBoundary(
                  key: reference.rootKey,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    locale: Locale(language),
                    theme: AppTheme.forPreset(
                      dark ? Brightness.dark : Brightness.light,
                      profile.$5,
                    ),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(profile.$4),
                        disableAnimations: true,
                      ),
                      child: child!,
                    ),
                    home: scene.page,
                  ),
                ),
              );
              await settleFocus(t);
              expect(t.takeException(), isNull);
              await reference.saveFrame(
                t,
                profile.$1,
                language,
                dark,
                state:
                    '${profile.$2}-${profile.$3.width.round()}-${profile.$4}-${profile.$5.name}-reduced-motion',
                group: 'adaptation',
                recordFile: 'adaptation-captures.json',
                size: profile.$3,
                scale: profile.$4,
                preset: profile.$5.name,
              );
            } finally {
              await t.pumpWidget(const SizedBox());
              await t.runAsync(() => scene!.close());
            }
          },
          skip: reference.output.isEmpty,
        );
      }
    }
  }
}
