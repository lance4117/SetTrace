import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/about/app_notice_dialog.dart';
import 'package:settrace/features/about/notice_preferences.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/l10n/language_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android notice and Downloads survive only explicit plan restore',
    (t) async {
      final prefs = await SharedPreferences.getInstance();
      final db = await AppDatabase.open();
      final plans = PlanRepository(db.db), workouts = WorkoutRepository(db.db);
      const after = bool.fromEnvironment('RESTORE_PHASE');
      const encoded = String.fromEnvironment('RESTORE_PLAN');
      if (after) {
        expect(prefs.get(noticePreferenceKey), isNull);
        expect(await plans.listPlans(), isEmpty);
        expect(await workouts.getActive(), isNull);
        expect(
          (await db.db.rawQuery('SELECT COUNT(*) AS n FROM workout_sessions'))
              .single['n'],
          0,
        );
      } else {
        await prefs.remove(noticePreferenceKey);
      }
      await prefs.setString(languagePreferenceKey, 'en');
      await t.pumpWidget(
        SetTraceApp(plans: plans, workouts: workouts, preferences: prefs),
      );
      await t.pumpAndSettle();
      expect(find.byType(AppNoticeDialog), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('notice-confirm')));
      await t.pumpAndSettle();
      expect(prefs.getInt(noticePreferenceKey), 1);
      if (after) {
        final document = const PlanTransferCodec().decode(
          utf8.decode(base64Decode(encoded)),
        );
        final ids = await plans.importPlans(
          document.plans,
          suffixFor: (n) => " (imported $n)",
        );
        final restored = (await plans.getPlan(ids.single))!;
        expect(restored.name, 'About QA backup');
        expect(restored.exercises.single.targetSets, 2);
        expect(restored.exercises.single.restBetweenSetsSeconds, 120);
        expect(restored.exercises.single.defaultWeightKg, 45.5);
        expect(
          (await db.db.rawQuery('SELECT COUNT(*) AS n FROM workout_sessions'))
              .single['n'],
          0,
        );
        debugPrint('ABOUT_QA_RESTORED_PLAN_ONLY');
      } else {
        final id = await plans.createPlan('About QA backup');
        await plans.addExercise(
          planId: id,
          name: 'QA exercise',
          targetSets: 2,
          restBetweenSetsSeconds: 120,
          restAfterExerciseSeconds: 30,
          defaultWeightKg: 45.5,
        );
        final session = await workouts.start(id);
        await workouts.completeSet(
          session.id,
          expectedExerciseId: session.currentExercise.id,
          expectedSetNumber: 1,
        );
        await workouts.finish(session.id);
        await workouts.start(id);
        final payload = const PlanTransferCodec().encode(
          PlanTransferDocument(await plans.exportPlans({id})),
        );
        final saved = await AndroidPlanTransferPlatform().saveFile(payload);
        debugPrint('ABOUT_QA_FILE=${saved.fileName}');
        final file = File('${Directory.systemTemp.path}/about-qa-export.txt');
        await file.writeAsString(saved.fileName);
      }
      await t.pumpWidget(const SizedBox());
      await db.close();
    },
  );
}
