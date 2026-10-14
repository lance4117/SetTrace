import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/l10n/localization.dart';

import '../test/support/focus_scenes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android keyboard and large-text form reachability', (t) async {
    await initializeDateFormatting();
    final directory = Directory(
      '${Directory.systemTemp.path}/focus-a-accessibility',
    );
    await directory.create(recursive: true);
    final results = <Map<String, Object?>>[];
    var converted = false;
    for (final dark in [false, true]) {
      for (final language in ['en', 'zh']) {
        for (final id in ['P03', 'X02', 'D01']) {
          final f = await FocusScene.create(id, Locale(language));
          try {
            f.dark = dark;
            await t.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: f.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.6),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: f.page,
              ),
            );
            await settleFocus(t);
            await prepareFocusScene(t, f);
            final field = find.byType(TextField).first;
            await t.ensureVisible(field);
            await t.showKeyboard(field);
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 650)),
            );
            await settleFocus(t);
            await t.enterText(field, id == 'X02' ? 'broken' : '');
            await t.pump();
            final l = lookupAppLocalizations(f.locale);
            await tapFocus(
              t,
              find.text(
                id == 'P03'
                    ? l.saveExercise
                    : id == 'X02'
                    ? l.previewPlans
                    : l.save,
              ),
            );
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 200)),
            );
            await settleFocus(t);
            expect(t.takeException(), isNull, reason: '$id $language');
            final context = t.element(find.byType(Scaffold).first);
            final inset = MediaQuery.viewInsetsOf(context).bottom;
            expect(
              inset,
              greaterThan(0),
              reason: 'The actual Android IME must be visible',
            );
            if (id == 'P03' || id == 'D01') {
              expect(
                t.widget<TextField>(field).decoration!.errorText,
                isNotNull,
              );
            }
            if (!converted) {
              await binding.convertFlutterSurfaceToImage();
              converted = true;
              await t.pumpAndSettle();
            }
            final name =
                '$id-$language-${dark ? 'dark' : 'light'}-keyboard-1_6';
            await File('${directory.path}/$name.png')
                .writeAsBytes(await binding.takeScreenshot(name));
            results.add({
              'scene': id,
              'language': language,
              'dark': dark,
              'scale': 1.6,
              'keyboardInset': inset,
              'status': 'passed',
            });
            await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
            await settleFocus(t);
          } finally {
            await t.pumpWidget(const SizedBox());
            await f.close();
          }
        }
      }
    }
    await File('${directory.path}/results.json')
        .writeAsString(jsonEncode(results));
    if (const bool.fromEnvironment('FOCUS_EXPORT_WAIT')) {
      debugPrint('FOCUS_EXPORT_READY');
      for (var i = 0; i < 120; i++) {
        if (await File('${directory.path}/export.done').exists()) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
