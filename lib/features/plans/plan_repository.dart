import 'package:sqflite/sqflite.dart';

import 'plan_models.dart';

class PlanRepository {
  const PlanRepository(this.db);
  final Database db;

  Future<List<WorkoutPlan>> listPlans() async {
    final rows = await db.query('plans', orderBy: 'created_at ASC, id ASC');
    final result = <WorkoutPlan>[];
    for (final row in rows) {
      result.add(WorkoutPlan(
        id: row['id'] as int,
        name: row['name'] as String,
        exercises: await _exercises(row['id'] as int),
      ));
    }
    return result;
  }

  Future<WorkoutPlan?> getPlan(int id) async {
    final rows = await db.query('plans', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return WorkoutPlan(id: id, name: rows.first['name'] as String,
      exercises: await _exercises(id));
  }

  Future<List<PlanExercise>> _exercises(int planId) async {
    final rows = await db.query('plan_exercises', where: 'plan_id = ?',
      whereArgs: [planId], orderBy: 'sort_order ASC');
    return rows.map(PlanExercise.fromRow).toList();
  }

  Future<int> createPlan(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Plan name is required');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return db.insert('plans', {'name': trimmed, 'created_at': now, 'updated_at': now});
  }

  Future<void> renamePlan(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Plan name is required');
    await db.update('plans', {'name': trimmed,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePlan(int id) async {
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addExercise({required int planId, required String name,
    required int targetSets, required int restBetweenSetsSeconds,
    required int restAfterExerciseSeconds, double? defaultWeightKg}) async {
    _validate(name, targetSets, restBetweenSetsSeconds,
      restAfterExerciseSeconds, defaultWeightKg);
    return db.transaction((txn) async {
      final orderRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), 0) AS last_order FROM plan_exercises WHERE plan_id = ?',
        [planId]);
      final nextOrder = (orderRows.first['last_order'] as int) + 1;
      return txn.insert('plan_exercises', {
        'plan_id': planId, 'name': name.trim(), 'sort_order': nextOrder,
        'target_sets': targetSets,
        'rest_between_sets_seconds': restBetweenSetsSeconds,
        'rest_after_exercise_seconds': restAfterExerciseSeconds,
        'default_weight_kg': defaultWeightKg,
      });
    });
  }

  Future<void> updateExercise({required int id, required String name,
    required int targetSets, required int restBetweenSetsSeconds,
    required int restAfterExerciseSeconds, double? defaultWeightKg}) async {
    _validate(name, targetSets, restBetweenSetsSeconds,
      restAfterExerciseSeconds, defaultWeightKg);
    await db.update('plan_exercises', {
      'name': name.trim(), 'target_sets': targetSets,
      'rest_between_sets_seconds': restBetweenSetsSeconds,
      'rest_after_exercise_seconds': restAfterExerciseSeconds,
      'default_weight_kg': defaultWeightKg,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExercise(int id, int planId) async {
    await db.transaction((txn) async {
      await txn.delete('plan_exercises', where: 'id = ? AND plan_id = ?',
        whereArgs: [id, planId]);
      await _renumber(txn, planId);
    });
  }

  Future<void> reorder(int planId, List<int> orderedIds) async {
    await db.transaction((txn) async {
      final rows = await txn.query('plan_exercises', columns: ['id'],
        where: 'plan_id = ?', whereArgs: [planId]);
      final existing = rows.map((row) => row['id'] as int).toSet();
      if (orderedIds.length != existing.length ||
          orderedIds.toSet().length != existing.length ||
          !orderedIds.toSet().containsAll(existing)) {
        throw ArgumentError('Ordered IDs must contain every exercise exactly once');
      }
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('plan_exercises', {'sort_order': -(i + 1)},
          where: 'id = ? AND plan_id = ?', whereArgs: [orderedIds[i], planId]);
      }
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('plan_exercises', {'sort_order': i + 1},
          where: 'id = ? AND plan_id = ?', whereArgs: [orderedIds[i], planId]);
      }
    });
  }

  Future<void> _renumber(Transaction txn, int planId) async {
    final rows = await txn.query('plan_exercises', columns: ['id'],
      where: 'plan_id = ?', whereArgs: [planId], orderBy: 'sort_order ASC');
    for (var i = 0; i < rows.length; i++) {
      await txn.update('plan_exercises', {'sort_order': -(i + 1)},
        where: 'id = ?', whereArgs: [rows[i]['id']]);
    }
    for (var i = 0; i < rows.length; i++) {
      await txn.update('plan_exercises', {'sort_order': i + 1},
        where: 'id = ?', whereArgs: [rows[i]['id']]);
    }
  }

  void _validate(String name, int sets, int between, int after, double? weight) {
    if (name.trim().isEmpty) throw ArgumentError('Exercise name is required');
    if (sets < 1) throw ArgumentError('At least one set is required');
    if (between < 0 || after < 0 || between % 30 != 0 || after % 30 != 0) {
      throw ArgumentError('Rest must be a non-negative multiple of 30 seconds');
    }
    if (weight != null && weight <= 0) throw ArgumentError('Weight must be positive');
  }
}
