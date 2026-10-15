import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/features/about/license_catalog.dart';
import 'package:settrace/features/about/licenses_page.dart';
import 'package:settrace/l10n/localization.dart';

LicenseEntry notice(List<String> names, String text) =>
    LicenseEntryWithLineBreaks(names, text);
List<LicenseEntry> sample() => [
  notice(['_fe_analyzer_shared'], 'Non-featured notice'),
  for (final name in featuredLicensePackages)
    notice([name], 'Full original statement for $name'),
  notice(['flutter'], 'Additional Flutter statement'),
  notice(['flutter'], 'Additional Flutter statement'),
];
Widget app({
  String language = 'en',
  bool dark = false,
  double scale = 1,
  Future<List<LicenseEntry>> Function()? load,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: AppLicensesPage(loadLicenses: load ?? () async => sample()),
);
void main() {
  test(
    'groups exact projects preserving shared, distinct and unnamed notices',
    () {
      final grouped = groupProjectLicenses([
        notice(['flutter', 'sqflite'], 'Shared notice'),
        notice(['flutter'], 'Shared notice'),
        notice(['flutter'], 'Different notice'),
        notice([], 'Unnamed notice'),
        notice(['z', 'z'], 'Last notice'),
      ]);
      expect(grouped.map((p) => p.package), ['', 'flutter', 'sqflite', 'z']);
      expect(grouped[1].notices, ['Shared notice', 'Different notice']);
      expect(grouped[2].notices, ['Shared notice']);
      expect(grouped.first.notices, ['Unnamed notice']);
    },
  );
  testWidgets(
    'summary has only five names and purposes, details preserve notices',
    (t) async {
      var loads = 0;
      await t.pumpWidget(
        app(
          load: () async {
            loads++;
            return sample();
          },
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.text('_fe_analyzer_shared'), findsNothing);
      expect(find.text('App framework'), findsOneWidget);
      expect(find.text('Full original statement for flutter'), findsNothing);
      await t.tap(find.text('Flutter'));
      await t.pumpAndSettle();
      expect(find.text('Full original statement for flutter'), findsOneWidget);
      expect(find.text('Additional Flutter statement'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('View all open-source licenses'));
      await t.pumpAndSettle();
      await t.tap(find.text('View all open-source licenses'));
      await t.pumpAndSettle();
      expect(find.text('_fe_analyzer_shared'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      await t.tap(find.text('_fe_analyzer_shared'));
      await t.pumpAndSettle();
      expect(find.text('Non-featured notice'), findsOneWidget);
      expect(loads, 1);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('App framework'), findsOneWidget);
    },
  );
  testWidgets(
    'missing featured project is not invented; unnamed notice stays accessible',
    (t) async {
      await t.pumpWidget(
        app(load: () async => [notice([], 'Unnamed original')]),
      );
      await t.pumpAndSettle();
      expect(find.text('Flutter'), findsNothing);
      await t.tap(find.text('View all open-source licenses'));
      await t.pumpAndSettle();
      await t.tap(find.text('Other notices'));
      await t.pumpAndSettle();
      expect(find.text('Unnamed original'), findsOneWidget);
    },
  );
  testWidgets(
    'all projects list retains its scroll offset after viewing a license',
    (t) async {
      await t.pumpWidget(
        app(
          load: () async => [
            for (var i = 0; i < 50; i++)
              notice(['project_${i.toString().padLeft(2, '0')}'], 'Notice $i'),
          ],
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('View all open-source licenses'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('project_35'), 300);
      await t.pumpAndSettle();
      final before = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await t.tap(find.text('project_35'));
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(
        t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels,
        before,
      );
    },
  );
  for (final language in ['zh', 'en']) {
    for (final dark in [false, true]) {
      for (final width in [360.0, 430.0]) {
        for (final scale in [1.0, 1.6]) {
          testWidgets('license navigation $language $dark $width $scale', (
            t,
          ) async {
            t.view.physicalSize = Size(width, 800);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            final l = lookupAppLocalizations(Locale(language));
            await t.pumpWidget(
              app(language: language, dark: dark, scale: scale),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await t.tap(find.text('Flutter'));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await t.tap(find.byType(BackButton));
            await t.pumpAndSettle();
            await t.scrollUntilVisible(find.text(l.viewAllLicenses), 200);
            await t.pumpAndSettle();
            await t.tap(find.text(l.viewAllLicenses));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await t.tap(find.text('Flutter'));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }
}
