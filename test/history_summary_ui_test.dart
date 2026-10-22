import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/widgets/app_card.dart';
import 'package:settrace/features/history/history_page.dart';
import 'package:settrace/features/history/history_summary_card.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/long_localizations.dart';
import 'history_delete_ui_test.dart' show ControlledHistory, sample;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late ControlledHistory repository;
  final now = DateTime.now();
  final previous = DateTime(now.year, now.month - 1, 15);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    repository = ControlledHistory(db)
      ..records = [sample(2, now, 11520, 63), sample(1, previous, 3540, 4)];
  });
  tearDown(() async => db.close());

  Future<void> mount(
    WidgetTester t, {
    String language = 'en',
    double scale = 1,
    Size size = const Size(430, 900),
    Brightness brightness = Brightness.light,
    ThemeColorPreset preset = ThemeColorPreset.teal,
    bool longLabels = false,
    bool reducedMotion = false,
    int revision = 0,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: [
          if (longLabels) const LongDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.forPreset(brightness, preset),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(bottom: 24),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: HistoryPage(workouts: repository, revision: revision),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Finder getSummary() => find.byKey(const ValueKey('history-month-summary'));
  void contained(Rect outer, Rect inner) {
    expect(inner.left, greaterThanOrEqualTo(outer.left - .1));
    expect(inner.right, lessThanOrEqualTo(outer.right + .1));
    expect(inner.top, greaterThanOrEqualTo(outer.top - .1));
    expect(inner.bottom, lessThanOrEqualTo(outer.bottom + .1));
  }

  void verifyParts(WidgetTester t, int seconds, String locale) {
    final parts = AppFormats(lookupAppLocalizations(Locale(locale)))
        .durationParts(seconds);
    final card = t.getRect(getSummary());
    Rect? last;
    for (var i = 0; i < parts.length; i++) {
      final finder = find.byKey(ValueKey('history-duration-part-$i'));
      final widget = t.widget<Text>(finder);
      expect(
        widget.textSpan!.toPlainText(),
        '${parts[i].value} ${parts[i].unit}',
      );
      expect(widget.softWrap, isFalse);
      expect(widget.maxLines, isNull);
      expect(widget.overflow, isNull);
      final paragraph = t.renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: widget.textSpan!.toPlainText().length,
        ),
      );
      for (final box in boxes) {
        expect(box.right, lessThanOrEqualTo(paragraph.size.width + .5));
        expect(box.left, greaterThanOrEqualTo(-.1));
      }
      final rect = t.getRect(finder);
      contained(card, rect);
      if (last != null) {
        expect(rect.overlaps(last), isFalse);
        expect(
          rect.top >= last.bottom || (rect.top - last.top).abs() < .1,
          isTrue,
        );
      }
      last = rect;
    }
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'full-width selected summary precedes recent, month and records',
    (t) async {
      await mount(t);
      final summary = t.getRect(getSummary());
      final week = t.getRect(
        find.ancestor(
          of: find.text('Workouts this week'),
          matching: find.byType(AppCard),
        ),
      );
      final month = t.getRect(
        find.ancestor(
          of: find.text('Workouts this month'),
          matching: find.byType(AppCard),
        ),
      );
      expect(week.top, month.top);
      expect(week.height, month.height);
      expect(week.width, month.width);
      expect(summary.left, week.left);
      expect(summary.right, month.right);
      expect(summary.top, greaterThan(week.bottom));
      final recent = find.textContaining('Latest workout:');
      final arrow = find.byTooltip('Previous month');
      expect(t.getTopLeft(recent).dy, greaterThan(summary.bottom));
      expect(t.getTopLeft(arrow).dy, greaterThan(t.getBottomLeft(recent).dy));
      final record = find.byKey(const ValueKey('history-session-2'));
      await t.ensureVisible(record);
      expect(t.getTopLeft(record).dy, greaterThan(t.getBottomLeft(arrow).dy));
      // Only the two count cards, one summary and the record card exist.
      expect(find.byType(AppCard), findsNWidgets(4));
      expect(
        t
            .widget<AppCard>(
              find.descendant(of: getSummary(), matching: find.byType(AppCard)),
            )
            .onTap,
        isNull,
      );
      verifyParts(t, 11520, 'en');
    },
  );

  testWidgets(
    'month changes only selected summary and records; empty states differ',
    (t) async {
      await mount(t);
      final initial = t.widget<HistorySummaryCard>(getSummary());
      expect(initial.completedSets, 63);
      final recent = t
          .widget<Text>(find.textContaining('Latest workout:'))
          .data;
      await t.tap(find.byTooltip('Previous month'));
      await t.pumpAndSettle();
      var card = t.widget<HistorySummaryCard>(getSummary());
      expect(card.month, DateTime(previous.year, previous.month));
      expect(card.durationSeconds, 3540);
      expect(card.completedSets, 4);
      expect(
        find.text(
          AppFormats(lookupAppLocalizations(const Locale('en'))).strings
              .historyMonthSummary(
                AppFormats(lookupAppLocalizations(const Locale('en')))
                    .month(previous),
              ),
        ),
        findsOneWidget,
      );
      expect(find.text(recent!), findsOneWidget);
      final countCard = find.ancestor(
        of: find.text('Workouts this month'),
        matching: find.byType(AppCard),
      );
      expect(
        find.descendant(of: countCard, matching: find.text('1')),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Previous month'));
      await t.pumpAndSettle();
      card = t.widget<HistorySummaryCard>(getSummary());
      expect(card.durationSeconds, 0);
      expect(card.completedSets, 0);
      expect(find.textContaining('No workouts'), findsOneWidget);
      expect(find.text(recent), findsOneWidget);
      repository.records = [];
      await mount(t, revision: 1);
      expect(t.widget<HistorySummaryCard>(getSummary()).durationSeconds, 0);
      expect(
        find.text(lookupAppLocalizations(const Locale('en')).noHistoryAll),
        findsOneWidget,
      );
    },
  );

  testWidgets('initial loading and failure never claim an empty summary', (
    t,
  ) async {
    final gate = Completer<void>();
    repository.nextLoadGate = gate;
    repository.failNextLoad = true;
    await mount(t);
    expect(getSummary(), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await t.pumpAndSettle();
    expect(getSummary(), findsNothing);
    await t.tap(
      find.text(lookupAppLocalizations(const Locale('en')).retryRefresh),
    );
    await t.pumpAndSettle();
    expect(t.widget<HistorySummaryCard>(getSummary()).durationSeconds, 11520);
  });

  testWidgets(
    'language, theme and scale changes retain selected month and values',
    (t) async {
      await mount(t);
      await t.tap(find.byTooltip('Previous month'));
      await t.pumpAndSettle();
      await mount(
        t,
        language: 'zh',
        brightness: Brightness.dark,
        preset: ThemeColorPreset.violet,
        scale: 1.6,
      );
      final card = t.widget<HistorySummaryCard>(getSummary());
      expect(card.month, DateTime(previous.year, previous.month));
      expect(card.durationSeconds, 3540);
      expect(card.completedSets, 4);
      verifyParts(t, 3540, 'zh');
    },
  );

  for (final language in ['en', 'zh']) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 1.3, 1.6]) {
        for (final seconds in [0, 3540, 11520, 445500]) {
          testWidgets('whole duration $language $width $scale $seconds', (
            t,
          ) async {
            repository.records = [sample(2, now, seconds, 63)];
            await mount(
              t,
              language: language,
              scale: scale,
              size: Size(width, 900),
            );
            verifyParts(t, seconds, language);
          });
        }
      }
    }
  }
  for (final preset in ThemeColorPreset.values) {
    for (final brightness in Brightness.values) {
      for (final size in [
        const Size(360, 640),
        const Size(740, 390),
        const Size(768, 1024),
      ]) {
        testWidgets(
          'theme and reachability ${preset.name} ${brightness.name} $size',
          (t) async {
            repository.records = [sample(2, now, 445500, 63)];
            await mount(
              t,
              scale: 1.6,
              brightness: brightness,
              preset: preset,
              size: size,
              reducedMotion: true,
              longLabels: true,
            );
            verifyParts(t, 445500, 'en');
            final summaryContext = t.element(getSummary());
            expect(
              summaryContext.appColors.accent,
              AppColors.forPreset(brightness, preset).accent,
            );
            final arrow = find.byTooltip('Previous month');
            await t.scrollUntilVisible(arrow, 160);
            await t.pumpAndSettle();
            await t.tap(arrow);
            await t.pumpAndSettle();
            expect(
              t.widget<HistorySummaryCard>(getSummary()).durationSeconds,
              0,
            );
            await t.tap(find.byTooltip('Next month'));
            await t.pumpAndSettle();
            expect(
              t.widget<HistorySummaryCard>(getSummary()).durationSeconds,
              445500,
            );
            final record = find.byKey(const ValueKey('history-session-2'));
            await t.scrollUntilVisible(record, 160);
            await Scrollable.ensureVisible(t.element(record), alignment: 1);
            await t.pumpAndSettle();
            expect(record.hitTestable(), findsOneWidget);
            expect(
              t.getBottomLeft(record).dy,
              lessThanOrEqualTo(size.height - 24),
            );
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'duration is announced once; month buttons have names, size and keyboard action',
    (t) async {
      final handle = t.ensureSemantics();
      await mount(t, language: 'zh');
      expect(find.bySemanticsLabel('训练时长，3 小时 12 分钟'), findsOneWidget);
      final node = t.getSemantics(find.bySemanticsLabel('训练时长，3 小时 12 分钟'));
      expect(node.childrenCount, 0);
      for (final label in ['上个月', '下个月']) {
        final button = find.byTooltip(label);
        final size = t.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(
        t.widget<HistorySummaryCard>(getSummary()).month,
        DateTime(previous.year, previous.month),
      );
      handle.dispose();
    },
  );
}
