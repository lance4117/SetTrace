// Supplemental, explicitly controlled UI states. No production data is used.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/about/app_notice_dialog.dart';
import 'package:settrace/features/about/notice_preferences.dart';
import 'package:settrace/features/about/licenses_page.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/diagnostics/diagnostics_controller.dart';
import 'package:settrace/features/diagnostics/diagnostics_pages.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/main.dart';

import 'support/diagnostics_fakes.dart';
import 'support/focus_scenes.dart';
import 'ui_reference_capture_test.dart' as reference;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(reference.loadReferenceFonts);
  for (final language in ['zh', 'en']) {
    for (final dark in [false, true]) {
      for (final id in [
        'D15',
        'D16',
        'D18',
        'LD01',
        'LE02',
        'L05-enabled',
        'L07',
        'C05-licenses',
      ]) {
        testWidgets('extra reference $id $language dark=$dark', (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(360, 800);
          t.platformDispatcher.localesTestValue = [Locale(language)];
          t.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(t.platformDispatcher.clearAllTestValues);
          SharedPreferences.setMockInitialValues({});
          final l = lookupAppLocalizations(Locale(language));
          final transport = FakeDiagnosticsTransport()
            ..eventCount = 4
            ..bytes = 4096;
          final client = DiagnosticsClient(transport: transport);
          final controller = DiagnosticsController(client);
          FocusScene? scene;
          Future<void> capture(
            String name, {
            String state = 'normal',
            String group = 'about',
          }) => reference.saveFrame(
            t,
            name,
            language,
            dark,
            state: state,
            group: group,
            recordFile: 'extra-captures.json',
          );
          try {
            if (id == 'D18') {
              scene = await t.runAsync(
                () => FocusScene.create(
                  'C01',
                  Locale(language),
                  factory: databaseFactoryFfi,
                ),
              );
              scene!.dark = dark;
              await t.pumpWidget(reference.wrap(scene.page, language, dark));
              await settleFocus(t);
              await tapFocus(t, find.text(l.restReminderInterval));
              await capture('D18', group: 'settings');
            } else if (id == 'D15' || id == 'D16') {
              final prefs = await SharedPreferences.getInstance();
              await t.pumpWidget(
                reference.wrap(
                  Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => showAppNotice(
                          context,
                          preferences: id == 'D15'
                              ? NoticePreferences(prefs)
                              : null,
                        ),
                        child: const Text('reference-trigger'),
                      ),
                    ),
                  ),
                  language,
                  dark,
                ),
              );
              await t.tap(find.text('reference-trigger'));
              await t.pumpAndSettle();
              await capture(id);
              await t.drag(find.byType(AlertDialog), const Offset(0, -450));
              await t.pumpAndSettle();
              await capture(id, state: 'scroll-bottom');
            } else if (id == 'L07') {
              await t.pumpWidget(
                RepaintBoundary(
                  key: reference.rootKey,
                  child: SetTraceBootstrap(
                    writes: DataWriteCoordinator(),
                    diagnostics: client,
                    openDatabase: () async {
                      throw StateError(
                        'controlled reference database open failure',
                      );
                    },
                  ),
                ),
              );
              await t.pumpAndSettle();
              expect(find.text(l.diagStartupTitle), findsOneWidget);
              await capture('L07', group: 'diagnostics');
            } else if (id == 'C05-licenses') {
              await t.pumpWidget(
                reference.wrap(
                  AppLicensesPage(
                    loadLicenses: () async => [
                      for (final name in [
                        'flutter',
                        'sqflite',
                        'shared_preferences',
                        'package_info_plus',
                        'url_launcher',
                      ])
                        LicenseEntryWithLineBreaks(
                          [name],
                          'Reference fixture license text.\n\nComplete declaration is shown in this isolated UI test.',
                        ),
                    ],
                  ),
                  language,
                  dark,
                ),
              );
              await t.pumpAndSettle();
              await capture('C05-license-summary');
              await t.tap(find.text(l.viewAllLicenses));
              await t.pumpAndSettle();
              await capture('C05-license-all');
              await t.tap(find.text('Flutter'));
              await t.pumpAndSettle();
              await capture('C05-license-detail');
            } else {
              if (id == 'L05-enabled') {
                transport.detailedUntil = DateTime.now().add(
                  const Duration(minutes: 20),
                );
              }
              await controller.load(recoverExport: false);
              if (id == 'LE02') {
                transport.failMethods.add('setEnabled');
                await controller.setEnabled(false);
              }
              await t.pumpWidget(
                reference.wrap(
                  id == 'L05-enabled'
                      ? DiagnosticsDetailedPage(controller: controller)
                      : DiagnosticsPage(controller: controller),
                  language,
                  dark,
                ),
              );
              await t.pumpAndSettle();
              if (id == 'LD01') {
                await t.scrollUntilVisible(
                  find.text(l.diagClear),
                  180,
                  scrollable: find.byType(Scrollable).first,
                );
                await t.tap(find.text(l.diagClear));
                await t.pumpAndSettle();
                await capture('LD01', group: 'diagnostics');
                await t.tap(find.text(l.cancel).last);
                await t.pumpAndSettle();
                expect(transport.calls, isNot(contains('clear')));
              } else {
                await capture(
                  id == 'L05-enabled' ? 'L05' : id,
                  state: id == 'L05-enabled' ? 'enabled' : 'normal',
                  group: 'diagnostics',
                );
              }
            }
          } finally {
            await t.pumpWidget(const SizedBox());
            controller.dispose();
            client.dispose();
            if (scene != null) await t.runAsync(scene.close);
          }
        }, skip: reference.output.isEmpty);
      }
    }
  }
}
