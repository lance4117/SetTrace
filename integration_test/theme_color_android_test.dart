import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android presets, mode independence, restart and active rest', (
    t,
  ) async {
    if (!const bool.fromEnvironment('THEME_QA_ISOLATED')) {
      throw StateError(
        'Run only on an isolated emulator with THEME_QA_ISOLATED=true.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_notice_seen_version', 1);
    await prefs.setString('theme_mode', 'light');
    await prefs.remove('theme_color');
    final db = await AppDatabase.open();
    final plans = PlanRepository(db.db), workouts = WorkoutRepository(db.db);
    final plan = await plans.createPlan('Theme color QA');
    await plans.addExercise(
      planId: plan,
      name: 'Palette exercise',
      targetSets: 3,
      restBetweenSetsSeconds: 600,
      restAfterExerciseSeconds: 0,
    );
    final active = await workouts.getActive();
    if (active != null) await workouts.discard(active.id);
    final session = await workouts.start(plan);
    final rest = await workouts.completeSet(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedSetNumber: 1,
    );
    Widget root() => SetTraceApp(
      plans: plans,
      workouts: workouts,
      preferences: prefs,
      initialLocale: const Locale('zh'),
    );
    await t.pumpWidget(root());
    await t.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await t.pumpAndSettle();
    final output = Directory(
      '${Directory.systemTemp.path}/theme-color-evidence',
    );
    await output.create(recursive: true);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      var tabs = t.widget<RootTabs>(find.byType(RootTabs));
      await tabs.onModeChanged(mode);
      await t.pumpAndSettle();
      await t.tap(find.text('设置').last);
      await t.pumpAndSettle();
      for (final preset in ThemeColorPreset.values) {
        final option = find.byKey(ValueKey('theme-color-${preset.name}'));
        await t.ensureVisible(option);
        await t.tap(option);
        await t.pump();
        tabs = t.widget<RootTabs>(find.byType(RootTabs));
        expect(tabs.themeColors!.selected, preset);
        await tabs.themeColors!.settled;
        await t.pumpAndSettle();
        expect(t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, mode);
        final name = '${preset.name}-${mode.name}-zh';
        await File('${output.path}/$name.png')
            .writeAsBytes(await binding.takeScreenshot(name));
        debugPrint('THEME_ANDROID_PALETTE $name OK');
      }
    }
    var c = t.widget<RootTabs>(find.byType(RootTabs)).themeColors!;
    c.select(ThemeColorPreset.blue);
    c.select(ThemeColorPreset.violet);
    c.select(ThemeColorPreset.graphite);
    await t.tap(find.text('记录').last);
    await c.settled;
    await t.pumpAndSettle();
    expect(c.committed, ThemeColorPreset.graphite);
    await t.pumpWidget(const SizedBox());
    await prefs.reload();
    await t.pumpWidget(root());
    await t.pumpAndSettle();
    c = t.widget<RootTabs>(find.byType(RootTabs)).themeColors!;
    expect(c.selected, ThemeColorPreset.graphite);
    expect(
      t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    final restored = (await workouts.getSession(session.id))!;
    expect(restored.restEndAt, rest.restEndAt);
    expect(restored.completedSets, 1);
    debugPrint('THEME_ANDROID_RESTART_REST OK');
    await t.tap(find.text('设置').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('theme-color-blue')));
    // Leave the real settings page available for adb keyboard/TalkBack checks.
    debugPrint('THEME_ANDROID_INTERACTION_READY ${output.path}');
    for (
      var i = 0;
      const bool.fromEnvironment('THEME_QA_INTERACT') && i < 600;
      i++
    ) {
      if (await File('${output.path}/interaction.done').exists()) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final language = t.widget<RootTabs>(find.byType(RootTabs)).onLocaleChanged;
    await language(const Locale('en'));
    await t.pumpAndSettle();
    await File('${output.path}/graphite-dark-en.png')
        .writeAsBytes(await binding.takeScreenshot('graphite-dark-en'));
    await t.pumpWidget(const SizedBox());
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
