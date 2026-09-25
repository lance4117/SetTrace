import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late String filePath;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settrace_test_');
    filePath = p.join(directory.path, 'settrace.db');
    database = await AppDatabase.open(filePath: filePath, factory: databaseFactoryFfi);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('database v1 keeps its five tables and plan data after reopen', () async {
    final names = await database.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(names.map((row) => row['name']), containsAll([
      'plans', 'plan_exercises', 'workout_sessions',
      'session_exercises', 'session_sets',
    ]));
    final plans = PlanRepository(database.db);
    final id = await plans.createPlan('  练背  ');
    await database.close();
    database = await AppDatabase.open(filePath: filePath, factory: databaseFactoryFfi);
    expect((await PlanRepository(database.db).getPlan(id))?.name, '练背');
  });

  test('plan exercises persist seconds and drag order', () async {
    final plans = PlanRepository(database.db);
    final planId = await plans.createPlan('练背');
    final first = await plans.addExercise(planId: planId, name: '高位下拉',
      targetSets: 4, restBetweenSetsSeconds: 120,
      restAfterExerciseSeconds: 150, defaultWeightKg: 45);
    final second = await plans.addExercise(planId: planId, name: '坐姿划船',
      targetSets: 3, restBetweenSetsSeconds: 90,
      restAfterExerciseSeconds: 120);
    await plans.reorder(planId, [second, first]);
    await database.close();
    database = await AppDatabase.open(filePath: filePath, factory: databaseFactoryFfi);
    final saved = (await PlanRepository(database.db).getPlan(planId))!;
    expect(saved.exercises.map((e) => e.name).toList(), ['坐姿划船', '高位下拉']);
    expect(saved.exercises.last.restAfterExerciseSeconds, 150);
    expect(saved.exercises.last.defaultWeightKg, 45);
  });
}
