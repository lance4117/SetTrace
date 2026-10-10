import 'package:settrace/l10n/generated/app_localizations_en.dart';
import 'package:settrace/l10n/generated/app_localizations_zh.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase db;
  late PlanRepository repo;
  late String path;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('plan_transfer_');
    path = '${dir.path}/test.db';
    db = await AppDatabase.open(filePath: path, factory: databaseFactoryFfi);
    repo = PlanRepository(db.db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<int> seed() async {
    final id = await repo.createPlan('练背');
    final a = await repo.addExercise(
      planId: id,
      name: '下拉',
      targetSets: 2,
      restBetweenSetsSeconds: 120,
      restAfterExerciseSeconds: 150,
      defaultWeightKg: 45.5,
    );
    final b = await repo.addExercise(
      planId: id,
      name: '划船',
      targetSets: 3,
      restBetweenSetsSeconds: 90,
      restAfterExerciseSeconds: 0,
    );
    await repo.reorder(id, [b, a]);
    return id;
  }

  Future<String> table(String name) async =>
      jsonEncode(await db.db.query(name));
  test('selected export uses list order and saved exercise order, not selection order', () async {
    final first = await seed();
    final second = await repo.createPlan('空计划');
    final all = await repo.exportPlans({second, first});
    expect(all.map((p) => p.name), ['练背', '空计划']);
    expect(all.first.exercises.map((e) => e.name), ['划船', '下拉']);
    expect(all.first.exercises.last.defaultWeightKg, 45.5);
    expect((await repo.exportPlans({first})).length, 1);
    await repo.deletePlan(second);
    await expectLater(
      repo.exportPlans({first, second}),
      throwsA(isA<PlanTransferException>()),
    );
    await expectLater(
      repo.exportPlans({}),
      throwsA(isA<PlanTransferException>()),
    );
  });
  test('imports fresh identities persist and never touch existing sessions or plans', () async {
    final original = await seed();
    final workouts = WorkoutRepository(db.db);
    final active = await workouts.start(original);
    await workouts.completeSet(
      active.id,
      expectedExerciseId: active.exercises.first.id,
      expectedSetNumber: 1,
    );
    final sessionTables = [
      'workout_sessions',
      'session_exercises',
      'session_sets',
    ];
    final before = [for (final t in sessionTables) await table(t)];
    final originalRows = await table('plan_exercises');
    final preview = await repo.previewImport(
      await repo.exportPlans({original}),
      suffixFor: AppLocalizationsZh().importSuffix,
    );
    expect(preview.single.name, '练背（导入）');
    final ids = await repo.importPlans(
      preview,
      suffixFor: AppLocalizationsZh().importSuffix,
    );
    expect(ids.single, isNot(original));
    expect(
      await table('plan_exercises'),
      startsWith(originalRows.substring(0, originalRows.length - 1)),
    );
    expect([for (final t in sessionTables) await table(t)], before);
    await db.close();
    db = await AppDatabase.open(filePath: path, factory: databaseFactoryFfi);
    repo = PlanRepository(db.db);
    final restored = (await repo.getPlan(ids.single))!;
    expect(restored.name, '练背（导入）');
    expect(restored.exercises.map((e) => e.name), ['划船', '下拉']);
    expect(restored.exercises.map((e) => e.sortOrder), [1, 2]);
    expect(restored.exercises.last.defaultWeightKg, 45.5);
    expect(
      restored.exercises
          .map((e) => e.id)
          .toSet()
          .intersection(
            (await repo.getPlan(original))!.exercises.map((e) => e.id).toSet(),
          ),
      isEmpty,
    );
    expect(
      (await db.db.rawQuery('PRAGMA user_version')).first.values.single,
      2,
    );
  });
  test(
    'new collision after preview saves nothing and returns a new preview',
    () async {
      final plans = [TransferPlan(name: '练腿', exercises: [])];
      final preview = await repo.previewImport(
        plans,
        suffixFor: AppLocalizationsZh().importSuffix,
      );
      await repo.createPlan('练腿');
      final before = await table('plans');
      await expectLater(
        repo.importPlans(preview, suffixFor: AppLocalizationsZh().importSuffix),
        throwsA(
          isA<ImportNameConflict>().having(
            (e) => e.plans.single.name,
            'updated name',
            '练腿（导入）',
          ),
        ),
      );
      expect(await table('plans'), before);
    },
  );
  test(
    'late exercise insertion failure rolls back every plan and exercise',
    () async {
      final original = await seed();
      final plansBefore = await table('plans');
      final exercisesBefore = await table('plan_exercises');
      await db.db.execute(
        "CREATE TRIGGER fail_transfer BEFORE INSERT ON plan_exercises WHEN NEW.name = '失败动作' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      final plans = [
        TransferPlan(name: '成功前半', exercises: []),
        TransferPlan(
          name: '失败后半',
          exercises: [
            const TransferExercise(
              name: '失败动作',
              targetSets: 1,
              restBetweenSetsSeconds: 0,
              restAfterExerciseSeconds: 0,
            ),
          ],
        ),
      ];
      await expectLater(
        repo.importPlans(plans, suffixFor: AppLocalizationsZh().importSuffix),
        throwsA(isA<DatabaseException>()),
      );
      expect(await table('plans'), plansBefore);
      expect(await table('plan_exercises'), exercisesBefore);
      expect((await repo.getPlan(original))!.name, '练背');
    },
  );
  test(
    'valid compact input is not rejected for the size of a re-encoded export',
    () async {
      const codec = PlanTransferCodec();
      final plan = TransferPlan(
        name: '大计划',
        exercises: List.generate(
          14000,
          (_) => const TransferExercise(
            name: '划船',
            targetSets: 1,
            restBetweenSetsSeconds: 0,
            restAfterExerciseSeconds: 0,
          ),
        ),
      );
      final source = jsonEncode({
        'format': PlanTransferCodec.format,
        'schemaVersion': 1,
        'plans': [plan.toJson()],
      });
      expect(utf8.encode(source).length, lessThan(PlanTransferCodec.maxBytes));
      expect(
        () => codec.encode(PlanTransferDocument([plan])),
        throwsA(isA<PlanTransferException>()),
      );
      final parsed = codec.decode(source);
      final preview = await repo.previewImport(
        parsed.plans,
        suffixFor: AppLocalizationsZh().importSuffix,
      );
      final ids = await repo.importPlans(
        preview,
        suffixFor: AppLocalizationsZh().importSuffix,
      );
      final restored = (await repo.getPlan(ids.single))!;
      expect(restored.name, '大计划');
      expect(restored.exercises, hasLength(14000));
      expect(restored.exercises.last.sortOrder, 14000);
      expect(restored.exercises.last.restBetweenSetsSeconds, 0);
    },
  );
  test(
    'English suffix is pinned for preview and transaction conflict review',
    () async {
      final original = await seed();
      final suffix = AppLocalizationsEn().importSuffix;
      final source = await repo.exportPlans({original});
      final preview = await repo.previewImport([
        ...source,
        ...source,
      ], suffixFor: suffix);
      expect(preview.map((p) => p.name), ['练背 (imported)', '练背 (imported 2)']);
      await repo.createPlan(
        preview.first.name,
      ); // A new conflict after preview.
      final before = await table('plans');
      List<TransferPlan>? updated;
      try {
        await repo.importPlans(preview, suffixFor: suffix);
        fail('Conflict must return to preview instead of saving silently');
      } on ImportNameConflict catch (error) {
        updated = error.plans;
      }
      expect(await table('plans'), before);
      expect(updated.first.name, '练背 (imported) (imported)');
      final ids = await repo.importPlans(updated, suffixFor: suffix);
      expect((await repo.getPlan(ids.first))!.name, updated.first.name);
      expect((await repo.getPlan(original))!.name, '练背');
      final restored = const PlanTransferCodec().decode(
        const PlanTransferCodec().encode(
          PlanTransferDocument(await repo.exportPlans({ids.first})),
        ),
      );
      expect(restored.plans.single.exercises.last.defaultWeightKg, 45.5);
    },
  );
}
