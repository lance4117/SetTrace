import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/l10n/localization.dart';

import 'support/focus_scenes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final width in [360.0, 430.0]) {
    for (final dark in [false, true]) {
      for (final language in ['en', 'zh']) {
        for (final id in focusSceneIds.where((id) => id != 'D11')) {
          testWidgets('$id $width ${dark ? 'dark' : 'light'} $language', (
            t,
          ) async {
            t.view.physicalSize = Size(width, 800);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({});
            final f = (await t.runAsync(
              () => FocusScene.create(
                id,
                Locale(language),
                factory: databaseFactoryFfi,
              ),
            ))!;
            try {
              f.dark = dark;
              await t.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  locale: f.locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: f.page,
                ),
              );
              await settleFocus(t);
              await prepareFocusScene(t, f);
              expect(t.takeException(), isNull, reason: id);
              // Exercise the content tail separately from fixed controls.
              final scroll = find.byType(Scrollable).hitTestable();
              if (!id.startsWith('D') &&
                  scroll.evaluate().isNotEmpty &&
                  find.byType(AlertDialog).evaluate().isEmpty) {
                await t.drag(scroll.first, const Offset(0, -900));
                await t.pumpAndSettle();
                expect(t.takeException(), isNull, reason: '$id content tail');
              }
            } finally {
              await t.pumpWidget(const SizedBox());
              await t.runAsync(f.close);
            }
          });
        }
      }
    }
  }
  for (final size in [
    const Size(360, 640),
    const Size(740, 390),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.3, 1.6]) {
      for (final id in [
        'P02',
        'P03',
        'P04',
        'W01',
        'W03',
        'W06',
        'S01',
        'S02',
        'S03',
        'S04',
        'X01',
        'X02',
        'X03',
        'X04',
        'H01',
        'H02',
        'C01',
        'C02',
        'C04',
        'D01',
        'D03',
        'D05',
        'D06',
        'D08',
        'D09',
        'D10',
        'D13',
        'D14',
      ]) {
        testWidgets(
          '$id adaptation ${size.width}x${size.height} $scale reduced motion',
          (t) async {
            t.view.physicalSize = size;
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({});
            final f = (await t.runAsync(
              () => FocusScene.create(
                id,
                const Locale('en'),
                factory: databaseFactoryFfi,
              ),
            ))!;
            try {
              f.dark = true;
              await t.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.dark,
                  locale: f.locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: f.page,
                ),
              );
              await settleFocus(t);
              await prepareFocusScene(t, f);
              expect(t.takeException(), isNull, reason: id);
            } finally {
              await t.pumpWidget(const SizedBox());
              await t.runAsync(f.close);
            }
          },
        );
      }
    }
  }
}
