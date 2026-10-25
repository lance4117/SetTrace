import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostic_observation.dart';

enum PlanFailure {
  nameRequired,
  exerciseNameRequired,
  invalidSets,
  invalidRest,
  invalidWeight,
  invalidOrder,
}

class PlanValidationException extends ArgumentError
    implements DiagnosticClassifiedFailure {
  PlanValidationException(this.reason) : super(reason.name);
  final PlanFailure reason;
  @override
  DiagnosticReason get diagnosticReason => reason == PlanFailure.invalidOrder
      ? DiagnosticReason.condition_mismatch
      : DiagnosticReason.validation;
  @override
  bool get diagnosticRejection => true;
}
