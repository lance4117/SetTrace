import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/diagnostics/diagnostic_errors.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostic_observation.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Isolate.run failure reaches its observing operation without raw error text', () async {
    final native = FakeDiagnosticsTransport();
    final client = DiagnosticsClient(transport: native);
    try {
      await expectLater(
        diagnosticObserve(
          client,
          DiagnosticName.backupProtect,
          () => Isolate.run<void>(
            () => throw StateError('PRIVATE_ISOLATE_SQL_URI'),
          ),
          inferCommitOnSuccess: false,
        ),
        throwsStateError,
      );
      await client.flush();
      expect(native.events.last['outcome'], 'unknown');
      expect(native.events.last['phase'], 'failed');
      expect(
        native.events.toString(),
        isNot(contains('PRIVATE_ISOLATE_SQL_URI')),
      );
    } finally {
      client.dispose();
    }
  });
  test(
    'global Flutter and async error hooks preserve prior handlers and sanitize',
    () async {
      final native = FakeDiagnosticsTransport(),
          previousFlutter = FlutterError.onError,
          previousPlatform = PlatformDispatcher.instance.onError;
      final client = DiagnosticsClient(transport: native);
      var flutterCalls = 0, platformCalls = 0;
      FlutterError.onError = (_) {
        flutterCalls++;
      };
      PlatformDispatcher.instance.onError = (_, _) {
        platformCalls++;
        return true;
      };
      final dispose = installDiagnosticErrorHandlers(client);
      try {
        FlutterError.onError!(
          FlutterErrorDetails(
            exception: StateError('PRIVATE_SENTINEL'),
            stack: StackTrace.fromString(
              '#0 method (package:settrace/main.dart:10:2)',
            ),
          ),
        );
        final handled = PlatformDispatcher.instance.onError!(
          StateError('PRIVATE_SENTINEL'),
          StackTrace.fromString('C:/PRIVATE_SENTINEL.dart:99'),
        );
        await client.flush();
        expect(flutterCalls, 1);
        expect(platformCalls, 1);
        expect(handled, isTrue);
        expect(native.events.toString(), isNot(contains('PRIVATE_SENTINEL')));
        expect(native.events.length, 2);
      } finally {
        dispose();
        FlutterError.onError = previousFlutter;
        PlatformDispatcher.instance.onError = previousPlatform;
        client.dispose();
      }
    },
  );
  testWidgets(
    'database failure shell exports and returns without deleting or opening data',
    (tester) async {
      final native = FakeDiagnosticsTransport(),
          client = DiagnosticsClient(transport: FakeDiagnosticsTransport());
      final exportClient = DiagnosticsClient(transport: native);
      var opens = 0;
      await tester.pumpWidget(
        SetTraceBootstrap(
          writes: DataWriteCoordinator(),
          diagnostics: exportClient,
          openDatabase: () async {
            opens++;
            throw StateError('PRIVATE open failure');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to open local data'), findsOneWidget);
      await tester.tap(find.text('Export available diagnostics'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(native.calls, isNot(contains('startExport')));
      await tester.tap(find.text('Save to Downloads'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Diagnostic file saved'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open local data'), findsOneWidget);
      expect(opens, 1);
      await tester.tap(find.text('Try opening again'));
      await tester.pumpAndSettle();
      expect(opens, 2);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
      exportClient.dispose();
    },
  );
  testWidgets(
    'preferences failure closes a successfully opened database before retry',
    (tester) async {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('diagnostic-startup-');
      final client = DiagnosticsClient();
      final opened = <AppDatabase>[];
      await tester.runAsync(() async {
        await tester.pumpWidget(
          SetTraceBootstrap(
            writes: DataWriteCoordinator(),
            diagnostics: client,
            openDatabase: () async {
              final db = await AppDatabase.open(
                filePath: '${dir.path}/business.db',
                factory: databaseFactoryFfiNoIsolate,
              );
              opened.add(db);
              return db;
            },
            readPreferences: () async =>
                throw StateError('PRIVATE preferences failure'),
          ),
        );
        final deadline = Stopwatch()..start();
        while ((opened.isEmpty || opened.last.db.isOpen) &&
            deadline.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(opened.single.db.isOpen, isFalse);
      expect(File('${dir.path}/business.db').existsSync(), isTrue);
      expect(find.text('Unable to open local data'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
      dir.deleteSync(recursive: true);
    },
  );
}
