import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/database_v1.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settrace_migration_');
    path = p.join(directory.path, 'legacy.db');
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<Database> seed(String variant) async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: createLegacyV1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    await db.insert('plans', {
      'id': 1,
      'name': '旧计划',
      'created_at': 1,
      'updated_at': 1,
    });
    final completed = switch (variant) {
      'zero' => 0,
      'between_exercises' => 2,
      'all' || 'completed' => 4,
      _ => 1,
    };
    final saved = variant == 'completed' || variant == 'partial';
    final order = variant == 'all' || variant == 'completed'
        ? 3
        : variant == 'between_exercises' || variant == 'corrupt'
        ? 2
        : 1;
    final resting = [
      'between_sets',
      'between_exercises',
      'corrupt',
      'deleted',
    ].contains(variant);
    await db.insert('workout_sessions', {
      'id': 50,
      'source_plan_id': 1,
      'plan_name_snapshot': '旧计划',
      'started_at': 1000,
      'started_local_date': '2026-09-25',
      'status': saved ? 'completed' : 'in_progress',
      'current_exercise_order': order,
      'current_set_number': order == 1 && completed == 1 ? 2 : 1,
      'ended_at': saved ? 901000 : null,
      'duration_seconds': saved ? 900 : null,
      'rest_kind': resting
          ? variant == 'between_exercises'
                ? 'between_exercises'
                : 'between_sets'
          : null,
      'rest_started_at': resting ? 10000 : null,
      'rest_end_at': resting ? 200000 : null,
    });
    var setId = 1001;
    for (var i = 0; i < 3; i++) {
      await db.insert('plan_exercises', {
        'id': i + 1,
        'plan_id': 1,
        'name': ['A', 'B', 'C'][i],
        'sort_order': i + 1,
        'target_sets': i == 0 ? 2 : 1,
        'rest_between_sets_seconds': 120,
        'rest_after_exercise_seconds': 150,
        'default_weight_kg': 25.5,
      });
      await db.insert('session_exercises', {
        'id': 101 + i,
        'session_id': 50,
        'source_exercise_id': i + 1,
        'name_snapshot': ['A', 'B', 'C'][i],
        'sort_order': i + 1,
        'target_sets': i == 0 ? 2 : 1,
        'rest_between_sets_seconds': 120,
        'rest_after_exercise_seconds': 150,
        'default_weight_kg': 25.5,
      });
      for (var number = 1; number <= (i == 0 ? 2 : 1); number++) {
        await db.insert('session_sets', {
          'id': setId,
          'session_exercise_id': 101 + i,
          'set_number': number,
          'completed_at': setId - 1001 < completed ? 10000 : null,
        });
        setId++;
      }
    }
    if (variant == 'deleted') await db.delete('plans', where: 'id = 1');
    return db;
  }

  for (final variant in [
    'zero',
    'between_sets',
    'between_exercises',
    'corrupt',
    'all',
    'completed',
    'partial',
    'deleted',
  ]) {
    test(
      'v1 to v2 preserves $variant data and corrects only invalid cursor',
      () async {
        final legacy = await seed(variant);
        final originalSets = await legacy.query('session_sets', orderBy: 'id');
        final originalExercises = await legacy.query(
          'session_exercises',
          orderBy: 'id',
        );
        final originalSession = (await legacy.query('workout_sessions')).single;
        await legacy.close();
        final upgraded = await AppDatabase.open(
          filePath: path,
          factory: databaseFactoryFfi,
        );
        try {
          expect(await upgraded.db.getVersion(), 2);
          final sets = await upgraded.db.query('session_sets', orderBy: 'id');
          var sequence = 0;
          for (var i = 0; i < sets.length; i++) {
            expect({...sets[i]}..remove('completed_sequence'), originalSets[i]);
            expect(
              sets[i]['completed_sequence'],
              sets[i]['completed_at'] == null ? null : ++sequence,
            );
          }
          expect(
            await upgraded.db.query('session_exercises', orderBy: 'id'),
            originalExercises,
          );
          final session = (await upgraded.db.query('workout_sessions')).single;
          for (final field in [
            'source_plan_id',
            'plan_name_snapshot',
            'started_at',
            'started_local_date',
            'status',
            'ended_at',
            'duration_seconds',
          ]) {
            expect(session[field], originalSession[field], reason: field);
          }
          if (variant == 'corrupt') {
            expect(session['current_session_exercise_id'], 101);
            expect(session['current_set_number'], 2);
            expect(session['rest_end_at'], isNull);
          } else {
            expect(
              session['current_session_exercise_id'],
              100 + (originalSession['current_exercise_order'] as int),
            );
            for (final field in [
              'current_exercise_order',
              'current_set_number',
              'rest_kind',
              'rest_started_at',
              'rest_end_at',
            ]) {
              expect(session[field], originalSession[field], reason: field);
            }
          }
          final data = await WorkoutRepository(
            upgraded.db,
            clock: () =>
                DateTime.fromMillisecondsSinceEpoch(20000, isUtc: true),
          ).getSession(50);
          expect(data!.exercises.map((e) => e.name), ['A', 'B', 'C']);
          expect(
            data.currentExercise.id,
            session['current_session_exercise_id'],
          );
          expect(
            await upgraded.db.rawQuery('PRAGMA foreign_key_check'),
            isEmpty,
          );
          final freshPath = p.join(directory.path, 'fresh.db');
          final fresh = await AppDatabase.open(
            filePath: freshPath,
            factory: databaseFactoryFfi,
          );
          try {
            for (final table in ['workout_sessions', 'session_sets']) {
              expect(
                await upgraded.db.rawQuery('PRAGMA table_info($table)'),
                await fresh.db.rawQuery('PRAGMA table_info($table)'),
              );
            }
          } finally {
            await fresh.close();
          }
        } finally {
          await upgraded.close();
        }
      },
    );
  }

  test(
    'failed migration rolls back version and added columns, retaining plans',
    () async {
      final legacy = await seed('zero');
      await legacy.execute('DROP TABLE session_sets');
      await legacy.close();
      await expectLater(
        AppDatabase.open(filePath: path, factory: databaseFactoryFfi),
        throwsA(isA<DatabaseException>()),
      );
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1),
      );
      try {
        expect(await db.getVersion(), 1);
        expect((await db.query('plans')).single['name'], '旧计划');
        expect(
          (await db.rawQuery('PRAGMA table_info(workout_sessions)'))
              .map((row) => row['name']),
          isNot(contains('current_session_exercise_id')),
        );
      } finally {
        await db.close();
      }
    },
  );
}
