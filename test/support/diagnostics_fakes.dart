import 'dart:convert';

import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';

class FakeDiagnosticsTransport implements DiagnosticsTransport {
  final events = <Map<String, dynamic>>[];
  final calls = <String>[];
  final failMethods = <String>{};
  Future<Map<String, Object?>> Function(String, Map<String, Object?>)?
  intercept;
  bool enabled = true;
  String generation = 'a' * 32;
  int bytes = 0, eventCount = 0;
  List<String> missing = [];
  bool limited = false;
  DateTime? firstTime, lastTime, detailedUntil;
  String exportId = 'd' * 32;
  DiagnosticExportStage stage = DiagnosticExportStage.collecting;
  bool autoComplete = true;
  bool hasExport = false;
  final exportMissing = <String>[];
  Map<String, Object?> overview() => {
    'enabled': enabled,
    'generation': generation,
    'bytes': bytes,
    'event_count': eventCount,
    'first_time': firstTime?.millisecondsSinceEpoch,
    'last_time': lastTime?.millisecondsSinceEpoch,
    'detailed_until': detailedUntil?.millisecondsSinceEpoch,
    'missing': List<String>.of(missing),
    'limited': limited,
  };
  Map<String, Object?> status() => {
    'export_id': exportId,
    'stage': stage.name,
    'cancellable': {
      DiagnosticExportStage.collecting,
      DiagnosticExportStage.packaging,
      DiagnosticExportStage.writing_unpublished,
      DiagnosticExportStage.verifying,
    }.contains(stage),
    if ({
      DiagnosticExportStage.saved,
      DiagnosticExportStage.saved_partial,
    }.contains(stage)) ...{
      'file_name':
          'SetTrace-diagnostics-2026-10-24-a-long-verified-report-name.zip',
      'bytes': 1200,
    },
    'missing': List<String>.of(exportMissing),
    if (stage == DiagnosticExportStage.unknown) 'reason': 'publication_unknown',
    if (stage == DiagnosticExportStage.failed) 'reason': 'storage_unavailable',
  };
  @override
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    if (failMethods.contains(method)) {
      throw const DiagnosticsFailure('injected');
    }
    if (intercept case final handler?) return handler(method, arguments);
    switch (method) {
      case 'recordBatch':
        for (final text in arguments['records'] as List) {
          events.add(jsonDecode(text as String) as Map<String, dynamic>);
        }
        return {'accepted': true};
      case 'overview':
        return overview();
      case 'setEnabled':
        enabled = arguments['enabled'] as bool;
        if (!enabled) detailedUntil = null;
        return overview();
      case 'setDetailed':
        if (!enabled) throw const DiagnosticsFailure('user_disabled');
        detailedUntil = arguments['enabled'] == true
            ? DateTime.now().add(const Duration(minutes: 30))
            : null;
        return overview();
      case 'clear':
        generation = generation == 'a' * 32 ? 'b' * 32 : 'a' * 32;
        bytes = 0;
        eventCount = 0;
        firstTime = null;
        lastTime = null;
        return overview();
      case 'requestExportPermission':
      case 'openAppSettings':
        return {};
      case 'startExport':
        hasExport = true;
        stage = DiagnosticExportStage.collecting;
        return status();
      case 'exportStatus':
        if (autoComplete) {
          stage = exportMissing.isEmpty
              ? DiagnosticExportStage.saved
              : DiagnosticExportStage.saved_partial;
        }
        return status();
      case 'cancelExport':
        if (status()['cancellable'] == true) {
          stage = DiagnosticExportStage.cancelled;
        }
        return status();
      case 'inspectExport':
        if (!hasExport) throw const DiagnosticsFailure('missing');
        return status();
      default:
        throw const DiagnosticsFailure('unsupported');
    }
  }
}
