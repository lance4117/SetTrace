import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostic_observation.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/rest_alerts/rest_alert_platform.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('schedule, delivery and acknowledgement cleanup retain captured epoch and operation', () async {
    const channel = MethodChannel('settrace/rest_alerts');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    final platform = AndroidRestAlertPlatform();
    var epoch = 4;
    final client = DiagnosticsClient(
      transport: FakeDiagnosticsTransport(),
      epoch: () => epoch,
    );
    try {
      await diagnosticObserve(client, DiagnosticName.restAcknowledge, () async {
        final captured = DiagnosticContext.capture(
          DiagnosticValue.acknowledge,
          epoch: epoch,
        );
        epoch = 5;
        await captured.run(() async {
          const event = RestAlertEvent({
            'id': 7,
            'revision': 2,
            'delivery_sequence': 0,
            'due_at': 1000,
          });
          await platform.schedule(event);
          await platform.deliver(event);
          await platform.stopOutput(7);
          await platform.cancelExcept({});
        });
      });
      final contexts = calls
          .map((c) => Map<String, Object?>.from(c.arguments as Map))
          .toList();
      expect(contexts.every((c) => c['diagnostic_epoch'] == 4), isTrue);
      expect(
        contexts.map((c) => c['diagnostic_operation']).toSet(),
        hasLength(1),
      );
      expect(
        contexts.every((c) => c['diagnostic_trigger'] == 'acknowledge'),
        isTrue,
      );
    } finally {
      platform.dispose();
      client.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
