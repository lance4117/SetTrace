import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/widgets/app_bottom_nav.dart';
import 'package:settrace/features/history/history_page.dart';
import 'package:settrace/features/history/history_summary_card.dart';
import 'package:settrace/l10n/localization.dart';

import '../test/support/focus_scenes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android history layout and deletion on isolated fixtures', (
    t,
  ) async {
    final output = Directory(
      '${Directory.systemTemp.path}/history-summary-evidence',
    );
    await output.create(recursive: true);
    final results = <Map<String, Object?>>[];
    final captureKey = GlobalKey();
    Future<List<int>> capture() async {
      await t.pumpAndSettle();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    for (final language in ['zh', 'en']) {
      for (final dark in [false, true]) {
        for (final seconds in [11520, 445500]) {
          final scene = await FocusScene.create('H01', Locale(language));
          try {
            await scene.database.db.update('workout_sessions', {
              'duration_seconds': seconds,
            });
            final scale = seconds == 445500 ? 1.6 : 1.0;
            final strings = lookupAppLocalizations(Locale(language));
            await t.pumpWidget(
              RepaintBoundary(
                key: captureKey,
                child: MaterialApp(
                  key: ValueKey('$language-$dark-$seconds'),
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.forPreset(
                    dark ? Brightness.dark : Brightness.light,
                    ThemeColorPreset.graphite,
                  ),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: HistoryPage(workouts: scene.workouts, revision: 0),
                    bottomNavigationBar: AppBottomNav(
                      index: 1,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final summary = find.byType(HistorySummaryCard);
            final historyScroll = find.descendant(
              of: find.byType(HistoryPage),
              matching: find.byType(Scrollable),
            );
            expect(
              t.widget<HistorySummaryCard>(summary).durationSeconds,
              seconds,
            );
            expect(t.takeException(), isNull);
            final name =
                'history-$language-${dark ? 'dark' : 'light'}-$seconds';
            await File('${output.path}/$name.png')
                .writeAsBytes(await capture());
            final media = MediaQuery.of(t.element(summary));
            results.add({
              'name': name,
              'size': '${media.size}',
              'scale': scale,
              'seconds': seconds,
            });
            await t.scrollUntilVisible(
              find.byTooltip(strings.previousMonth),
              160,
              scrollable: historyScroll,
            );
            await t.pumpAndSettle();
            await t.tap(find.byTooltip(strings.previousMonth));
            await t.pumpAndSettle();
            expect(t.widget<HistorySummaryCard>(summary).durationSeconds, 0);
            expect(find.text(strings.noHistoryMonth), findsOneWidget);
            final emptyName = '$name-empty-month';
            await File('${output.path}/$emptyName.png')
                .writeAsBytes(await capture());
            await t.tap(find.byTooltip(strings.nextMonth));
            await t.pumpAndSettle();
            expect(
              t.widget<HistorySummaryCard>(summary).durationSeconds,
              seconds,
            );
            final records = await scene.workouts.listHistory();
            final record = find.byKey(
              ValueKey('history-session-${records.single.id}'),
            );
            await t.scrollUntilVisible(record, 160, scrollable: historyScroll);
            await Scrollable.ensureVisible(t.element(record), alignment: 1);
            await t.pumpAndSettle();
            expect(record.hitTestable(), findsOneWidget);
            final navigation = find.byType(AppBottomNav);
            expect(
              t.getBottomLeft(record).dy,
              lessThanOrEqualTo(t.getTopLeft(navigation).dy),
            );
            await t.tap(record);
            await t.pumpAndSettle();
            await t.tap(find.byTooltip(strings.historyMenu));
            await t.pumpAndSettle();
            await t.tap(find.text(strings.deleteHistory));
            await t.pumpAndSettle();
            await t.tap(find.widgetWithText(TextButton, strings.cancel));
            await t.pumpAndSettle();
            expect(await scene.workouts.listHistory(), hasLength(1));
            await t.tap(find.byTooltip(strings.historyMenu));
            await t.pumpAndSettle();
            await t.tap(find.text(strings.deleteHistory));
            await t.pumpAndSettle();
            await t.tap(find.widgetWithText(TextButton, strings.delete));
            await t.pumpAndSettle();
            expect(find.text(strings.noHistoryAll), findsOneWidget);
            expect(t.widget<HistorySummaryCard>(summary).durationSeconds, 0);
            expect(await scene.workouts.listHistory(), isEmpty);
            expect(t.takeException(), isNull);
            debugPrint('HISTORY_ANDROID $name passed');
          } finally {
            await t.pumpWidget(const SizedBox());
            await scene.close();
          }
        }
      }
    }
    await File('${output.path}/results.json')
        .writeAsString(jsonEncode(results));
    debugPrint('HISTORY_EVIDENCE ${output.path}');
    if (const bool.fromEnvironment('HISTORY_EXPORT_WAIT')) {
      debugPrint('HISTORY_EXPORT_READY');
      for (var i = 0; i < 120; i++) {
        if (await File('${output.path}/export.done').exists()) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
