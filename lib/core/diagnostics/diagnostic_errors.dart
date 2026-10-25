import 'package:flutter/foundation.dart';

import 'diagnostic_contract.dart';
import 'diagnostics_client.dart';

/// Keep Flutter and root-isolate handling semantics, including the previous
/// handler's return value. Isolate.run failures propagate to their caller's
/// observation scope; no error listener changes an isolate's termination.
VoidCallback installDiagnosticErrorHandlers(DiagnosticsClient client) {
  final flutterPrevious = FlutterError.onError;
  final platformPrevious = PlatformDispatcher.instance.onError;
  void record(StackTrace? stack) => client.event(
    DiagnosticName.errorUnhandled,
    phase: DiagnosticPhase.failed,
    outcome: DiagnosticOutcome.unknown,
    reason: DiagnosticReason.unhandled,
    level: DiagnosticSeverity.error,
    stack: stack,
  );
  void flutterHandler(FlutterErrorDetails details) {
    try {
      record(details.stack);
    } catch (_) {}
    flutterPrevious?.call(details);
  }

  bool platformHandler(Object error, StackTrace stack) {
    try {
      record(stack);
    } catch (_) {}
    return platformPrevious?.call(error, stack) ?? false;
  }

  FlutterError.onError = flutterHandler;
  PlatformDispatcher.instance.onError = platformHandler;
  return () {
    if (identical(FlutterError.onError, flutterHandler)) {
      FlutterError.onError = flutterPrevious;
    }
    if (identical(PlatformDispatcher.instance.onError, platformHandler)) {
      PlatformDispatcher.instance.onError = platformPrevious;
    }
  };
}
