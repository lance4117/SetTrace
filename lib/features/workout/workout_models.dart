class SessionSet {
  const SessionSet({
    required this.id,
    required this.number,
    this.completedAt,
    this.completedSequence,
    this.skippedAt,
    this.skipBatchId,
  });
  final int id, number;
  final DateTime? completedAt;
  final int? completedSequence;
  final DateTime? skippedAt;
  final int? skipBatchId;
  bool get completed => completedAt != null;
  bool get skipped => skippedAt != null;
  bool get pending => !completed && !skipped;

  factory SessionSet.fromRow(Map<String, Object?> row) => SessionSet(
    id: row['id'] as int,
    number: row['set_number'] as int,
    completedSequence: row['completed_sequence'] as int?,
    skipBatchId: row['skip_batch_id'] as int?,
    skippedAt: row['skipped_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row['skipped_at'] as int,
            isUtc: true,
          ),
    completedAt: row['completed_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row['completed_at'] as int,
            isUtc: true,
          ),
  );
}

class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.targetSets,
    required this.restBetweenSetsSeconds,
    required this.restAfterExerciseSeconds,
    required this.sets,
    this.defaultWeightKg,
  });
  final int id, sortOrder, targetSets;
  final String name;
  final int restBetweenSetsSeconds, restAfterExerciseSeconds;
  final double? defaultWeightKg;
  final List<SessionSet> sets;
  int get completedSets => sets.where((set) => set.completed).length;
  bool get completed => completedSets == targetSets;
  int get skippedSets => sets.where((s) => s.skipped).length;
  int get pendingSets => sets.where((s) => s.pending).length;
  bool get resolved => pendingSets == 0;
  bool get movable => completedSets == 0 && skippedSets == 0 && !resolved;

  factory SessionExercise.fromRow(
    Map<String, Object?> row,
    List<SessionSet> sets,
  ) => SessionExercise(
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
  const WorkoutSessionData({
    required this.id,
    required this.planName,
    required this.startedAt,
    required this.startedLocalDate,
    required this.status,
    required this.currentExerciseOrder,
    required this.currentSetNumber,
    required this.exercises,
    this.endedAt,
    this.durationSeconds,
    this.restKind,
    this.restStartedAt,
    this.restEndAt,
    this.currentSessionExerciseId,
    this.lastSkipBatchId,
  });
  final int id;
  final String planName, startedLocalDate, status;
  final DateTime startedAt;
  final DateTime? endedAt, restStartedAt, restEndAt;
  final int? durationSeconds, currentSessionExerciseId;
  final int? lastSkipBatchId;
  final int currentExerciseOrder, currentSetNumber;
  final String? restKind;
  final List<SessionExercise> exercises;

  bool get inProgress => status == 'in_progress';
  bool get resting => restEndAt != null;
  int get completedSets =>
      exercises.fold(0, (sum, item) => sum + item.completedSets);
  int get totalSets => exercises.fold(0, (sum, item) => sum + item.targetSets);
  bool get allSetsCompleted => completedSets == totalSets;
  bool get hasPendingSets => exercises.any((e) => !e.resolved);
  bool get readyToFinish => !hasPendingSets;
  bool get canSkipRemaining =>
      inProgress &&
      currentExercise.completedSets > 0 &&
      currentExercise.pendingSets > 0 &&
      (!resting || restKind == 'between_sets');
  SessionExercise? get lastSkippedExercise => lastSkipBatchId == null
      ? null
      : exercises
            .where(
              (e) => e.sets.any(
                (s) => s.skipped && s.skipBatchId == lastSkipBatchId,
              ),
            )
            .firstOrNull;
  SessionExercise get currentExercise => exercises.firstWhere(
    (exercise) => currentSessionExerciseId != null
        ? exercise.id == currentSessionExerciseId
        : exercise.sortOrder == currentExerciseOrder,
  );
  SessionExercise? get nextExercise => exercises
      .where(
        (exercise) => exercise.id != currentExercise.id && !exercise.resolved,
      )
      .firstOrNull;
  List<SessionExercise> get movableExercises =>
      exercises.where((exercise) => exercise.movable).toList();
  bool get canReorder =>
      inProgress && hasPendingSets && movableExercises.length > 1;

  // Time passing or rest adjustments do not invalidate a sorting draft.
  String get reorderToken =>
      '$status:${currentExercise.id}:$currentSetNumber:'
      '${exercises.map((e) => '${e.id}/${e.targetSets}/'
          '${e.sets.map((s) => '${s.id}:${s.completedSequence}:${s.completedAt?.millisecondsSinceEpoch}:${s.skippedAt?.millisecondsSinceEpoch}:${s.skipBatchId}').join(',')}').join(';')}';
}
