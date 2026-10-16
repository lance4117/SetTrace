import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/rest_alerts/rest_alert_platform.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/rest_alerts/rest_reminder_dialog.dart';
import 'package:settrace/features/rest_alerts/rest_reminder_controls.dart';
import 'package:settrace/l10n/generated/app_localizations.dart';
import 'package:settrace/l10n/generated/app_localizations_en.dart';

import 'rest_alert_repository_test.dart' show FakeAlertsPlatform;

class PreviewPlatform extends FakeAlertsPlatform {
  PreviewPlatform(super.repo);
  final previews = <String>[];
  @override
  Future<void> preview(String sound, String locale) async {
    previews.add('$sound:$locale');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase db;
  late WorkoutRepository workouts;
  late RestAlertRepository repo;
  late RestAlertService alerts;
  late PreviewPlatform platform;
  late WorkoutSessionData session;
  late DateTime now;
  bool appOwned = false;
  setUp(() async {
    appOwned = false;
    PackageInfo.setMockInitialValues(
      appName: 'SetTrace',
      packageName: 'test',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({'app_notice_seen_version': 1});
    dir = await Directory.systemTemp.createTemp('reminder_ui_');
    db = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    now = DateTime.utc(2026, 10, 16);
    workouts = WorkoutRepository(db.db, clock: () => now);
    repo = RestAlertRepository(db.db, clock: () => now);
    platform = PreviewPlatform(repo);
    alerts = RestAlertService(repo, platform);
    final plans = PlanRepository(db.db);
    final id = await plans.createPlan('Workout');
    await plans.addExercise(
      planId: id,
      name: '坐姿划船 / Seated cable row',
      targetSets: 4,
      restBetweenSetsSeconds: 60,
      restAfterExerciseSeconds: 60,
    );
    session = await workouts.start(id);
    session = await workouts.completeSet(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedSetNumber: session.currentSetNumber,
    );
    await repo.markPermissionRequested();
    await alerts.configure(AppLocalizationsEn());
  });
  tearDown(() async {
    if (!appOwned) alerts.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<void> flush(WidgetTester t) async {
    for (var n = 0; n < 100; n++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
      if (n >= 7 &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await t.pumpAndSettle();
  }

  Future<void> expire(WidgetTester t) async {
    now = now.add(const Duration(seconds: 60));
    final pending = alerts.synchronize();
    await flush(t);
    await pending;
  }

  Widget wrap(
    Widget child, {
    bool dark = false,
    String language = 'en',
    double scale = 1,
    ThemeColorPreset preset = ThemeColorPreset.teal,
  }) => MaterialApp(
    theme: AppTheme.forPreset(
      dark ? Brightness.dark : Brightness.light,
      preset,
    ),
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
  Future<void> showDialogFor(
    WidgetTester t, {
    bool dark = false,
    String language = 'en',
    double scale = 1,
    ThemeColorPreset preset = ThemeColorPreset.teal,
  }) async {
    await expire(t);
    await t.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => RestReminderDialog(
                alerts: alerts,
                event: alerts.awaiting.single,
              ),
            ),
            child: const Text('Show'),
          ),
        ),
        dark: dark,
        language: language,
        scale: scale,
        preset: preset,
      ),
    );
    await t.tap(find.text('Show'));
    await t.pumpAndSettle();
  }

  testWidgets('dialog survives repeat and barrier, back only dismisses', (
    t,
  ) async {
    await showDialogFor(t);
    expect(find.byType(RestReminderDialog), findsOneWidget);
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(find.byType(RestReminderDialog), findsOneWidget);
    now = now.add(const Duration(seconds: 10));
    final pending = alerts.synchronize();
    await flush(t);
    await pending;
    expect(platform.sounds, hasLength(2));
    expect(find.byType(RestReminderDialog), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RestReminderDialog), findsNothing);
    expect(alerts.awaiting, hasLength(1));
    expect(
      (await t.runAsync(() => workouts.getSession(session.id)))!.completedSets,
      1,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed acknowledgment stays actionable and retry does not complete a set',
    (t) async {
      await showDialogFor(t);
      await t.runAsync(
        () => db.db.execute(
          "CREATE TRIGGER fail_ack BEFORE UPDATE OF acknowledged_at ON rest_alerts BEGIN SELECT RAISE(ABORT,'fail'); END",
        ),
      );
      await t.tap(find.text('Got it, stop reminders'));
      await flush(t);
      expect(
        find.text('Could not stop the reminder. Try again.'),
        findsOneWidget,
      );
      expect(find.byType(RestReminderDialog), findsOneWidget);
      await t.runAsync(() => db.db.execute('DROP TRIGGER fail_ack'));
      await t.tap(find.text('Got it, stop reminders'));
      await flush(t);
      expect(find.byType(RestReminderDialog), findsNothing);
      expect(alerts.awaiting, isEmpty);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!
            .completedSets,
        1,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'interval draft cancels, saves, and repeat toggle hides interval',
    (t) async {
      await t.pumpWidget(
        wrap(
          SingleChildScrollView(child: RestReminderControls(alerts: alerts)),
        ),
      );
      await t.tap(find.text('Reminder interval'));
      await t.pumpAndSettle();
      await t.tap(find.text('30 seconds'));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(alerts.options.interval, 10);
      await t.tap(find.text('Reminder interval'));
      await t.pumpAndSettle();
      await t.tap(find.text('30 seconds'));
      await t.tap(find.text('Save'));
      await flush(t);
      expect(alerts.options.interval, 30);
      await t.tap(find.widgetWithText(SwitchListTile, 'Repeat reminders'));
      await flush(t);
      expect(alerts.options.repeat, false);
      expect(find.text('Reminder interval'), findsNothing);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!.restEndAt,
        session.restEndAt,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'preview is independent of selection and settings save failure retains draft',
    (t) async {
      await t.pumpWidget(
        wrap(
          SingleChildScrollView(child: RestReminderControls(alerts: alerts)),
        ),
      );
      await t.tap(find.text('Reminder sound'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Preview Double beep'));
      await flush(t);
      expect(platform.previews, ['double_beep:en']);
      expect(alerts.options.sound, 'three_tone');
      await t.tap(find.text('Double beep'));
      await t.runAsync(
        () => db.db.execute(
          "CREATE TRIGGER fail_pref BEFORE UPDATE ON rest_alert_preferences BEGIN SELECT RAISE(ABORT,'fail'); END",
        ),
      );
      await t.tap(find.text('Save'));
      await flush(t);
      expect(alerts.options.sound, 'three_tone');
      expect(find.text('Save'), findsOneWidget);
      await t.runAsync(() => db.db.execute('DROP TRIGGER fail_pref'));
      await t.tap(find.text('Save'));
      await flush(t);
      expect(alerts.options.sound, 'double_beep');
      await t.pumpWidget(const SizedBox());
    },
  );
  Future<void> pumpApp(WidgetTester t) async {
    appOwned = true;
    final preferences = await SharedPreferences.getInstance();
    await t.pumpWidget(
      SetTraceApp(
        plans: PlanRepository(db.db),
        workouts: workouts,
        preferences: preferences,
        initialLocale: const Locale('en'),
        alerts: alerts,
      ),
    );
    await flush(t);
  }

  Future<void> closeApp(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    final pending = alerts.synchronize();
    await flush(t);
    await pending;
  }

  testWidgets(
    'automatic dialog waits for editing and notification confirms after page presentation',
    (t) async {
      await pumpApp(t);
      final navigator = t.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'editing'),
            builder: (_) => const Scaffold(body: TextField()),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'draft remains');
      await expire(t);
      await flush(t);
      expect(find.byType(RestReminderDialog), findsNothing);
      expect(find.text('draft remains'), findsOneWidget);
      navigator.pop();
      await flush(t);
      expect(find.byType(RestReminderDialog), findsOneWidget);
      final e = alerts.awaiting.single;
      alerts.onTapDetails!(
        RestAlertTap(session.id, eventId: e.id, revision: e.revision),
      );
      await flush(t);
      for (var i = 0; i < 100 && alerts.awaiting.isNotEmpty; i++) {
        await flush(t);
      }
      expect(find.byType(WorkoutPage), findsOneWidget);
      expect(find.byType(RestReminderDialog), findsNothing);
      expect(alerts.awaiting, isEmpty);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!
            .completedSets,
        1,
      );
      await closeApp(t);
    },
  );
  testWidgets(
    'back dismisses only the automatic dialog and page stop remains available',
    (t) async {
      await pumpApp(t);
      final root = t.state<RootTabsState>(find.byType(RootTabs));
      unawaited(root.openWorkout(session));
      await flush(t);
      await expire(t);
      await flush(t);
      expect(find.byType(RestReminderDialog), findsOneWidget);
      await t.binding.handlePopRoute();
      await flush(t);
      expect(find.byType(WorkoutPage), findsOneWidget);
      expect(find.byType(RestReminderDialog), findsNothing);
      now = now.add(const Duration(seconds: 10));
      final pending = alerts.synchronize();
      await flush(t);
      await pending;
      expect(find.byType(RestReminderDialog), findsNothing);
      await t.ensureVisible(find.text('Stop this reminder'));
      await t.tap(find.text('Stop this reminder'));
      await t.tap(find.text('Stop this reminder'));
      await flush(t);
      expect(
        find.text('Could not stop the reminder. Try again.'),
        findsNothing,
      );
      expect(alerts.awaiting, isEmpty);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!
            .completedSets,
        1,
      );
      await closeApp(t);
    },
  );
  testWidgets(
    'keyboard confirms once with reduced motion and keeps training progress',
    (t) async {
      t.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        t.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await showDialogFor(t);
      final context = t.element(find.text('Got it, stop reminders'));
      final focus = Focus.of(context);
      focus.requestFocus();
      await t.pump();
      expect(focus.hasFocus, true);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await flush(t);
      expect(find.byType(RestReminderDialog), findsNothing);
      expect(alerts.awaiting, isEmpty);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!
            .completedSets,
        1,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final preset in ThemeColorPreset.values) {
      for (final dark in [false, true]) {
        for (final language in ['zh', 'en']) {
          testWidgets(
            'dialog fits ${width}dp short screen 1.6 type $language $preset dark=$dark',
            (t) async {
              t.view.physicalSize = Size(width, 600);
              t.view.devicePixelRatio = 1;
              addTearDown(t.view.resetPhysicalSize);
              addTearDown(t.view.resetDevicePixelRatio);
              await showDialogFor(
                t,
                dark: dark,
                language: language,
                scale: 1.6,
                preset: preset,
              );
              expect(t.takeException(), isNull);
              final button = find.text(
                language == 'zh' ? '知道了，停止提醒' : 'Got it, stop reminders',
              );
              await t.ensureVisible(button);
              expect(button, findsOneWidget);
              final semantics = t.ensureSemantics();
              expect(
                find.bySemanticsLabel(
                  language == 'zh' ? '知道了，停止提醒' : 'Got it, stop reminders',
                ),
                findsOneWidget,
              );
              semantics.dispose();
              await t.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  }
}
