import '../features/plans/plan_failure.dart';
import '../features/plans/plan_transfer.dart';
import '../features/workout/workout_failure.dart';
import 'generated/app_localizations.dart';

String transferLocationText(
  AppLocalizations strings,
  PlanTransferLocation location,
) {
  var result = location.exercise > 0
      ? strings.exerciseLocation(location.plan, location.exercise)
      : location.plan > 0
      ? strings.planLocation(location.plan)
      : strings.planContent;
  final field = switch (location.field) {
    null => null,
    PlanTransferField.name => strings.nameField,
    PlanTransferField.exercises => strings.exercisesField,
    PlanTransferField.sets => strings.setsLabel,
    PlanTransferField.betweenRest => strings.betweenSets,
    PlanTransferField.afterRest => strings.afterExerciseShort,
    PlanTransferField.weight => strings.weightField,
  };
  if (field != null) result = strings.fieldLocation(result, field);
  return result;
}

String failureText(AppLocalizations strings, Object error, {String? fallback}) {
  if (error is PlanValidationException) {
    return switch (error.reason) {
      PlanFailure.nameRequired => strings.planNameRequired,
      PlanFailure.exerciseNameRequired => strings.exerciseInvalid,
      PlanFailure.invalidSets => strings.invalidInteger(
        strings.setsLabel,
        1,
        100,
      ),
      PlanFailure.invalidRest => strings.invalidRest(strings.betweenSets),
      PlanFailure.invalidWeight => strings.invalidWeight(strings.weightField),
      PlanFailure.invalidOrder => strings.planOrderInvalid,
    };
  }
  if (error is PlanTransferException) {
    final location = transferLocationText(strings, error.location);
    return switch (error.code) {
      PlanTransferFailure.fileTooLarge => strings.fileTooLarge,
      PlanTransferFailure.emptyContent => strings.emptyContent,
      PlanTransferFailure.damagedContent => strings.damagedContent,
      PlanTransferFailure.wrongFormat => strings.wrongFormat,
      PlanTransferFailure.unsupportedVersion => strings.unsupportedVersion,
      PlanTransferFailure.noImportPlans => strings.noImportPlans,
      PlanTransferFailure.selectPlans => strings.selectPlans,
      PlanTransferFailure.clipboardCopyFailed => strings.clipboardCopyFailed,
      PlanTransferFailure.clipboardReadFailed => strings.clipboardReadFailed,
      PlanTransferFailure.clipboardEmpty => strings.clipboardEmpty,
      PlanTransferFailure.fileBusy => strings.fileBusy,
      PlanTransferFailure.fileIncomplete => strings.fileIncomplete,
      PlanTransferFailure.fileOperationFailed => strings.fileOperationFailed,
      PlanTransferFailure.fileUnsupported => strings.fileUnsupported,
      PlanTransferFailure.fileNotDownloads => strings.fileNotDownloads,
      PlanTransferFailure.fileReadFailed => strings.fileReadFailed,
      PlanTransferFailure.fileEmpty => strings.fileEmpty,
      PlanTransferFailure.filePickerFailed => strings.filePickerFailed,
      PlanTransferFailure.permissionDenied => strings.permissionDenied,
      PlanTransferFailure.fileSaveFailed => strings.fileSaveFailed,
      PlanTransferFailure.plansChanged => strings.plansChanged,
      PlanTransferFailure.invalidObject => strings.invalidObject(location),
      PlanTransferFailure.invalidName => strings.invalidName(
        location,
        error.max,
      ),
      PlanTransferFailure.invalidInteger => strings.invalidInteger(
        location,
        error.min,
        error.max,
      ),
      PlanTransferFailure.invalidRest => strings.invalidRest(location),
      PlanTransferFailure.invalidWeight => strings.invalidWeight(location),
      PlanTransferFailure.invalidExercises => strings.invalidExercises(
        location,
      ),
    };
  }
  final reason = switch (error) {
    WorkoutStateException e => e.reason,
    WorkoutValidationException e => e.reason,
    _ => null,
  };
  return switch (reason) {
    WorkoutFailure.planNotFound => strings.planNotFound,
    WorkoutFailure.activeExists => strings.activeExists,
    WorkoutFailure.exerciseNotFound => strings.exerciseNotFound,
    WorkoutFailure.emptyPlan => strings.emptyPlan,
    WorkoutFailure.restActive => strings.restActive,
    WorkoutFailure.positionChanged => strings.positionChanged,
    WorkoutFailure.setAlreadyCompleted => strings.setAlreadyCompleted,
    WorkoutFailure.workoutChanged => strings.workoutChanged,
    WorkoutFailure.invalidOrder => strings.invalidOrder,
    WorkoutFailure.noSetToUndo => strings.noSetToUndo,
    WorkoutFailure.invalidConfiguration => strings.invalidConfiguration,
    WorkoutFailure.noRest => strings.noRest,
    WorkoutFailure.completedExercise => strings.completedExercise,
    WorkoutFailure.targetBelowCompleted => strings.targetBelowCompleted,
    WorkoutFailure.emptyWorkout => strings.emptyWorkout,
    WorkoutFailure.activeNotFound => strings.activeNotFound,
    WorkoutFailure.sessionEnded => strings.sessionEnded,
    null => fallback ?? strings.operationFailed,
  };
}
