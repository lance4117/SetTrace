import 'package:sqflite/sqflite.dart';

import 'plan_models.dart';
import 'plan_failure.dart';
import 'plan_transfer.dart';

class PlanRepository {
  const PlanRepository(this.db);
  final Database db;
  Future<List<TransferPlan>> exportPlans(Set<int> selectedIds) async {
    if (selectedIds.isEmpty) {
      throw const PlanTransferException(PlanTransferFailure.selectPlans);
    }
    return db.transaction((txn) async {
      final rows = await txn.query('plans', orderBy: 'created_at ASC, id ASC');
      final selected = rows
          .where((row) => selectedIds.contains(row['id']))
          .toList();
      if (selected.length != selectedIds.length) {
        throw const PlanTransferException(PlanTransferFailure.plansChanged);
      }
      final plans = <TransferPlan>[];
      for (final row in selected) {
        final exercises = await txn.query(
          'plan_exercises',
          where: 'plan_id = ?',
          whereArgs: [row['id']],
          orderBy: 'sort_order ASC',
        );
        plans.add(
          TransferPlan.fromPlan(
            WorkoutPlan(
              id: row['id'] as int,
              name: row['name'] as String,
              exercises: exercises.map(PlanExercise.fromRow).toList(),
            ),
          ),
        );
      }
      return plans;
    });
  }

  Future<List<TransferPlan>> previewImport(
    List<TransferPlan> plans, {
    required ImportSuffix suffixFor,
  }) async {
    final rows = await db.query('plans', columns: ['name']);
    return resolveImportNames(
      plans,
      rows.map((row) => row['name'] as String),
      suffixFor: suffixFor,
    );
  }

  Future<List<int>> importPlans(
    List<TransferPlan> plans, {
    required ImportSuffix suffixFor,
  }) async {
    // The source byte limit is checked by decode; validate edited fields here.
    // Re-encoding with export indentation must not reject a valid compact input.
    const PlanTransferCodec().validatePlans(plans);
    return db.transaction((txn) async {
      final rows = await txn.query('plans', columns: ['name']);
      final resolved = resolveImportNames(
        plans,
        rows.map((row) => row['name'] as String),
        suffixFor: suffixFor,
      );
      if (Iterable<int>.generate(plans.length)
          .any((i) => resolved[i].name != plans[i].name.trim())) {
        throw ImportNameConflict(resolved);
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final ids = <int>[];
      for (final plan in plans) {
        final id = await txn.insert('plans', {
          'name': plan.name.trim(),
          'created_at': now,
          'updated_at': now,
        });
        ids.add(id);
        for (var i = 0; i < plan.exercises.length; i++) {
          final e = plan.exercises[i];
          await txn.insert('plan_exercises', {
            'plan_id': id,
            'name': e.name.trim(),
            'sort_order': i + 1,
            'target_sets': e.targetSets,
            'rest_between_sets_seconds': e.restBetweenSetsSeconds,
            'rest_after_exercise_seconds': e.restAfterExerciseSeconds,
            'default_weight_kg': e.defaultWeightKg,
          });
        }
      }
      return ids;
    });
  }

  Future<List<WorkoutPlan>> listPlans() async {
    final rows = await db.query('plans', orderBy: 'created_at ASC, id ASC');
    final result = <WorkoutPlan>[];
    for (final row in rows) {
      result.add(
        WorkoutPlan(
          id: row['id'] as int,
          name: row['name'] as String,
          exercises: await _exercises(row['id'] as int),
        ),
      );
    }
    return result;
  }

  Future<WorkoutPlan?> getPlan(int id) async {
    final rows = await db.query(
      'plans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkoutPlan(
      id: id,
      name: rows.first['name'] as String,
      exercises: await _exercises(id),
    );
  }

  Future<List<PlanExercise>> _exercises(int planId) async {
    final rows = await db.query(
      'plan_exercises',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(PlanExercise.fromRow).toList();
  }

  Future<int> createPlan(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw PlanValidationException(PlanFailure.nameRequired);
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return db.insert('plans', {
      'name': trimmed,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> renamePlan(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw PlanValidationException(PlanFailure.nameRequired);
    }
    await db.update(
      'plans',
      {
        'name': trimmed,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlan(int id) async {
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addExercise({
    required int planId,
    required String name,
    required int targetSets,
    required int restBetweenSetsSeconds,
    required int restAfterExerciseSeconds,
    double? defaultWeightKg,
  }) async {
    _validate(
      name,
      targetSets,
      restBetweenSetsSeconds,
      restAfterExerciseSeconds,
      defaultWeightKg,
    );
    return db.transaction((txn) async {
      final orderRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), 0) AS last_order FROM plan_exercises WHERE plan_id = ?',
        [planId],
      );
      final nextOrder = (orderRows.first['last_order'] as int) + 1;
      return txn.insert('plan_exercises', {
        'plan_id': planId,
        'name': name.trim(),
        'sort_order': nextOrder,
        'target_sets': targetSets,
        'rest_between_sets_seconds': restBetweenSetsSeconds,
        'rest_after_exercise_seconds': restAfterExerciseSeconds,
        'default_weight_kg': defaultWeightKg,
      });
    });
  }

  Future<void> updateExercise({
    required int id,
    required String name,
    required int targetSets,
    required int restBetweenSetsSeconds,
    required int restAfterExerciseSeconds,
    double? defaultWeightKg,
  }) async {
    _validate(
      name,
      targetSets,
      restBetweenSetsSeconds,
      restAfterExerciseSeconds,
      defaultWeightKg,
    );
    await db.update(
      'plan_exercises',
      {
        'name': name.trim(),
        'target_sets': targetSets,
        'rest_between_sets_seconds': restBetweenSetsSeconds,
        'rest_after_exercise_seconds': restAfterExerciseSeconds,
        'default_weight_kg': defaultWeightKg,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExercise(int id, int planId) async {
    await db.transaction((txn) async {
      await txn.delete(
        'plan_exercises',
        where: 'id = ? AND plan_id = ?',
        whereArgs: [id, planId],
      );
      await _renumber(txn, planId);
    });
  }

  Future<void> reorder(int planId, List<int> orderedIds) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'plan_exercises',
        columns: ['id'],
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
      final existing = rows.map((row) => row['id'] as int).toSet();
      if (orderedIds.length != existing.length ||
          orderedIds.toSet().length != existing.length ||
          !orderedIds.toSet().containsAll(existing)) {
        throw PlanValidationException(PlanFailure.invalidOrder);
      }
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'plan_exercises',
          {'sort_order': -(i + 1)},
          where: 'id = ? AND plan_id = ?',
          whereArgs: [orderedIds[i], planId],
        );
      }
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'plan_exercises',
          {'sort_order': i + 1},
          where: 'id = ? AND plan_id = ?',
          whereArgs: [orderedIds[i], planId],
        );
      }
    });
  }

  Future<void> _renumber(Transaction txn, int planId) async {
    final rows = await txn.query(
      'plan_exercises',
      columns: ['id'],
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'sort_order ASC',
    );
    for (var i = 0; i < rows.length; i++) {
      await txn.update(
        'plan_exercises',
        {'sort_order': -(i + 1)},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
    for (var i = 0; i < rows.length; i++) {
      await txn.update(
        'plan_exercises',
        {'sort_order': i + 1},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
  }

  void _validate(
    String name,
    int sets,
    int between,
    int after,
    double? weight,
  ) {
    if (name.trim().isEmpty) {
      throw PlanValidationException(PlanFailure.exerciseNameRequired);
    }
    if (sets < 1) throw PlanValidationException(PlanFailure.invalidSets);
    if (between < 0 || after < 0 || between % 30 != 0 || after % 30 != 0) {
      throw PlanValidationException(PlanFailure.invalidRest);
    }
    if (weight != null && (!weight.isFinite || weight <= 0)) {
      throw PlanValidationException(PlanFailure.invalidWeight);
    }
  }
}
