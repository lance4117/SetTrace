import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/diagnostics/diagnostics_controller.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  late FakeDiagnosticsTransport transport;
  late DiagnosticsClient client;
  late DiagnosticsController controller;
  setUp(() {
    transport = FakeDiagnosticsTransport();
    client = DiagnosticsClient(transport: transport);
    controller = DiagnosticsController(client);
  });
  tearDown(() {
    controller.dispose();
    client.dispose();
  });
  test('load failure remains distinct from an actual empty overview', () async {
    transport.failMethods.add('overview');
    await controller.load();
    expect(controller.overviewFailed, isTrue);
    expect(controller.overview, isNull);
    transport.failMethods.clear();
    await controller.load();
    expect(controller.overviewFailed, isFalse);
    expect(controller.overview!.eventCount, 0);
  });
  test('failed policy write retains re-read effective state', () async {
    await controller.load();
    transport.failMethods.add('setEnabled');
    await controller.setEnabled(false);
    expect(controller.overview!.enabled, isTrue);
    expect(controller.controlError, isNotNull);
    transport.failMethods.clear();
    await controller.setEnabled(false);
    expect(controller.overview!.enabled, isFalse);
  });
  test(
    'lost control acknowledgement re-queries a successful native commit',
    () async {
      await controller.load();
      transport.intercept = (method, args) async {
        if (method == 'setEnabled') {
          transport.enabled = false;
          throw const DiagnosticsFailure('timeout');
        }
        return transport.overview();
      };
      await controller.setEnabled(false);
      expect(controller.overview!.enabled, isFalse);
      expect(controller.controlError, 'timeout');
    },
  );
  test(
    'late overview cannot overwrite a confirmed later control change',
    () async {
      final pending = Completer<Map<String, Object?>>();
      final stale = transport.overview();
      transport.intercept = (method, args) async {
        if (method == 'overview') return pending.future;
        transport.enabled = false;
        return transport.overview();
      };
      final loading = controller.load(recoverExport: false);
      await controller.setEnabled(false);
      pending.complete(stale);
      await loading;
      expect(controller.overview!.enabled, isFalse);
    },
  );
  test('permission cancellation never starts a native export', () async {
    final permission = Completer<Map<String, Object?>>();
    transport.intercept = (method, args) async => permission.future;
    final started = controller.startExport();
    await controller.cancel();
    permission.complete({});
    await started;
    expect(transport.calls.where((m) => m == 'startExport'), isEmpty);
    expect(controller.exportError, 'cancelled');
    expect(controller.exporting, isFalse);
  });
  test(
    'start and controls cannot re-enter; final publication is polled',
    () async {
      transport.autoComplete = false;
      await controller.startExport();
      await controller.startExport();
      await controller.clear();
      expect(transport.calls.where((m) => m == 'startExport'), hasLength(1));
      expect(transport.calls, isNot(contains('clear')));
      transport.stage = DiagnosticExportStage.saved;
      await controller.resume();
      expect(controller.export!.saved, isTrue);
    },
  );
  test('unknown publication must inspect existing task before retry', () async {
    transport.hasExport = true;
    transport.stage = DiagnosticExportStage.unknown;
    await controller.load();
    await controller.startExport();
    expect(transport.calls, isNot(contains('startExport')));
    transport.stage = DiagnosticExportStage.saved;
    await controller.inspect();
    expect(controller.export!.saved, isTrue);
  });
  test('publication winning a cancellation race remains saved', () async {
    transport.autoComplete = false;
    await controller.startExport();
    transport.stage = DiagnosticExportStage.saved;
    await controller.cancel();
    expect(controller.export!.saved, isTrue);
    expect(controller.export!.stage, isNot(DiagnosticExportStage.cancelled));
  });
  test(
    'detailed mode cannot revive through total policy off then on',
    () async {
      await controller.load();
      await controller.setDetailed(true);
      expect(controller.overview!.detailedUntil, isNotNull);
      await controller.setEnabled(false);
      await controller.setEnabled(true);
      expect(controller.overview!.detailedUntil, isNull);
    },
  );
}
