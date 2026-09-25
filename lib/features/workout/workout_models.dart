class SessionSet {
  const SessionSet({required this.id, required this.number, this.completedAt});
  final int id, number;
  final DateTime? completedAt;
  bool get completed => completedAt != null;

  factory SessionSet.fromRow(Map<String, Object?> row) => SessionSet(
    id: row['id'] as int,
    number: row['set_number'] as int,
    completedAt: row['completed_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(
      row['completed_at'] as int, isUtc: true),
  );
}

class SessionExercise {
  const SessionExercise({required this.id, required this.name, required this.sortOrder,
    required this.targetSets, required this.restBetweenSetsSeconds,
    required this.restAfterExerciseSeconds, required this.sets,
    this.defaultWeightKg});

  final int id, sortOrder, targetSets;
  final String name;
  final int restBetweenSetsSeconds, restAfterExerciseSeconds;
  final double? defaultWeightKg;
  final List<SessionSet> sets;
  int get completedSets => sets.where((set) => set.completed).length;

  factory SessionExercise.fromRow(Map<String, Object?> row, List<SessionSet> sets) =>
      SessionExercise(
        id: row['id'] as int,
        name: row['name_snapshot'] as String,
        sortOrder: row['sort_order'] as int,
        targetSets: row['target_sets'] as int,
        restBetweenSetsSeconds: row['rest_between_sets_seconds'] as int,
        restAfterExerciseSeconds: row['rest_after_exercise_seconds'] as int,
        defaultWeightKg: (row['default_weight_kg'] as num?)?.toDouble(),
        sets: sets,
      );
}

class WorkoutSessionData {
  const WorkoutSessionData({required this.id, required this.planName,
    required this.startedAt, required this.startedLocalDate,
    required this.status, required this.currentExerciseOrder,
    required this.currentSetNumber, required this.exercises,
    this.endedAt, this.durationSeconds, this.restKind,
    this.restStartedAt, this.restEndAt});

  final int id;
  final String planName, startedLocalDate, status;
  final DateTime startedAt;
  final DateTime? endedAt, restStartedAt, restEndAt;
  final int? durationSeconds;
  final int currentExerciseOrder, currentSetNumber;
  final String? restKind;
  final List<SessionExercise> exercises;

  bool get inProgress => status == 'in_progress';
  bool get resting => restEndAt != null;
  int get completedSets => exercises.fold(0, (sum, item) => sum + item.completedSets);
  int get totalSets => exercises.fold(0, (sum, item) => sum + item.targetSets);
  bool get allSetsCompleted => completedSets == totalSets;
  SessionExercise get currentExercise => exercises[currentExerciseOrder - 1];
  SessionExercise? get nextExercise => currentExerciseOrder < exercises.length
      ? exercises[currentExerciseOrder] : null;
}
