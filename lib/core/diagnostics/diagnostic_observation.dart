import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'diagnostic_contract.dart';
import 'diagnostics_client.dart';

abstract interface class DiagnosticClassifiedFailure {
  DiagnosticReason get diagnosticReason;
  bool get diagnosticRejection;
}

final Object _scopeKey = Object();
final Object _transactionKey = Object();
final Object _triggerKey = Object();
final Object _epochKey = Object();
final Object _fixedEpochKey = Object();
final Object _restCancellationKey = Object();
DiagnosticValue get diagnosticTrigger =>
    Zone.current[_triggerKey] as DiagnosticValue? ?? DiagnosticValue.unknown;

DiagnosticValue get diagnosticRestCancellation =>
    switch (DiagnosticScope.current?.operation.name) {
      DiagnosticName.restAcknowledge => DiagnosticValue.acknowledge,
      DiagnosticName.workoutRestEnd => DiagnosticValue.manual_rest_end,
      DiagnosticName.workoutRestAdjust => DiagnosticValue.deadline_replaced,
      DiagnosticName.workoutUndoComplete => DiagnosticValue.undo_complete,
      DiagnosticName.workoutRestoreSkipped => DiagnosticValue.restore_skipped,
      DiagnosticName.workoutSkipRemaining => DiagnosticValue.skip_remaining,
      DiagnosticName.workoutComplete => DiagnosticValue.training_advance,
      DiagnosticName.workoutSave => DiagnosticValue.workout_saved,
      DiagnosticName.workoutDiscard => DiagnosticValue.workout_discarded,
      _ =>
        Zone.current[_restCancellationKey] as DiagnosticValue? ??
            DiagnosticValue.platform_cleanup,
    };

/// Capture before serial queuing. Re-enter only the captured immutable context.
class DiagnosticContext {
  DiagnosticContext.capture(this.trigger, {int? epoch})
    : scope = DiagnosticScope.current,
      cancellation = diagnosticRestCancellation,
      epoch = DiagnosticScope.current?.operation.epoch ?? epoch;
  final DiagnosticScope? scope;
  final int? epoch;
  final DiagnosticValue trigger;
  final DiagnosticValue cancellation;
  Future<T> run<T>(Future<T> Function() action) => runZoned(
    action,
    zoneValues: {
      _scopeKey: scope,
      _triggerKey: trigger,
      _epochKey: epoch,
      _fixedEpochKey: true,
      _restCancellationKey: cancellation,
    },
  );
}

class DiagnosticScope {
  DiagnosticScope(
    this.operation, {
    required this.writeIntent,
    this.visible = true,
    this.ancestor,
  });
  final DiagnosticOperation operation;
  final bool writeIntent;
  final bool visible;
  final String? ancestor;
  String? get visibleOperation => visible ? operation.id : ancestor;
  bool committed = false;
  bool rollbackConfirmed = false;
  bool followupFailed = false;
  DiagnosticPhase phase = DiagnosticPhase.transaction;
  static DiagnosticScope? get current =>
      Zone.current[_scopeKey] as DiagnosticScope?;
  void commit({Map<DiagnosticField, Object> fields = const {}}) {
    if (!writeIntent || committed) return;
    committed = true;
    operation.emit(
      DiagnosticPhase.committed,
      DiagnosticOutcome.committed,
      fields: fields,
    );
  }

  void followupFailure(Object error, StackTrace stack, {DiagnosticPhase? at}) {
    followupFailed = true;
    operation.emit(
      at ?? phase,
      committed ? DiagnosticOutcome.partial_success : DiagnosticOutcome.unknown,
      reason: committed
          ? DiagnosticReason.followup_failed
          : diagnosticFailureReason(error),
      level: DiagnosticSeverity.error,
      stack: stack,
    );
  }
}

DiagnosticReason diagnosticFailureReason(Object error) {
  if (error is DiagnosticClassifiedFailure) return error.diagnosticReason;
  if (error is DatabaseException) return DiagnosticReason.sqlite;
  if (error is FileSystemException) return DiagnosticReason.io;
  if (error is FormatException) return DiagnosticReason.invalid_format;
  if (error is PlatformException) return DiagnosticReason.platform;
  if (error is StateError) return DiagnosticReason.state;
  if (error is ArgumentError) return DiagnosticReason.validation;
  return DiagnosticReason.unknown;
}

/// An observation scope never changes exceptions or drives retries. Only an
/// explicit transaction return confirms commit before subsequent refresh work.
Future<T> diagnosticObserve<T>(
  DiagnosticsClient client,
  DiagnosticName name,
  Future<T> Function() action, {
  Map<DiagnosticObject, Object> objects = const {},
  Map<DiagnosticField, Object> fields = const {},
  bool readOnly = false,
  bool recordSuccess = true,
  bool inferCommitOnSuccess = true,
  bool nestReadScope = false,
  String? parentOperation,
  String? backupOperation,
  Map<DiagnosticObject, Object> Function(T value)? resultObjects,
  Map<DiagnosticField, Object> Function(T value)? resultFields,
}) async {
  if (client.transport == null || client.current?.enabled == false) {
    return action();
  }
  final parent = DiagnosticScope.current;
  final detailedRead =
      readOnly &&
      !recordSuccess &&
      client.current?.detailedUntil?.isAfter(DateTime.now()) == true;
  if (readOnly && parent != null && !nestReadScope) return action();
  late final DiagnosticOperation operation;
  try {
    operation = client.operation(
      name,
      objects: objects,
      fields: fields,
      parent: parentOperation ?? parent?.visibleOperation,
      backupOperation: backupOperation ?? parent?.operation.backupOperation,
      begin: !readOnly || recordSuccess,
      epoch: Zone.current[_epochKey] as int?,
      fixedEpoch: Zone.current[_fixedEpochKey] == true,
    );
  } catch (_) {
    return action();
  }
  final scope = DiagnosticScope(
    operation,
    writeIntent: !readOnly,
    visible: !readOnly || recordSuccess || detailedRead,
    ancestor: parentOperation ?? parent?.visibleOperation,
  );
  return runZoned(() async {
    try {
      final result = await action();
      Map<DiagnosticObject, Object> references = const {};
      Map<DiagnosticField, Object> details = const {};
      // Observability projections may fail independently of the business result.
      try {
        references = resultObjects?.call(result) ?? const {};
        details = resultFields?.call(result) ?? const {};
      } catch (_) {}
      if (!readOnly && inferCommitOnSuccess && !scope.committed) {
        scope.commit(fields: details);
      }
      if (recordSuccess || detailedRead) {
        operation.emit(
          DiagnosticPhase.completed,
          scope.followupFailed
              ? (scope.committed
                    ? DiagnosticOutcome.partial_success
                    : DiagnosticOutcome.unknown)
              : scope.committed
              ? DiagnosticOutcome.committed
              : DiagnosticOutcome.observed,
          fields: details,
          level: detailedRead
              ? DiagnosticSeverity.debug
              : DiagnosticSeverity.info,
          resultObjects: references,
        );
      }
      return result;
    } catch (error, stack) {
      final expected = error is DiagnosticClassifiedFailure
          ? error.diagnosticRejection
          : error is ArgumentError;
      operation.emit(
        scope.committed
            ? scope.phase
            : expected
            ? DiagnosticPhase.validation
            : DiagnosticPhase.failed,
        scope.committed
            ? DiagnosticOutcome.partial_success
            : expected
            ? DiagnosticOutcome.rejected
            : scope.rollbackConfirmed
            ? DiagnosticOutcome.rolled_back_confirmed
            : DiagnosticOutcome.unknown,
        reason: scope.committed
            ? DiagnosticReason.followup_failed
            : diagnosticFailureReason(error),
        level: expected && !scope.committed
            ? DiagnosticSeverity.info
            : DiagnosticSeverity.error,
        stack: expected && !scope.committed ? null : stack,
      );
      rethrow;
    }
  }, zoneValues: {_scopeKey: scope});
}

class _Correction {
  const _Correction(
    this.client,
    this.name,
    this.reason,
    this.objects,
    this.fields,
  );
  final DiagnosticsClient client;
  final DiagnosticName name;
  final DiagnosticReason reason;
  final Map<DiagnosticObject, Object> objects;
  final Map<DiagnosticField, Object> fields;
}

void diagnosticCorrection(
  DiagnosticsClient client,
  DiagnosticName name, {
  required DiagnosticReason reason,
  Map<DiagnosticObject, Object> objects = const {},
  Map<DiagnosticField, Object> fields = const {},
}) {
  final pending = Zone.current[_transactionKey] as List<_Correction>?;
  if (pending != null && pending.length < 32) {
    pending.add(_Correction(client, name, reason, objects, fields));
  }
}

Future<T> diagnosticTransaction<T>(
  Database database,
  Future<T> Function(Transaction) action,
) async {
  final scope = DiagnosticScope.current;
  final corrections = <_Correction>[];
  Object? callbackError;
  try {
    final result = await runZoned(
      () => database.transaction((transaction) async {
        try {
          return await action(transaction);
        } catch (error) {
          callbackError = error;
          rethrow;
        }
      }),
      zoneValues: {_transactionKey: corrections},
    );
    scope?.commit();
    for (final correction in corrections) {
      correction.client.event(
        correction.name,
        phase: DiagnosticPhase.committed,
        outcome: DiagnosticOutcome.committed,
        reason: correction.reason,
        objects: correction.objects,
        fields: correction.fields,
        parent: scope?.visibleOperation,
      );
    }
    return result;
  } catch (error) {
    // sqflite completes the failed transaction after rollback. If rollback or
    // commit itself instead raised a different exception, the outcome is unknown.
    if (scope != null &&
        callbackError != null &&
        identical(callbackError, error)) {
      scope.rollbackConfirmed = true;
    }
    rethrow;
  }
}
