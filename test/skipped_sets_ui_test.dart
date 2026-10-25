import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/history/history_page.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/settings/settings_page.dart';
import 'package:settrace/l10n/generated/app_localizations.dart';
import 'package:settrace/l10n/generated/app_localizations_en.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'rest_alert_repository_test.dart' show FakeAlertsPlatform;
import 'fixtures/long_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase db;
  late PlanRepository plans;
  late WorkoutRepository repo;
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'SetTrace',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    dir = await Directory.systemTemp.createTemp('settrace_skip_ui_');
    db = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    plans = PlanRepository(db.db);
    repo = WorkoutRepository(db.db);
    SharedPreferences.setMockInitialValues({'app_notice_seen_version': 3});
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<WorkoutSessionData> seed({int actions = 2, int rest = 0}) async {
    final id = await plans.createPlan('Plan');
    for (var i = 0; i < actions; i++) {
      await plans.addExercise(
        planId: id,
        name: 'Action $i',
        targetSets: 4,
        restBetweenSetsSeconds: rest,
        restAfterExerciseSeconds: 0,
      );
    }
    var s = await repo.start(id);
    for (var n = 0; n < 2; n++) {
      if (s.resting) s = await repo.skipRest(s.id);
      s = await repo.completeSet(
        s.id,
        expectedExerciseId: s.currentExercise.id,
        expectedSetNumber: s.currentSetNumber,
      );
    }
    return s;
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle(
      const Duration(milliseconds: 20),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  }

  Widget wrap(
    Widget child, {
    Locale locale = const Locale('zh'),
    bool dark = false,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark ? AppTheme.dark : AppTheme.light,
    home: child,
  );
  Future<void> tap(WidgetTester t, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.text(text),
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await settle(t);
  }

  testWidgets(
    'cancel keeps 2/4 and rest, confirmation advances, undo remains discoverable',
    (t) async {
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      final s = (await t.runAsync(() => seed(rest: 120)))!;
      await t.pumpWidget(wrap(WorkoutPage(workouts: repo, sessionId: s.id)));
      await settle(t);
      await tap(t, '跳过剩余 2 组');
      await tap(t, '取消');
      final cancelled = await t.runAsync(() => repo.getSession(s.id));
      expect(cancelled!.restEndAt, s.restEndAt);
      expect(cancelled.currentExercise.skippedSets, 0);
      await tap(t, '跳过剩余 2 组');
      await tap(t, '确认跳过剩余组');
      final skipped = await t.runAsync(() => repo.getSession(s.id));
      expect(skipped!.currentExercise.name, 'Action 1');
      expect(skipped.resting, false);
      await t.scrollUntilVisible(
        find.text('撤销最近一次跳过'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('撤销最近一次跳过'), findsOneWidget);
      await tap(t, '撤销最近一次跳过');
      await tap(t, '恢复待练组');
      final restored = await t.runAsync(() => repo.getSession(s.id));
      expect(restored!.currentSetNumber, 3);
      expect(restored.completedSets, 2);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('stale confirmation cannot skip newly advanced state', (t) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    final s = (await t.runAsync(() => seed()))!;
    await t.pumpWidget(wrap(WorkoutPage(workouts: repo, sessionId: s.id)));
    await settle(t);
    await tap(t, '跳过剩余 2 组');
    await t.runAsync(
      () => repo.completeSet(
        s.id,
        expectedExerciseId: s.currentExercise.id,
        expectedSetNumber: s.currentSetNumber,
      ),
    );
    await tap(t, '确认跳过剩余组');
    final latest = await t.runAsync(() => repo.getSession(s.id));
    expect(latest!.currentSetNumber, 4);
    expect(latest.currentExercise.skippedSets, 0);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'last action finishes at 50 percent and history distinguishes skipped',
    (t) async {
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      final s = (await t.runAsync(() => seed(actions: 1)))!;
      await t.pumpWidget(wrap(WorkoutPage(workouts: repo, sessionId: s.id)));
      await settle(t);
      await tap(t, '跳过剩余 2 组');
      await tap(t, '确认跳过剩余组');
      await tap(t, '继续训练');
      await t.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await settle(t);
      await t.scrollUntilVisible(
        find.byType(LinearProgressIndicator),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('workout-body')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      expect(find.text('全部组已完成'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      final saved = await t.runAsync(() => repo.finish(s.id));
      await t.pumpWidget(
        wrap(HistoryDetailPage(session: saved!, workouts: repo)),
      );
      await settle(t);
      expect(find.text('2 / 4 组完成'), findsOneWidget);
      expect(find.text('第 3 组 · 已跳过'), findsOneWidget);
      expect(find.text('第 4 组 · 已跳过'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'settings separates permission, preference and failed preference saving',
    (t) async {
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      final alertsRepo = RestAlertRepository(db.db);
      final platform = FakeAlertsPlatform(alertsRepo);
      final alerts = RestAlertService(alertsRepo, platform);
      await t.runAsync(() => alerts.configure(AppLocalizationsEn()));
      await t.pumpWidget(
        wrap(
          Scaffold(
            body: SettingsPage(
              alerts: alerts,
              mode: ThemeMode.light,
              onModeChanged: (_) {},
              locale: const Locale('zh'),
              onLocaleChanged: (_) async {},
            ),
          ),
        ),
      );
      await settle(t);
      final reminderToggle = find.widgetWithText(SwitchListTile, '休息结束提醒');
      await t.scrollUntilVisible(reminderToggle, 120);
      await t.pumpAndSettle();
      expect(find.textContaining('后台通知不可用'), findsOneWidget);
      await t.runAsync(
        () => db.db.execute(
          """CREATE TRIGGER fail_toggle BEFORE UPDATE ON rest_alert_preferences
      BEGIN SELECT RAISE(ABORT, 'test'); END""",
        ),
      );
      await t.tap(reminderToggle);
      await settle(t);
      expect(t.widget<SwitchListTile>(reminderToggle).value, true);
      expect(find.text('提醒设置保存失败，已保留原设置。'), findsOneWidget);
      expect(platform.permissionCalls, 0);
      await t.pumpWidget(const SizedBox.shrink());
      alerts.dispose();
    },
  );

  testWidgets(
    'notification navigation reuses latest page and rejects ended target',
    (t) async {
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      final s = (await t.runAsync(() => seed()))!;
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      await t.pumpWidget(
        SetTraceApp(
          plans: plans,
          workouts: repo,
          preferences: prefs!,
          initialLocale: const Locale('zh'),
        ),
      );
      await settle(t);
      final root = t.state<RootTabsState>(find.byType(RootTabs));
      unawaited(root.openFromNotification(s.id));
      await settle(t);
      expect(find.byType(WorkoutPage), findsOneWidget);
      unawaited(root.openFromNotification(s.id));
      await settle(t);
      expect(find.byType(WorkoutPage), findsOneWidget);
      await t.runAsync(() => repo.finish(s.id));
      unawaited(root.openFromNotification(s.id));
      await settle(t);
      expect(find.text('该训练已结束或已不可用。'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('saving from notification removes the stale active home card', (
    t,
  ) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    final s = (await t.runAsync(() => seed(actions: 1)))!;
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    await t.pumpWidget(
      SetTraceApp(
        plans: plans,
        workouts: repo,
        preferences: prefs!,
        initialLocale: const Locale('zh'),
      ),
    );
    await settle(t);
    expect(find.text('继续训练'), findsOneWidget);
    final root = t.state<RootTabsState>(find.byType(RootTabs));
    unawaited(root.openFromNotification(s.id));
    await settle(t);
    await tap(t, '跳过剩余 2 组');
    await tap(t, '确认跳过剩余组');
    await tap(t, '保存已完成');
    await settle(t);
    expect(find.byType(WorkoutPage), findsNothing);
    expect(find.text('继续训练'), findsNothing);
    expect(
      (await t.runAsync(() => repo.getSession(s.id)))!.status,
      'completed',
    );
  });

  testWidgets('double taps create one confirmation and one skip batch', (
    t,
  ) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    final s = (await t.runAsync(() => seed()))!;
    await t.pumpWidget(wrap(WorkoutPage(workouts: repo, sessionId: s.id)));
    await settle(t);
    await t.ensureVisible(find.text('跳过剩余 2 组'));
    await t.pumpAndSettle();
    final skipPoint = t.getCenter(find.text('跳过剩余 2 组'));
    await t.tapAt(skipPoint);
    await t.tapAt(skipPoint);
    await settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    final confirmPoint = t.getCenter(find.text('确认跳过剩余组'));
    await t.tapAt(confirmPoint);
    await t.tapAt(confirmPoint);
    await settle(t);
    final latest = (await t.runAsync(() => repo.getSession(s.id)))!;
    expect(latest.currentExercise.name, 'Action 1');
    expect(latest.exercises.first.skippedSets, 2);
    expect(
      (await t.runAsync(() => db.db.query('session_skip_batches')))!.length,
      1,
    );
  });

  for (final language in ['en', 'zh']) {
    testWidgets('360 dp scaled dark skip dialog is usable in $language', (
      t,
    ) async {
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      final s = (await t.runAsync(() => seed()))!;
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        wrap(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: WorkoutPage(workouts: repo, sessionId: s.id),
          ),
          locale: Locale(language),
          dark: true,
        ),
      );
      await settle(t);
      await tap(t, language == 'en' ? 'Skip remaining 2 sets' : '跳过剩余 2 组');
      expect(t.takeException(), isNull);
      await tap(t, language == 'en' ? 'Cancel' : '取消');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('long translated skip copy is readable at 360 dp and 1.6 scale', (
    t,
  ) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    final s = (await t.runAsync(() => seed()))!;
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final strings = LongStrings();
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.dark,
        localizationsDelegates: [
          const LongDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: WorkoutPage(workouts: repo, sessionId: s.id),
      ),
    );
    await settle(t);
    await tap(t, strings.skipRemainingSets(2));
    expect(t.takeException(), isNull);
    await tap(t, strings.cancel);
    expect(t.takeException(), isNull);
  });
}
