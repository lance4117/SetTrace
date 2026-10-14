import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/l10n/localization.dart';

import '../test/support/focus_scenes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Focus A Android page and modal evidence', (t) async {
    await initializeDateFormatting();
    final directory = Directory(
      '${Directory.systemTemp.path}/focus-a-evidence',
    );
    await directory.create(recursive: true);
    final results = <Map<String, Object?>>[];
    var surfaceReady = false;
    for (final dark in [false, true]) {
      for (final language in ['en', 'zh']) {
        for (final id in focusSceneIds.where(
          (id) =>
              const String.fromEnvironment('FOCUS_SCENES').isEmpty ||
              const String.fromEnvironment('FOCUS_SCENES')
                  .split(',')
                  .contains(id),
        )) {
          final f = await FocusScene.create(id, Locale(language));
          try {
            f.dark = dark;
            if (id == 'D11') {
              await f.prefs.setString('theme_mode', dark ? 'dark' : 'light');
            }
            final page = f.page;
            await t.pumpWidget(
              id == 'D11'
                  ? page
                  : MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: dark ? AppTheme.dark : AppTheme.light,
                      locale: f.locale,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: page,
                    ),
            );
            await settleFocus(t);
            await prepareFocusScene(t, f);
            expect(
              t.takeException(),
              isNull,
              reason: '$id $language dark=$dark',
            );
            if (!surfaceReady) {
              await binding.convertFlutterSurfaceToImage();
              surfaceReady = true;
              await t.pumpAndSettle();
            }
            final context = t.element(find.byType(Scaffold).first);
            final size = MediaQuery.sizeOf(context);
            final name =
                '$id-$language-${dark ? 'dark' : 'light'}-${size.width.round()}';
            final bytes = await binding.takeScreenshot(name);
            await File('${directory.path}/$name.png').writeAsBytes(bytes);
            results.add({
              'id': id,
              'language': language,
              'dark': dark,
              'width': size.width,
              'height': size.height,
              'screenshot': '$name.png',
            });
            debugPrint('FOCUS_SCENE $name OK');
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
  }, timeout: const Timeout(Duration(minutes: 15)));
}
