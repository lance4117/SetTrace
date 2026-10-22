import 'package:package_info_plus/package_info_plus.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:settrace/app/app.dart';
import 'package:settrace/core/widgets/app_bottom_nav.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plans_page.dart';
import 'package:settrace/features/plans/exercise_editor_page.dart';
import 'package:settrace/features/plans/plan_models.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_pages.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/session_order_sheet.dart';
import 'package:settrace/features/history/history_page.dart';
import 'package:settrace/features/rest_alerts/rest_alert_platform.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/settings/settings_page.dart';
import 'package:settrace/l10n/localization.dart';

/// App-owned scenes. C03 is system-owned and verified separately on Android.
const focusSceneIds = [
  'P01',
  'P02',
  'P03',
  'P04',
  'P05',
  'P06',
  'W01',
  'W02',
  'W03',
  'W04',
  'W05',
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
  'H03',
  'H04',
  'H05',
  'C01',
  'C02',
  'C04',
  'D01',
  'D02',
  'D03',
  'D04',
  'D05',
  'D06',
  'D07',
  'D08',
  'D09',
  'D10',
  'D11',
  'D12',
  'D13',
  'D14',
];

class PreviewTransfer implements PlanTransferPlatform {
  String? text;
  @override
  Future<void> copyText(String text) async {}
  @override
  Future<String?> readClipboard() async => text;
  @override
  Future<SavedPlanFile> saveFile(String text) async =>
      const SavedPlanFile('preview.settrace.json', 'downloads');
  @override
  Future<String?> pickFile() async => text;
}

class PreviewAlerts extends RestAlertPlatform {
  PreviewAlerts({this.allowed = true, this.exact = true, this.fail = false});
  final bool allowed, exact, fail;
  @override
  Future<void> initialize(
    String path,
    String channel,
    String description,
  ) async {
    if (fail) throw StateError('injected platform failure');
  }

  @override
  Future<RestAlertCapabilities> capabilities() async =>
      RestAlertCapabilities(notifications: allowed, exact: exact);
  @override
  Future<void> schedule(RestAlertEvent event) async {}
  @override
  Future<void> deliver(RestAlertEvent event) async {}
  @override
  Future<void> cancelExcept(Set<int> ids) async {}
  @override
  Future<void> requestNotifications() async {}
  @override
  Future<void> openSettings({required bool exact}) async {}
  @override
  Future<int?> takeInitialTap() async => null;
}

class FocusScene {
  FocusScene(
    this.id,
    this.directory,
    this.database,
    this.plans,
    this.workouts,
    this.locale,
  );
  final String id;
  final Directory directory;
  final AppDatabase database;
  final PlanRepository plans;
  final WorkoutRepository workouts;
  final Locale locale;
  bool dark = false;
  Widget root(Widget body, int index) => Scaffold(
    body: body,
    bottomNavigationBar: AppBottomNav(index: index, onChanged: (_) {}),
  );
  WorkoutPlan? plan;
  WorkoutSessionData? session, history;
  RestAlertService? alerts;
  final transfer = PreviewTransfer();
  late SharedPreferences prefs;
  String get base => switch (id) {
    'D01' || 'D12' => 'P01',
    'D02' || 'D03' => 'P02',
    'D04' => 'P03',
    'D05' || 'D06' || 'D08' => 'W01',
    'D07' => 'W02',
    'D09' => 'W05',
    'D10' => 'P04',
    'D11' => 'W03',
    'D13' => 'H02',
    'D14' => 'S02',
    _ => id,
  };
  static Future<FocusScene> create(
    String id,
    Locale locale, {
    DatabaseFactory? factory,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'settrace_focus_scene_',
    );
    final database = await AppDatabase.open(
      filePath: '${directory.path}/scene.db',
      factory: factory,
    );
    final f = FocusScene(
      id,
      directory,
      database,
      PlanRepository(database.db),
      WorkoutRepository(database.db),
      locale,
    );
    PackageInfo.setMockInitialValues(
      appName: 'SetTrace',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    f.prefs = await SharedPreferences.getInstance();
    await f.prefs.setInt('app_notice_seen_version', 2);
    await f.seed();
    return f;
  }

  Future<void> seed() async {
    if (['P05', 'H05'].contains(base)) return;
    final planId = await plans.createPlan('练背 · Back');
    if (base != 'P06') {
      for (var i = 0; i < (base == 'W06' ? 1 : 3); i++) {
        await plans.addExercise(
          planId: planId,
          name: [
            '高位下拉 · Lat pulldown',
            '坐姿划船 · Seated row',
            '二头弯举 · Biceps curl',
          ][i],
          targetSets: 4,
          restBetweenSetsSeconds: base == 'W03' ? 120 : 0,
          restAfterExerciseSeconds: base == 'W04' ? 150 : 0,
          defaultWeightKg: i == 0 ? 45.5 : null,
        );
      }
    }
    plan = (await plans.getPlan(planId))!;
    transfer.text = PlanTransferCodec().encode(
      PlanTransferDocument(await plans.exportPlans({planId})),
    );
    final needsSession =
        base.startsWith('W') ||
        base.startsWith('S') ||
        ['P01', 'H01', 'H02', 'H03', 'H04'].contains(base) ||
        id == 'D10';
    if (needsSession) {
      session = await workouts.start(planId);
      final count = base == 'W02'
          ? 0
          : base == 'W04'
          ? 4
          : 2;
      for (var i = 0; i < count; i++) {
        if (session!.resting) session = await workouts.skipRest(session!.id);
        session = await workouts.completeSet(
          session!.id,
          expectedExerciseId: session!.currentExercise.id,
          expectedSetNumber: session!.currentSetNumber,
        );
      }
      if (['W05', 'W06', 'H02', 'H04'].contains(base)) {
        session = await workouts.skipRemainingSets(
          session!.id,
          expectedExerciseId: session!.currentExercise.id,
          expectedToken: session!.reorderToken,
        );
      }
      if (base == 'H02') {
        while (session!.hasPendingSets) {
          if (session!.resting) session = await workouts.skipRest(session!.id);
          session = await workouts.completeSet(
            session!.id,
            expectedExerciseId: session!.currentExercise.id,
            expectedSetNumber: session!.currentSetNumber,
          );
        }
      }
      if (['H01', 'H02', 'H03', 'H04'].contains(base)) {
        if (base == 'H04') {
          session = await workouts.completeSet(
            session!.id,
            expectedExerciseId: session!.currentExercise.id,
            expectedSetNumber: session!.currentSetNumber,
          );
        }
        history = await workouts.finish(session!.id);
        if (base == 'H01') {
          // A realistic monthly duration exposes the former narrow-grid bug.
          await database.db.update(
            'workout_sessions',
            {'duration_seconds': 11520},
            where: 'id = ?',
            whereArgs: [history!.id],
          );
          history = await workouts.getSession(history!.id);
        }
      }
    }
    if (base.startsWith('C') || id == 'D11') {
      alerts = RestAlertService(
        RestAlertRepository(database.db),
        PreviewAlerts(
          allowed: base != 'C02' && id != 'D11',
          exact: base != 'C02',
          fail: base == 'C04',
        ),
      );
      try {
        await alerts!.configure(lookupAppLocalizations(locale));
      } catch (_) {}
    }
  }

  Widget get page {
    if (id == 'D11') {
      return SetTraceApp(
        plans: plans,
        workouts: workouts,
        preferences: prefs,
        initialLocale: locale,
        alerts: alerts,
      );
    }
    if (base == 'P01' || base == 'P05') {
      return root(
        PlansPage(
          plans: plans,
          workouts: workouts,
          onOpenWorkout: (_) async {},
          transferPlatform: transfer,
        ),
        0,
      );
    }
    if (base == 'P02' || base == 'P06') {
      return PlanDetailPage(
        planId: plan!.id,
        plans: plans,
        workouts: workouts,
        onOpenWorkout: (_) async {},
      );
    }
    if (base == 'P03') {
      return ExerciseEditorPage(
        plans: plans,
        planId: plan!.id,
        exercise: plan!.exercises.first,
      );
    }
    if (base == 'P04') {
      return PrepPage(
        plan: plan!,
        workouts: workouts,
        onOpenWorkout: (_) async {},
      );
    }
    if (base.startsWith('W') || base == 'S01') {
      return WorkoutPage(workouts: workouts, sessionId: session!.id);
    }
    if (base == 'S02' || base == 'S03') {
      return Scaffold(
        body: SessionOrderSheet(
          session: session!,
          selectNext: base == 'S03',
          onSave: (baseline, ids) => workouts.reorder(
            baseline.id,
            ids,
            expectedToken: baseline.reorderToken,
          ),
          onReload: () => workouts.getSession(session!.id),
        ),
      );
    }
    if (base == 'S04') {
      return SessionExerciseEditorPage(
        workouts: workouts,
        sessionId: session!.id,
        exercise: session!.exercises[1],
        expectedToken: session!.reorderToken,
      );
    }
    if (base == 'X01') return PlanExportPage(plans: plans, platform: transfer);
    if (base.startsWith('X')) {
      return PlanImportPage(plans: plans, platform: transfer);
    }
    if (['H01', 'H03', 'H05'].contains(base)) {
      return root(HistoryPage(workouts: workouts, revision: 0), 1);
    }
    if (base == 'H02' || base == 'H04') {
      return HistoryDetailPage(session: history!, workouts: workouts);
    }
    return root(
      SettingsPage(
        mode: dark ? ThemeMode.dark : ThemeMode.light,
        onModeChanged: (_) async {},
        locale: locale,
        onLocaleChanged: (_) async {},
        alerts: alerts,
      ),
      2,
    );
  }

  Future<void> close() async {
    if (id != 'D11') alerts?.dispose();
    await database.close();
    await directory.delete(recursive: true);
  }
}

Future<void> settleFocus(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 12)),
    );
    await t.pump(const Duration(milliseconds: 80));
  }
  if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
    await t.pumpAndSettle(
      const Duration(milliseconds: 20),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  } else {
    // A pending start deliberately remains busy while its conflict dialog is open.
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> tapFocus(WidgetTester t, Finder finder) async {
  if (finder.evaluate().isEmpty || finder.hitTestable().evaluate().isEmpty) {
    final scrolls = find.byType(Scrollable);
    if (scrolls.evaluate().isNotEmpty) {
      await t.scrollUntilVisible(
        finder,
        120,
        scrollable: scrolls.first,
        maxScrolls: 30,
      );
    }
  }
  await t.ensureVisible(finder.last);
  await t.pumpAndSettle();
  await t.tap(finder.last);
  await settleFocus(t);
}

Future<void> prepareFocusScene(WidgetTester t, FocusScene f) async {
  final l = lookupAppLocalizations(f.locale);
  if (f.base == 'W06' && find.byType(AlertDialog).evaluate().isNotEmpty) {
    await tapFocus(t, find.text(l.resumeWorkout));
  }
  if (f.id == 'S01') await tapFocus(t, find.text(l.allExercisesEdit));
  if (f.base == 'X03' || f.base == 'X04') {
    await tapFocus(t, find.text(l.chooseFile));
    if (f.base == 'X04') await tapFocus(t, find.text(l.viewExerciseConfig));
  }
  if (f.base == 'H03') await tapFocus(t, find.byTooltip(l.previousMonth));
  if (f.id == 'D01') {
    // Do not await the dialog future; it completes when the modal closes.
    final context = t.element(find.byType(PlansPage));
    askPlanName(
      context,
      onSave: (name) async {
        await f.plans.createPlan(name);
      },
    );
    await settleFocus(t);
  }
  if (f.id == 'D02' || f.id == 'D03') {
    await tapFocus(t, find.byType(PopupMenuButton<String>));
    await tapFocus(t, find.text(f.id == 'D02' ? l.rename : l.deletePlan));
  }
  if (f.id == 'D04') await tapFocus(t, find.text(l.delete));
  if (['D05', 'D06', 'D07'].contains(f.id)) {
    await tapFocus(t, find.text(l.exitWorkout));
    if (f.id == 'D06') await tapFocus(t, find.text(l.discard));
  }
  if (f.id == 'D08') {
    await tapFocus(
      t,
      find.text(l.skipRemainingSets(f.session!.currentExercise.pendingSets)),
    );
  }
  if (f.id == 'D09') await tapFocus(t, find.text(l.undoLastSkip));
  if (f.id == 'D10') await tapFocus(t, find.text(l.startWorkout));
  if (f.id == 'D11') await tapFocus(t, find.text(l.resumeWorkout));
  if (f.id == 'D12') await tapFocus(t, find.byTooltip(l.transferMenu));
  if (f.id == 'D13') {
    await tapFocus(t, find.byTooltip(l.historyMenu));
  }
  if (f.id == 'D14') {
    await t.runAsync(
      () => f.workouts.completeSet(
        f.session!.id,
        expectedExerciseId: f.session!.currentExercise.id,
        expectedSetNumber: f.session!.currentSetNumber,
      ),
    );
    await tapFocus(t, find.text(l.saveOrder));
  }
}
