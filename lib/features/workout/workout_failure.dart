import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostic_observation.dart';

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
  cannotSkip,
  noSkipToUndo,
  skippedExercise,
}

DiagnosticReason _diagnosticReason(WorkoutFailure reason) => switch (reason) {
  WorkoutFailure.activeExists => DiagnosticReason.active_session,
  WorkoutFailure.positionChanged ||
  WorkoutFailure.workoutChanged ||
  WorkoutFailure.setAlreadyCompleted => DiagnosticReason.stale_position,
  WorkoutFailure.exerciseNotFound ||
  WorkoutFailure.activeNotFound ||
  WorkoutFailure.planNotFound => DiagnosticReason.not_found,
  WorkoutFailure.emptyWorkout => DiagnosticReason.no_completed_sets,
  WorkoutFailure.completedExercise ||
  WorkoutFailure.skippedExercise ||
  WorkoutFailure.cannotSkip => DiagnosticReason.position_locked,
  WorkoutFailure.sessionEnded => DiagnosticReason.invalid_session,
  WorkoutFailure.noRest ||
  WorkoutFailure.noSetToUndo ||
  WorkoutFailure.noSkipToUndo => DiagnosticReason.not_available,
  WorkoutFailure.restActive => DiagnosticReason.condition_mismatch,
  _ => DiagnosticReason.validation,
};

class WorkoutStateException extends StateError
    implements DiagnosticClassifiedFailure {
  WorkoutStateException(this.reason) : super(reason.name);
  final WorkoutFailure reason;
  @override
  DiagnosticReason get diagnosticReason => _diagnosticReason(reason);
  @override
  bool get diagnosticRejection => true;
}

class WorkoutValidationException extends ArgumentError
    implements DiagnosticClassifiedFailure {
  WorkoutValidationException(this.reason) : super(reason.name);
  final WorkoutFailure reason;
  @override
  DiagnosticReason get diagnosticReason => _diagnosticReason(reason);
  @override
  bool get diagnosticRejection => true;
}
