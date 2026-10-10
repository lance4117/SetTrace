enum PlanFailure {
  nameRequired,
  exerciseNameRequired,
  invalidSets,
  invalidRest,
  invalidWeight,
  invalidOrder,
}

class PlanValidationException extends ArgumentError {
  PlanValidationException(this.reason) : super(reason.name);
  final PlanFailure reason;
}
