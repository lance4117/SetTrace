enum WorkoutFailure {
  activeExists,
  emptyPlan,
  restActive,
  positionChanged,
  setAlreadyCompleted,
  workoutChanged,
  invalidOrder,
  noSetToUndo,
  noRest,
  invalidConfiguration,
  exerciseNotFound,
  completedExercise,
  targetBelowCompleted,
  emptyWorkout,
  activeNotFound,
  sessionEnded,
  planNotFound,
}

class WorkoutStateException extends StateError {
  WorkoutStateException(this.reason) : super(reason.name);
  final WorkoutFailure reason;
}

class WorkoutValidationException extends ArgumentError {
  WorkoutValidationException(this.reason) : super(reason.name);
  final WorkoutFailure reason;
}
