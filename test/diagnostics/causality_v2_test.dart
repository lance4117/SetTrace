import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostic_observation.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  test(
    'silent scopes are skipped and queued contexts keep their own ancestors',
    () async {
      final transport = FakeDiagnosticsTransport();
      final client = DiagnosticsClient(transport: transport, epoch: () => 7);
      await client.overview();
      final queued = <DiagnosticContext>[];
      final parents = <String>[];
      for (final trigger in [
        DiagnosticValue.training_change,
        DiagnosticValue.settings_change,
      ]) {
        await diagnosticObserve(
          client,
          DiagnosticName.workoutComplete,
          () async {
            parents.add(DiagnosticScope.current!.operation.id);
            await diagnosticObserve(
              client,
              DiagnosticName.restSynchronize,
              () async {
                queued.add(DiagnosticContext.capture(trigger));
              },
              readOnly: true,
              recordSuccess: false,
              nestReadScope: true,
            );
          },
        );
      }
      for (final context in queued.reversed) {
        await context.run(
          () => diagnosticObserve(
            client,
            DiagnosticName.restSchedule,
            () async {},
            readOnly: true,
            nestReadScope: true,
            fields: {DiagnosticField.trigger: diagnosticTrigger},
          ),
        );
      }
      await client.flush();
      final schedules = transport.events
          .where(
            (e) =>
                e['event_name'] == 'rest.schedule' && e['phase'] == 'started',
          )
          .toList();
      expect(
        schedules.map((e) => e['parent_operation_id']).toList(),
        parents.reversed.toList(),
      );
      final ids = transport.events.map((e) => e['operation_id']).toSet();
      expect(
        transport.events
            .where((e) => e['parent_operation_id'] != null)
            .every((e) => ids.contains(e['parent_operation_id'])),
        isTrue,
      );
      expect(schedules.first['attributes']['trigger'], 'settings_change');
      client.dispose();
    },
  );
}
