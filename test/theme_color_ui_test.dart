import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_controller.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/settings/theme_color_section.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/l10n/localization.dart';

import 'fixtures/long_localizations.dart';
import 'theme_color_controller_test.dart' show ControlledColors;
import 'rest_alert_repository_test.dart' show FakeAlertsPlatform;

import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/rest_alerts/rest_alert_platform.dart';

class CountSchedules extends FakeAlertsPlatform {
  CountSchedules(super.repo);
  int calls = 0;
  @override
  Future<RestAlertCapabilities> capabilities() async =>
      const RestAlertCapabilities(notifications: true, exact: true);
  @override
  Future<void> schedule(RestAlertEvent event) async {
    calls++;
    await super.schedule(event);
  }
}

Future<void> flush(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final width in [360.0, 430.0]) {
    for (final brightness in Brightness.values) {
      for (final language in ['en', 'zh']) {
        for (final preset in ThemeColorPreset.values) {
          for (final scale in [1.0, 1.3, 1.6]) {
            testWidgets('card $width $brightness $language $preset $scale', (
              t,
            ) async {
              t.view.physicalSize = Size(width, 800);
              t.view.devicePixelRatio = 1;
              addTearDown(t.view.resetPhysicalSize);
              addTearDown(t.view.resetDevicePixelRatio);
              final store = ControlledColors()..value = preset.name;
              final c = ThemeColorController(store);
              await t.pumpWidget(
                AnimatedBuilder(
                  animation: c,
                  builder: (context, _) => MaterialApp(
                    theme: AppTheme.forPreset(brightness, c.selected),
                    themeAnimationDuration: Duration.zero,
                    locale: Locale(language),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    home: MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Scaffold(
                        body: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ThemeColorSection(controller: c),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await t.pumpAndSettle();
              final semantics = t.ensureSemantics();
              final strings = lookupAppLocalizations(Locale(language));
              for (final name in [
                strings.themeColorTeal,
                strings.themeColorBlue,
                strings.themeColorViolet,
                strings.themeColorGraphite,
              ]) {
                expect(find.text(name), findsNothing);
              }
              final firstY = t
                  .getTopLeft(find.byKey(const ValueKey('theme-color-teal')))
                  .dy;

              for (final option in ThemeColorPreset.values) {
                final finder = find.byKey(
                  ValueKey('theme-color-${option.name}'),
                );
                expect(t.getSize(finder).width, greaterThanOrEqualTo(48));
                expect(t.getSize(finder).height, greaterThanOrEqualTo(48));
                expect(t.getTopLeft(finder).dy, firstY);
                expect(t.getSemantics(finder).label, isNotEmpty);

                expect(
                  t
                      .getSemantics(finder)
                      .flagsCollection
                      .isSelected
                      .toBoolOrNull(),
                  option == preset,
                );
              }
              final next = ThemeColorPreset.values[(preset.index + 1) % 4];
              final item = find.byKey(ValueKey('theme-color-${next.name}'));
              await t.ensureVisible(item);
              await t.tap(item);
              await t.pump();
              expect(c.selected, next);
              expect(c.saving, isTrue);
              store.pending.single.complete(false);
              await t.pumpAndSettle();
              expect(c.selected, preset);
              expect(c.failedTarget, next);
              final l = lookupAppLocalizations(Locale(language));
              expect(find.text(l.themeColorSaveFailed), findsOneWidget);
              await t.ensureVisible(find.text(l.retry));
              await t.tap(find.text(l.retry));
              store.pending.last.complete(true);
              await t.pumpAndSettle();
              expect(c.committed, next);
              expect(find.text(l.themeColorSaveFailed), findsNothing);
              expect(t.takeException(), isNull);
              semantics.dispose();
              await t.pumpWidget(const SizedBox());
              c.dispose();
            });
          }
        }
      }
    }
  }
  for (final size in [
    const Size(360, 640),
    const Size(740, 390),
    const Size(768, 1024),
  ]) {
    testWidgets('long text, keyboard and reduced motion $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = ControlledColors();
      final c = ThemeColorController(store);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            const LongDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.6),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ThemeColorSection(controller: c),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final graphite = find.byKey(const ValueKey('theme-color-graphite'));
      await t.ensureVisible(graphite);
      // Traverse to a real InkWell focus and activate using the keyboard.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      // The first option is already selected; tab advances to the next option.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(c.selected, ThemeColorPreset.blue);
      store.pending.single.complete(false);
      await t.pumpAndSettle();
      expect(find.text(LongStrings().themeColorSaveFailed), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets(
    'root preview, navigation, rest and modal drafts survive failure/retry',
    (t) async {
      sqfliteFfiInit();
      SharedPreferences.setMockInitialValues({
        'app_notice_seen_version': 3,
        'app_locale': 'en',
      });
      final prefs = await SharedPreferences.getInstance();
      final db = (await t.runAsync(
        () => AppDatabase.open(
          filePath: inMemoryDatabasePath,
          factory: databaseFactoryFfi,
        ),
      ))!;
      final plans = PlanRepository(db.db), workouts = WorkoutRepository(db.db);
      final plan = (await t.runAsync(() => plans.createPlan('Palette QA')))!;
      await t.runAsync(
        () => plans.addExercise(
          planId: plan,
          name: 'Exercise',
          targetSets: 3,
          restBetweenSetsSeconds: 120,
          restAfterExerciseSeconds: 0,
        ),
      );
      final session = (await t.runAsync(() => workouts.start(plan)))!;
      await t.runAsync(
        () => workouts.completeSet(
          session.id,
          expectedExerciseId: session.currentExercise.id,
          expectedSetNumber: 1,
        ),
      );
      final before = (await t.runAsync(() => workouts.getSession(session.id)))!;
      var platform = CountSchedules(RestAlertRepository(db.db));
      final store = ControlledColors();
      Widget root() => SetTraceApp(
        plans: plans,
        workouts: workouts,
        preferences: prefs,
        initialLocale: const Locale('en'),
        themeColorStore: store,
        alerts: RestAlertService(platform.repo, platform),
      );
      await t.pumpWidget(root());
      await flush(t);
      var scheduledAtStart = platform.calls;
      expect(scheduledAtStart, greaterThanOrEqualTo(1));
      final tabs = t.widget<RootTabs>(find.byType(RootTabs));
      final c = tabs.themeColors!;
      final state = t.state<RootTabsState>(find.byType(RootTabs));
      scheduledAtStart = platform.calls;
      await t.tap(find.text('Settings').last);
      await flush(t);
      await t.pumpAndSettle();
      final blue = find.byKey(const ValueKey('theme-color-blue'));
      await t.ensureVisible(blue);
      await t.tap(blue);
      await t.pump(const Duration(milliseconds: 250));
      expect(store.pending.single.isCompleted, isFalse);
      expect(
        t
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary,
        ThemeColorPreset.blue.palette(Brightness.light).accent,
      );
      await t.tap(find.text('History').last);
      await flush(t);
      await t.pumpAndSettle();
      store.pending.single.complete(false);
      await flush(t);
      await t.pumpAndSettle();
      expect(c.selected, ThemeColorPreset.teal);
      expect(platform.calls, scheduledAtStart);
      // Language changes retranslate the existing failure without retrying it.
      unawaited(tabs.onLocaleChanged(const Locale('zh')));
      await flush(t);
      expect(c.failedTarget, ThemeColorPreset.blue);
      expect(store.writes.length, 1);
      unawaited(tabs.onLocaleChanged(const Locale('en')));
      await flush(t);
      scheduledAtStart = platform.calls;
      await t.tap(find.text('Settings').last);
      await flush(t);
      await t.pumpAndSettle();
      final retry = find.descendant(
        of: find.byType(ThemeColorSection),
        matching: find.text('Retry'),
      );
      await t.ensureVisible(retry);
      await t.tap(retry);
      store.pending.last.complete(true);
      await flush(t);
      await t.pumpAndSettle();
      expect(c.committed, ThemeColorPreset.blue);
      final after = (await t.runAsync(() => workouts.getSession(session.id)))!;
      expect(after.restEndAt, before.restEndAt);
      expect(after.id, before.id);
      expect(after.completedSets, before.completedSets);
      expect(
        after.exercises.map((e) => e.skippedSets),
        before.exercises.map((e) => e.skippedSets),
      );
      expect(platform.calls, scheduledAtStart);
      // A modal and its controller keep identity while the app theme changes.
      final input = TextEditingController(text: 'unsaved draft');
      final context = t.element(find.byType(Scaffold).first);
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(content: TextField(controller: input)),
      );
      await flush(t);
      await t.pumpAndSettle();
      final modal = t.element(find.byType(TextField));
      c.select(ThemeColorPreset.violet);
      await t.pump(const Duration(milliseconds: 250));
      expect(t.element(find.byType(TextField)), same(modal));
      expect(input.text, 'unsaved draft');
      store.pending.last.complete(true);
      await flush(t);
      await t.pumpAndSettle();
      Navigator.of(t.element(find.byType(TextField))).pop();
      await flush(t);
      await t.pumpAndSettle();
      unawaited(state.openFromNotification(session.id));
      await flush(t);
      expect(state.openSessionId, session.id);
      expect(c.selected, ThemeColorPreset.violet);
      expect(t.state<RootTabsState>(find.byType(RootTabs)), same(state));
      await t.pumpWidget(const SizedBox());
      input.dispose();
      platform = CountSchedules(RestAlertRepository(db.db));
      await t.pumpWidget(root());
      await flush(t);
      expect(
        t.widget<RootTabs>(find.byType(RootTabs)).themeColors!.selected,
        ThemeColorPreset.violet,
      );
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    },
  );
}
