import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';

class _Transport implements DiagnosticsTransport {
  final calls = <String>[];
  final records = <String>[];
  bool fail = false;
  bool enabled = true;
  String generation = 'b' * 32;
  @override
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    calls.add(method);
    if (fail) throw StateError('private exception must not escape a log call');
    if (method == 'recordBatch') {
      records.addAll(List<String>.from(arguments['records'] as List));
    }
    if (method == 'setEnabled') enabled = arguments['enabled'] as bool;
    if (method == 'clear') generation = 'c' * 32;
    return {
      'enabled': enabled,
      'generation': generation,
      'bytes': 0,
      'event_count': 0,
      'missing': <String>[],
      'limited': false,
    };
  }
}

void main() {
  test('version two fields use per-field closed vocabularies', () {
    expect(
      diagnosticFields({
        DiagnosticField.trigger: DiagnosticValue.alarm,
        DiagnosticField.audio_state: DiagnosticValue.started,
        DiagnosticField.sound_condition: 'content://private',
        DiagnosticField.after_state: DiagnosticValue.blue,
        DiagnosticField.notification_requested: true,
      }),
      {
        'trigger': 'alarm',
        'audio_state': 'started',
        'notification_requested': true,
      },
    );
  });
  test('Dart and Kotlin event/enum vocabularies stay aligned', () {
    final native = File(
      'android/app/src/main/kotlin/com/settrace/settrace/DiagnosticsContract.kt',
    ).readAsStringSync();
    for (final name in DiagnosticName.values) {
      expect(native, contains('"${name.wire}"'));
    }
    for (final name in [
      ...DiagnosticPhase.values.map((v) => v.name),
      ...DiagnosticOutcome.values.map((v) => v.name),
      ...DiagnosticReason.values.map((v) => v.name),
    ]) {
      expect(native, contains('"$name"'));
    }
  });
  test(
    'fields reject user strings, nonfinite values, and negative counters',
    () {
      expect(
        diagnosticFields({
          DiagnosticField.count: 'private plan',
          DiagnosticField.bytes: double.infinity,
          DiagnosticField.revision: -1,
          DiagnosticField.mode: 'private path',
          DiagnosticField.enabled: true,
        }),
        {'enabled': true},
      );
      expect(
        diagnosticFields({
          DiagnosticField.count: 2,
          DiagnosticField.mode: DiagnosticValue.foreground,
        }),
        {'count': 2, 'mode': 'foreground'},
      );
    },
  );
  test('stack contains only approved relative locations', () {
    final result = diagnosticFrames(
      StackTrace.fromString(
        '#0 PrivateName (/storage/emulated/0/private.dart:1:2)\n#1 work (package:settrace/features/workout/workout_repository.dart:3:4)\nprivate-content content://user/file\n#2 next (dart:async/future.dart:20:1)',
      ),
    );
    expect(result, [
      'package:settrace/features/workout/workout_repository.dart:3:4',
      'dart:async/future.dart:20:1',
    ]);
  });
  test(
    'commit and failed followup retain identity and original dataset epoch',
    () async {
      final target = _Transport();
      var epoch = 1;
      final client = DiagnosticsClient(transport: target, epoch: () => epoch);
      await client.overview();
      final operation = client.operation(
        DiagnosticName.workoutComplete,
        objects: {DiagnosticObject.session: 5},
      );
      operation.emit(DiagnosticPhase.committed, DiagnosticOutcome.committed);
      epoch = 2;
      operation.emit(
        DiagnosticPhase.refresh,
        DiagnosticOutcome.partial_success,
        reason: DiagnosticReason.followup_failed,
      );
      await client.flush();
      final records = target.records
          .map((value) => jsonDecode(value) as Map<String, dynamic>)
          .toList();
      expect(records.map((v) => v['operation_id']).toSet(), {operation.id});
      expect(records.map((v) => v['dataset_epoch']).toSet(), {1});
      expect(records[1]['outcome'], 'committed');
      expect(records[2]['outcome'], 'partial_success');
      expect(records[2]['time_utc'], isA<int>());
      client.dispose();
    },
  );
  test('logging remains nonthrowing and bounded when channel fails', () async {
    final target = _Transport();
    final client = DiagnosticsClient(transport: target);
    await client.overview();
    target.fail = true;
    for (var i = 0; i < 1000; i++) {
      client.event(
        DiagnosticName.historyRead,
        phase: DiagnosticPhase.failed,
        level: DiagnosticSeverity.error,
      );
    }
    expect(client.queuedBytes, lessThanOrEqualTo(128 * 1024));
    await client.flush();
    expect(client.dropped, greaterThan(0));
    await expectLater(client.setEnabled(false), throwsStateError);
    client.dispose();
  });
  test(
    'closed logging and clear cannot revive queued old generation',
    () async {
      final target = _Transport();
      final client = DiagnosticsClient(transport: target);
      await client.overview();
      client.event(DiagnosticName.historyRead, phase: DiagnosticPhase.started);
      await client.clear();
      await client.flush();
      expect(target.records, isEmpty);
      await client.setEnabled(false);
      client.event(DiagnosticName.historyRead, phase: DiagnosticPhase.started);
      await client.flush();
      expect(target.records, isEmpty);
      client.dispose();
    },
  );
  test('NoOp supports repository observation without a platform', () async {
    final client = DiagnosticsClient();
    client
        .operation(DiagnosticName.planCreate)
        .emit(DiagnosticPhase.committed, DiagnosticOutcome.committed);
    await client.flush();
    expect(client.queuedBytes, 0);
    client.dispose();
  });
}
