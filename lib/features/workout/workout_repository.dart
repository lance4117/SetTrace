import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import 'workout_models.dart';

class WorkoutRepository {
  WorkoutRepository(this.db, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final Database db;
  final DateTime Function() clock;

  int get _nowMs => clock().toUtc().millisecondsSinceEpoch;

  Future<WorkoutSessionData?> getActive() async {
    final rows = await db.query('workout_sessions', columns: ['id'],
      where: "status = 'in_progress'", limit: 1);
    if (rows.isEmpty) return null;
    final id = rows.first['id'] as int;
    await normalizeRest(id);
    await db.transaction((txn) => _repairCursor(txn, id));
    return getSession(id);
  }

  Future<WorkoutSessionData?> getSession(int id) async {
    final rows = await db.query('workout_sessions', where: 'id = ?',
      whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final exerciseRows = await db.query('session_exercises',
      where: 'session_id = ?', whereArgs: [id], orderBy: 'sort_order ASC');
    final exercises = <SessionExercise>[];
    for (final row in exerciseRows) {
      final setRows = await db.query('session_sets',
        where: 'session_exercise_id = ?', whereArgs: [row['id']],
        orderBy: 'set_number ASC');
      exercises.add(SessionExercise.fromRow(row,
        setRows.map(SessionSet.fromRow).toList()));
    }
    final row = rows.first;
    DateTime? date(String key) => row[key] == null ? null :
      DateTime.fromMillisecondsSinceEpoch(row[key] as int, isUtc: true);
    return WorkoutSessionData(
      id: id, planName: row['plan_name_snapshot'] as String,
      startedAt: date('started_at')!,
      startedLocalDate: row['started_local_date'] as String,
      endedAt: date('ended_at'), durationSeconds: row['duration_seconds'] as int?,
      status: row['status'] as String,
      currentExerciseOrder: row['current_exercise_order'] as int,
      currentSetNumber: row['current_set_number'] as int,
      restKind: row['rest_kind'] as String?,
      restStartedAt: date('rest_started_at'), restEndAt: date('rest_end_at'),
      exercises: exercises,
    );
  }

  Future<WorkoutSessionData> start(int planId) async {
    final id = await db.transaction((txn) async {
      final active = await txn.query('workout_sessions', columns: ['id'],
        where: "status = 'in_progress'", limit: 1);
      if (active.isNotEmpty) throw StateError('An unfinished workout already exists');
      final plans = await txn.query('plans', where: 'id = ?',
        whereArgs: [planId], limit: 1);
      if (plans.isEmpty) throw StateError('Plan not found');
      final configured = await txn.query('plan_exercises',
        where: 'plan_id = ?', whereArgs: [planId], orderBy: 'sort_order ASC');
      if (configured.isEmpty) throw StateError('Add an exercise before starting');
      final now = clock();
      final local = now.toLocal();
      final localDate = '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
      final sessionId = await txn.insert('workout_sessions', {
        'source_plan_id': planId,
        'plan_name_snapshot': plans.first['name'],
        'started_at': now.toUtc().millisecondsSinceEpoch,
        'started_local_date': localDate,
        'status': 'in_progress',
        'current_exercise_order': 1,
        'current_set_number': 1,
      });
      for (var i = 0; i < configured.length; i++) {
        final source = configured[i];
        final exerciseId = await txn.insert('session_exercises', {
          'session_id': sessionId,
          'source_exercise_id': source['id'],
          'name_snapshot': source['name'],
          'sort_order': i + 1,
          'target_sets': source['target_sets'],
          'rest_between_sets_seconds': source['rest_between_sets_seconds'],
          'rest_after_exercise_seconds': source['rest_after_exercise_seconds'],
          'default_weight_kg': source['default_weight_kg'],
        });
        for (var number = 1; number <= (source['target_sets'] as int); number++) {
          await txn.insert('session_sets', {
            'session_exercise_id': exerciseId, 'set_number': number,
          });
        }
      }
      return sessionId;
    });
    return (await getSession(id))!;
  }

  Future<WorkoutSessionData> completeSet(int sessionId, {
    required int expectedExerciseOrder, required int expectedSetNumber}) async {
    await db.transaction((txn) async {
      final session = await _activeRow(txn, sessionId);
      if (session['rest_end_at'] != null) throw StateError('Rest is still active');
      if (session['current_exercise_order'] != expectedExerciseOrder ||
          session['current_set_number'] != expectedSetNumber) {
        throw StateError('Workout position has changed');
      }
      final exerciseRows = await txn.query('session_exercises',
        where: 'session_id = ? AND sort_order = ?',
        whereArgs: [sessionId, expectedExerciseOrder], limit: 1);
      final exercise = exerciseRows.single;
      final changed = await txn.update('session_sets', {'completed_at': _nowMs},
        where: 'session_exercise_id = ? AND set_number = ? AND completed_at IS NULL',
        whereArgs: [exercise['id'], expectedSetNumber]);
      if (changed != 1) throw StateError('Set already completed');

      final target = exercise['target_sets'] as int;
      final nextExerciseRows = await txn.query('session_exercises', columns: ['id'],
        where: 'session_id = ? AND sort_order = ?',
        whereArgs: [sessionId, expectedExerciseOrder + 1], limit: 1);
      final hasNextSet = expectedSetNumber < target;
      final hasNextExercise = nextExerciseRows.isNotEmpty;
      final restSeconds = hasNextSet
        ? exercise['rest_between_sets_seconds'] as int
        : hasNextExercise ? exercise['rest_after_exercise_seconds'] as int : 0;
      final now = _nowMs;
      await txn.update('workout_sessions', {
        'current_exercise_order': hasNextSet || !hasNextExercise
          ? expectedExerciseOrder : expectedExerciseOrder + 1,
        'current_set_number': hasNextSet ? expectedSetNumber + 1
          : hasNextExercise ? 1 : expectedSetNumber,
        'rest_kind': restSeconds == 0 ? null
          : hasNextSet ? 'between_sets' : 'between_exercises',
        'rest_started_at': restSeconds == 0 ? null : now,
        'rest_end_at': restSeconds == 0 ? null : now + restSeconds * 1000,
      }, where: 'id = ?', whereArgs: [sessionId]);
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> undoLastSet(int sessionId) async {
    await db.transaction((txn) async {
      await _activeRow(txn, sessionId);
      final rows = await txn.rawQuery('''
        SELECT ss.id, ss.set_number, se.sort_order
        FROM session_sets ss JOIN session_exercises se
          ON se.id = ss.session_exercise_id
        WHERE se.session_id = ? AND ss.completed_at IS NOT NULL
        ORDER BY ss.completed_at DESC, ss.id DESC LIMIT 1
      ''', [sessionId]);
      if (rows.isEmpty) throw StateError('No completed set to undo');
      final last = rows.first;
      await txn.update('session_sets', {'completed_at': null},
        where: 'id = ?', whereArgs: [last['id']]);
      await txn.update('workout_sessions', {
        'current_exercise_order': last['sort_order'],
        'current_set_number': last['set_number'],
        'rest_kind': null, 'rest_started_at': null, 'rest_end_at': null,
      }, where: 'id = ?', whereArgs: [sessionId]);
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> adjustRest(int sessionId, int deltaSeconds) async {
    if (deltaSeconds % 30 != 0) throw ArgumentError('Rest adjustment must use 30 seconds');
    await db.transaction((txn) async {
      final row = await _activeRow(txn, sessionId);
      final end = row['rest_end_at'] as int?;
      if (end == null) throw StateError('No active rest');
      final updated = end + deltaSeconds * 1000;
      if (updated <= _nowMs) {
        await _clearRest(txn, sessionId);
      } else {
        await txn.update('workout_sessions', {'rest_end_at': updated},
          where: 'id = ?', whereArgs: [sessionId]);
      }
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> skipRest(int sessionId) async {
    await db.transaction((txn) async {
      final row = await _activeRow(txn, sessionId);
      if (row['rest_end_at'] == null) throw StateError('No active rest');
      await _clearRest(txn, sessionId);
    });
    return (await getSession(sessionId))!;
  }

  Future<void> normalizeRest(int sessionId) async {
    await db.transaction((txn) async {
      final rows = await txn.query('workout_sessions', where: 'id = ?',
        whereArgs: [sessionId], limit: 1);
      if (rows.isEmpty || rows.first['status'] != 'in_progress') return;
      final end = rows.first['rest_end_at'] as int?;
      if (end != null && end <= _nowMs) await _clearRest(txn, sessionId);
    });
  }

  Future<WorkoutSessionData> updateExercise(int sessionId, int exerciseId, {
    required int targetSets, required int restBetweenSetsSeconds,
    required int restAfterExerciseSeconds}) async {
    if (targetSets < 1 || restBetweenSetsSeconds < 0 ||
        restAfterExerciseSeconds < 0 || restBetweenSetsSeconds % 30 != 0 ||
        restAfterExerciseSeconds % 30 != 0) {
      throw ArgumentError('Invalid set or rest value');
    }
    await db.transaction((txn) async {
      final session = await _activeRow(txn, sessionId);
      final rows = await txn.query('session_exercises',
        where: 'id = ? AND session_id = ?',
        whereArgs: [exerciseId, sessionId], limit: 1);
      if (rows.isEmpty) throw StateError('Exercise not found');
      final exercise = rows.first;
      if ((exercise['sort_order'] as int) < (session['current_exercise_order'] as int)) {
        throw StateError('Past exercise cannot be changed');
      }
      final countRows = await txn.rawQuery('''
        SELECT COUNT(*) AS count FROM session_sets
        WHERE session_exercise_id = ? AND completed_at IS NOT NULL
      ''', [exerciseId]);
      if (targetSets < (countRows.first['count'] as int)) {
        throw ArgumentError('Target cannot be smaller than completed sets');
      }
      final oldTarget = exercise['target_sets'] as int;
      if (targetSets > oldTarget) {
        for (var number = oldTarget + 1; number <= targetSets; number++) {
          await txn.insert('session_sets', {
            'session_exercise_id': exerciseId, 'set_number': number,
          });
        }
      } else if (targetSets < oldTarget) {
        await txn.delete('session_sets',
          where: 'session_exercise_id = ? AND set_number > ? AND completed_at IS NULL',
          whereArgs: [exerciseId, targetSets]);
      }
      await txn.update('session_exercises', {
        'target_sets': targetSets,
        'rest_between_sets_seconds': restBetweenSetsSeconds,
        'rest_after_exercise_seconds': restAfterExerciseSeconds,
      }, where: 'id = ?', whereArgs: [exerciseId]);
      await _repairCursor(txn, sessionId);
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> finish(int sessionId) async {
    await db.transaction((txn) async {
      final row = await _activeRow(txn, sessionId);
      final completed = await txn.rawQuery('''
        SELECT COUNT(*) AS count FROM session_sets ss
        JOIN session_exercises se ON se.id = ss.session_exercise_id
        WHERE se.session_id = ? AND ss.completed_at IS NOT NULL
      ''', [sessionId]);
      if ((completed.first['count'] as int) == 0) {
        throw StateError('An empty workout cannot be saved');
      }
      final now = _nowMs;
      final duration = math.max(0, (now - (row['started_at'] as int)) ~/ 1000);
      await txn.update('workout_sessions', {
        'status': 'completed', 'ended_at': now, 'duration_seconds': duration,
        'rest_kind': null, 'rest_started_at': null, 'rest_end_at': null,
      }, where: 'id = ?', whereArgs: [sessionId]);
    });
    return (await getSession(sessionId))!;
  }

  Future<void> discard(int sessionId) async {
    await db.transaction((txn) async {
      await _activeRow(txn, sessionId);
      await txn.delete('workout_sessions', where: 'id = ?', whereArgs: [sessionId]);
    });
  }

  Future<List<WorkoutSessionData>> listHistory() async {
    final rows = await db.query('workout_sessions', columns: ['id'],
      where: "status = 'completed'", orderBy: 'started_at DESC');
    final result = <WorkoutSessionData>[];
    for (final row in rows) {
      result.add((await getSession(row['id'] as int))!);
    }
    return result;
  }

  Future<Map<String, Object?>> _activeRow(Transaction txn, int id) async {
    final rows = await txn.query('workout_sessions', where: 'id = ?',
      whereArgs: [id], limit: 1);
    if (rows.isEmpty || rows.first['status'] != 'in_progress') {
      throw StateError('Active workout not found');
    }
    return rows.first;
  }

  Future<void> _clearRest(Transaction txn, int id) async {
    await txn.update('workout_sessions', {
      'rest_kind': null, 'rest_started_at': null, 'rest_end_at': null,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _repairCursor(Transaction txn, int id) async {
    final pending = await txn.rawQuery('''
      SELECT se.sort_order, ss.set_number FROM session_sets ss
      JOIN session_exercises se ON se.id = ss.session_exercise_id
      WHERE se.session_id = ? AND ss.completed_at IS NULL
      ORDER BY se.sort_order, ss.set_number LIMIT 1
    ''', [id]);
    if (pending.isEmpty) {
      final last = await txn.query('session_exercises',
        columns: ['sort_order', 'target_sets'], where: 'session_id = ?',
        whereArgs: [id], orderBy: 'sort_order DESC', limit: 1);
      if (last.isNotEmpty) {
        await txn.update('workout_sessions', {
          'current_exercise_order': last.first['sort_order'],
          'current_set_number': last.first['target_sets'],
        }, where: 'id = ?', whereArgs: [id]);
        await _clearRest(txn, id);
      }
      return;
    }
    final current = await txn.query('workout_sessions',
      columns: ['current_exercise_order', 'current_set_number'],
      where: 'id = ?', whereArgs: [id], limit: 1);
    if (current.isNotEmpty &&
        (current.first['current_exercise_order'] != pending.first['sort_order'] ||
         current.first['current_set_number'] != pending.first['set_number'])) {
      await _clearRest(txn, id);
    }
    await txn.update('workout_sessions', {
      'current_exercise_order': pending.first['sort_order'],
      'current_set_number': pending.first['set_number'],
    }, where: 'id = ?', whereArgs: [id]);
  }
}
