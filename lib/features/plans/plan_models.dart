class WorkoutPlan {
  const WorkoutPlan({required this.id, required this.name, required this.exercises});

  final int id;
  final String name;
  final List<PlanExercise> exercises;

  int get totalSets => exercises.fold(0, (sum, item) => sum + item.targetSets);
}

class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.planId,
    required this.name,
    required this.sortOrder,
    required this.targetSets,
    required this.restBetweenSetsSeconds,
    required this.restAfterExerciseSeconds,
    this.defaultWeightKg,
  });

  final int id, planId, sortOrder, targetSets;
  final String name;
  final int restBetweenSetsSeconds, restAfterExerciseSeconds;
  final double? defaultWeightKg;

  factory PlanExercise.fromRow(Map<String, Object?> row) => PlanExercise(
    id: row['id'] as int,
    planId: row['plan_id'] as int,
    name: row['name'] as String,
    sortOrder: row['sort_order'] as int,
    targetSets: row['target_sets'] as int,
    restBetweenSetsSeconds: row['rest_between_sets_seconds'] as int,
    restAfterExerciseSeconds: row['rest_after_exercise_seconds'] as int,
    defaultWeightKg: (row['default_weight_kg'] as num?)?.toDouble(),
  );
}
