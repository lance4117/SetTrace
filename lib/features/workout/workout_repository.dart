import 'workout_failure.dart';

import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import 'workout_models.dart';

enum HistoryDeleteFailure { notFound, notSaved }

class HistoryDeleteException implements Exception {
  const HistoryDeleteException(this.reason);
  final HistoryDeleteFailure reason;
}

class WorkoutRepository {
  WorkoutRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final Database db;
  final DateTime Function() clock;

  int get _nowMs => clock().toUtc().millisecondsSinceEpoch;

  Future<WorkoutSessionData?> getActive() async {
    return db.transaction((txn) async {
      final rows = await txn.query(
        'workout_sessions',
        columns: ['id'],
        where: "status = 'in_progress'",
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final id = rows.first['id'] as int;
      await _normalizeRest(txn, id);
      await _repairCursor(txn, id);
      return _readSession(txn, id);
    });
  }

  Future<WorkoutSessionData?> getSession(int id) =>
      db.transaction((txn) => _readSession(txn, id));

  Future<WorkoutSessionData?> _readSession(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final exerciseRows = await db.query(
      'session_exercises',
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );
    final exercises = <SessionExercise>[];
    for (final row in exerciseRows) {
      final setRows = await db.query(
        'session_sets',
        where: 'session_exercise_id = ?',
        whereArgs: [row['id']],
        orderBy: 'set_number ASC',
      );
      exercises.add(
        SessionExercise.fromRow(row, setRows.map(SessionSet.fromRow).toList()),
      );
    }
    final row = rows.first;
    DateTime? date(String key) => row[key] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row[key] as int, isUtc: true);
    return WorkoutSessionData(
      id: id,
      planName: row['plan_name_snapshot'] as String,
      startedAt: date('started_at')!,
      startedLocalDate: row['started_local_date'] as String,
      endedAt: date('ended_at'),
      durationSeconds: row['duration_seconds'] as int?,
      status: row['status'] as String,
      currentExerciseOrder: row['current_exercise_order'] as int,
      currentSetNumber: row['current_set_number'] as int,
      currentSessionExerciseId: row['current_session_exercise_id'] as int?,
      restKind: row['rest_kind'] as String?,
      restStartedAt: date('rest_started_at'),
      restEndAt: date('rest_end_at'),
      exercises: exercises,
    );
  }

  Future<WorkoutSessionData> start(int planId) async {
    final id = await db.transaction((txn) async {
      final active = await txn.query(
        'workout_sessions',
        columns: ['id'],
        where: "status = 'in_progress'",
        limit: 1,
      );
      if (active.isNotEmpty) {
        throw WorkoutStateException(WorkoutFailure.activeExists);
      }
      final plans = await txn.query(
        'plans',
        where: 'id = ?',
        whereArgs: [planId],
        limit: 1,
      );
      if (plans.isEmpty) {
        throw WorkoutStateException(WorkoutFailure.planNotFound);
      }
      final configured = await txn.query(
        'plan_exercises',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'sort_order ASC',
      );
      if (configured.isEmpty) {
        throw WorkoutStateException(WorkoutFailure.emptyPlan);
      }
      final now = clock();
      final local = now.toLocal();
      final localDate =
          '${local.year.toString().padLeft(4, '0')}-'
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
        if (i == 0) {
          await txn.update(
            'workout_sessions',
            {'current_session_exercise_id': exerciseId},
            where: 'id = ?',
            whereArgs: [sessionId],
          );
        }
        for (
          var number = 1;
          number <= (source['target_sets'] as int);
          number++
        ) {
          await txn.insert('session_sets', {
            'session_exercise_id': exerciseId,
            'set_number': number,
          });
        }
      }
      return sessionId;
    });
    return (await getSession(id))!;
  }

  Future<WorkoutSessionData> completeSet(
    int sessionId, {
    required int expectedExerciseId,
    required int expectedSetNumber,
  }) async {
    await db.transaction((txn) async {
      final session = await _activeRow(txn, sessionId);
      if (session['rest_end_at'] != null) {
        throw WorkoutStateException(WorkoutFailure.restActive);
      }
      if (session['current_session_exercise_id'] != expectedExerciseId ||
          session['current_set_number'] != expectedSetNumber) {
        throw WorkoutStateException(WorkoutFailure.positionChanged);
      }
      final exercise = (await txn.query(
        'session_exercises',
        where: 'session_id = ? AND id = ?',
        whereArgs: [sessionId, expectedExerciseId],
        limit: 1,
      )).single;
      final sequence = await txn.rawQuery(
        '''
        SELECT COALESCE(MAX(ss.completed_sequence), 0) AS last_sequence
        FROM session_sets ss JOIN session_exercises se ON se.id = ss.session_exercise_id
        WHERE se.session_id = ?
      ''',
        [sessionId],
      );
      final now = _nowMs;
      final changed = await txn.update(
        'session_sets',
        {
          'completed_at': now,
          'completed_sequence': (sequence.single['last_sequence'] as int) + 1,
        },
        where: 'session_exercise_id = ? AND set_number = ? AND completed_at IS NULL',
        whereArgs: [expectedExerciseId, expectedSetNumber],
      );
      if (changed != 1) {
        throw WorkoutStateException(WorkoutFailure.setAlreadyCompleted);
      }
      final pending = await _pendingSets(txn, sessionId);
      final same = pending
          .where((row) => row['exercise_id'] == expectedExerciseId)
          .firstOrNull;
      final next = same ?? pending.firstOrNull;
      final restSeconds = same != null
          ? exercise['rest_between_sets_seconds'] as int
          : next != null
          ? exercise['rest_after_exercise_seconds'] as int
          : 0;
      await txn.update(
        'workout_sessions',
        {
          'current_session_exercise_id':
              next?['exercise_id'] ?? expectedExerciseId,
          'current_exercise_order':
              next?['sort_order'] ?? exercise['sort_order'],
          'current_set_number': next?['set_number'] ?? expectedSetNumber,
          'rest_kind': restSeconds == 0
              ? null
              : same != null
              ? 'between_sets'
              : 'between_exercises',
          'rest_started_at': restSeconds == 0 ? null : now,
          'rest_end_at': restSeconds == 0 ? null : now + restSeconds * 1000,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> reorder(
    int sessionId,
    List<int> orderedIds, {
    required String expectedToken,
  }) async {
    return db.transaction((txn) async {
      await _activeRow(txn, sessionId);
      final data = (await _readSession(txn, sessionId))!;
      if (data.reorderToken != expectedToken) {
        throw WorkoutStateException(WorkoutFailure.workoutChanged);
      }
      final candidates = data.movableExercises;
      final existing = candidates.map((e) => e.id).toSet();
      if (!data.canReorder ||
          orderedIds.length != existing.length ||
          orderedIds.toSet().length != existing.length ||
          !orderedIds.toSet().containsAll(existing)) {
        throw WorkoutValidationException(WorkoutFailure.invalidOrder);
      }
      final slots = candidates.map((e) => e.sortOrder).toList();
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'session_exercises',
          {'sort_order': -slots[i]},
          where: 'id = ? AND session_id = ?',
          whereArgs: [orderedIds[i], sessionId],
        );
      }
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'session_exercises',
          {'sort_order': slots[i]},
          where: 'id = ? AND session_id = ?',
          whereArgs: [orderedIds[i], sessionId],
        );
      }
      final currentId = data.currentExercise.movable
          ? orderedIds.first
          : data.currentExercise.id;
      final current = (await txn.query(
        'session_exercises',
        where: 'id = ? AND session_id = ?',
        whereArgs: [currentId, sessionId],
      )).single;
      await txn.update(
        'workout_sessions',
        {
          'current_session_exercise_id': currentId,
          'current_exercise_order': current['sort_order'],
          'current_set_number': data.currentExercise.movable
              ? 1
              : data.currentSetNumber,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await _normalizeRest(txn, sessionId);
      return (await _readSession(txn, sessionId))!;
    });
  }

  Future<WorkoutSessionData> undoLastSet(int sessionId) async {
    await db.transaction((txn) async {
      await _activeRow(txn, sessionId);
      final rows = await txn.rawQuery(
        '''
        SELECT ss.id, ss.set_number, se.sort_order, se.id AS exercise_id
        FROM session_sets ss JOIN session_exercises se
          ON se.id = ss.session_exercise_id
        WHERE se.session_id = ? AND ss.completed_at IS NOT NULL
        ORDER BY ss.completed_sequence DESC, ss.completed_at DESC, ss.id DESC LIMIT 1
      ''',
        [sessionId],
      );
      if (rows.isEmpty) throw WorkoutStateException(WorkoutFailure.noSetToUndo);
      final last = rows.first;
      await txn.update(
        'session_sets',
        {'completed_at': null, 'completed_sequence': null},
        where: 'id = ?',
        whereArgs: [last['id']],
      );
      await txn.update(
        'workout_sessions',
        {
          'current_exercise_order': last['sort_order'],
          'current_session_exercise_id': last['exercise_id'],
          'current_set_number': last['set_number'],
          'rest_kind': null,
          'rest_started_at': null,
          'rest_end_at': null,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> adjustRest(int sessionId, int deltaSeconds) async {
    if (deltaSeconds % 30 != 0) {
      throw WorkoutValidationException(WorkoutFailure.invalidConfiguration);
    }
    await db.transaction((txn) async {
      final row = await _activeRow(txn, sessionId);
      final end = row['rest_end_at'] as int?;
      if (end == null) throw WorkoutStateException(WorkoutFailure.noRest);
      final updated = end + deltaSeconds * 1000;
      if (updated <= _nowMs) {
        await _clearRest(txn, sessionId);
      } else {
        await txn.update(
          'workout_sessions',
          {'rest_end_at': updated},
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> skipRest(int sessionId) async {
    await db.transaction((txn) async {
      final row = await _activeRow(txn, sessionId);
      if (row['rest_end_at'] == null) {
        throw WorkoutStateException(WorkoutFailure.noRest);
      }
      await _clearRest(txn, sessionId);
    });
    return (await getSession(sessionId))!;
  }

  Future<void> normalizeRest(int sessionId) =>
      db.transaction((txn) => _normalizeRest(txn, sessionId));

  Future<void> _normalizeRest(DatabaseExecutor txn, int sessionId) async {
    final rows = await txn.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['status'] != 'in_progress') return;
    final end = rows.first['rest_end_at'] as int?;
    if (end != null && end <= _nowMs) await _clearRest(txn, sessionId);
  }

  Future<WorkoutSessionData> updateExercise(
    int sessionId,
    int exerciseId, {
    required int targetSets,
    required int restBetweenSetsSeconds,
    required int restAfterExerciseSeconds,
  }) async {
    if (targetSets < 1 ||
        restBetweenSetsSeconds < 0 ||
        restAfterExerciseSeconds < 0 ||
        restBetweenSetsSeconds % 30 != 0 ||
        restAfterExerciseSeconds % 30 != 0) {
      throw WorkoutValidationException(WorkoutFailure.invalidConfiguration);
    }
    await db.transaction((txn) async {
      await _activeRow(txn, sessionId);
      final rows = await txn.query(
        'session_exercises',
        where: 'id = ? AND session_id = ?',
        whereArgs: [exerciseId, sessionId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw WorkoutStateException(WorkoutFailure.exerciseNotFound);
      }
      final exercise = rows.first;
      final countRows = await txn.rawQuery(
        '''
        SELECT COUNT(*) AS count FROM session_sets
        WHERE session_exercise_id = ? AND completed_at IS NOT NULL
      ''',
        [exerciseId],
      );
      final completed = countRows.first['count'] as int;
      if (completed == exercise['target_sets']) {
        throw WorkoutStateException(WorkoutFailure.completedExercise);
      }
      if (targetSets < completed) {
        throw WorkoutValidationException(WorkoutFailure.targetBelowCompleted);
      }
      final oldTarget = exercise['target_sets'] as int;
      if (targetSets > oldTarget) {
        for (var number = oldTarget + 1; number <= targetSets; number++) {
          await txn.insert('session_sets', {
            'session_exercise_id': exerciseId,
            'set_number': number,
          });
        }
      } else if (targetSets < oldTarget) {
        await txn.delete(
          'session_sets',
          where: 'session_exercise_id = ? AND set_number > ? AND completed_at IS NULL',
          whereArgs: [exerciseId, targetSets],
        );
      }
      await txn.update(
        'session_exercises',
        {
          'target_sets': targetSets,
          'rest_between_sets_seconds': restBetweenSetsSeconds,
          'rest_after_exercise_seconds': restAfterExerciseSeconds,
        },
        where: 'id = ?',
        whereArgs: [exerciseId],
      );
      await _repairCursor(txn, sessionId);
    });
    return (await getSession(sessionId))!;
  }

  Future<WorkoutSessionData> finish(int sessionId) async {
    await db.transaction((txn) async {
      final row = await _activeRow(txn, sessionId);
      final completed = await txn.rawQuery(
        '''
        SELECT COUNT(*) AS count FROM session_sets ss
        JOIN session_exercises se ON se.id = ss.session_exercise_id
        WHERE se.session_id = ? AND ss.completed_at IS NOT NULL
      ''',
        [sessionId],
      );
      if ((completed.first['count'] as int) == 0) {
        throw WorkoutStateException(WorkoutFailure.emptyWorkout);
      }
      final now = _nowMs;
      final duration = math.max(0, (now - (row['started_at'] as int)) ~/ 1000);
      await txn.update(
        'workout_sessions',
        {
          'status': 'completed',
          'ended_at': now,
          'duration_seconds': duration,
          'rest_kind': null,
          'rest_started_at': null,
          'rest_end_at': null,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
    return (await getSession(sessionId))!;
  }

  Future<void> discard(int sessionId) async {
    await db.transaction((txn) async {
      await _activeRow(txn, sessionId);
      await txn.delete(
        'workout_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<void> deleteHistory(int sessionId) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'workout_sessions',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      if (rows.isEmpty) {
        throw const HistoryDeleteException(HistoryDeleteFailure.notFound);
      }
      if (rows.single['status'] != 'completed') {
        throw const HistoryDeleteException(HistoryDeleteFailure.notSaved);
      }
      final deleted = await txn.delete(
        'workout_sessions',
        where: "id = ? AND status = 'completed'",
        whereArgs: [sessionId],
      );
      if (deleted != 1) {
        throw const HistoryDeleteException(HistoryDeleteFailure.notFound);
      }
    });
  }

  Future<List<WorkoutSessionData>> listHistory() async {
    final rows = await db.query(
      'workout_sessions',
      columns: ['id'],
      where: "status = 'completed'",
      orderBy: 'started_at DESC',
    );
    final result = <WorkoutSessionData>[];
    for (final row in rows) {
      result.add((await getSession(row['id'] as int))!);
    }
    return result;
  }

  Future<Map<String, Object?>> _activeRow(Transaction txn, int id) async {
    final rows = await txn.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['status'] != 'in_progress') {
      throw WorkoutStateException(WorkoutFailure.activeNotFound);
    }
    return rows.first;
  }

  Future<void> _clearRest(DatabaseExecutor txn, int id) async {
    await txn.update(
      'workout_sessions',
      {'rest_kind': null, 'rest_started_at': null, 'rest_end_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> _pendingSets(
    DatabaseExecutor txn,
    int id,
  ) => txn.rawQuery(
    '''
      SELECT se.id AS exercise_id, se.sort_order, ss.set_number
      FROM session_sets ss JOIN session_exercises se ON se.id = ss.session_exercise_id
      WHERE se.session_id = ? AND ss.completed_at IS NULL
      ORDER BY se.sort_order, ss.set_number
    ''',
    [id],
  );

  Future<void> _repairCursor(Transaction txn, int id) async {
    final row = (await txn.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    final pending = await _pendingSets(txn, id);
    if (pending.isEmpty) {
      final exercises = await txn.query(
        'session_exercises',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
      );
      if (exercises.isEmpty) return;
      final last =
          exercises
              .where((e) => e['id'] == row['current_session_exercise_id'])
              .firstOrNull ??
          exercises.last;
      await txn.update(
        'workout_sessions',
        {
          'current_session_exercise_id': last['id'],
          'current_exercise_order': last['sort_order'],
          'current_set_number': last['target_sets'],
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _clearRest(txn, id);
      return;
    }
    final current = pending
        .where((s) => s['exercise_id'] == row['current_session_exercise_id'])
        .firstOrNull;
    final next = current ?? pending.first;
    if (row['current_session_exercise_id'] != next['exercise_id'] ||
        row['current_set_number'] != next['set_number']) {
      await _clearRest(txn, id);
    }
    await txn.update(
      'workout_sessions',
      {
        'current_session_exercise_id': next['exercise_id'],
        'current_exercise_order': next['sort_order'],
        'current_set_number': next['set_number'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
