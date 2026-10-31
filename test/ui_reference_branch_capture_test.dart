// Explicit state fixtures for short-lived or unsafe-to-trigger branches.
// These verify rendering only; no claim about real rollback/storage faults.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_json.dart';
import 'package:settrace/features/backup/backup_pages.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';

import 'support/backup_fakes.dart';
import 'ui_reference_capture_test.dart' as reference;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(reference.loadReferenceFonts);
  for (final language in ['zh', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('controlled branch reference $language $dark', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(360, 800);
        final directory = await t.runAsync(
          () => Directory.systemTemp.createTemp('ui_branch_'),
        );
        final db = await t.runAsync(
          () => AppDatabase.open(
            filePath: '${directory!.path}/db',
            factory: databaseFactoryFfi,
          ),
        );
        final document = BackupCodec().decode(
          File('test/fixtures/backup/v1-history.settrace.json')
              .readAsBytesSync(),
        );
        final writes = DataWriteCoordinator();
        final service = BackupCoordinator(
          db: db!.db,
          writes: writes,
          preferences: FakeBackupPreferences(document.data.settings),
          files: FakeBackupFiles(Directory('${directory!.path}/files')),
          appVersion: () => '0.3.1+12 controlled view fixture',
        );
        dynamic page;
        Future<void> capture(String id) async {
          if (find.byType(BackupPage).evaluate().isNotEmpty) {
            page.setState(() {});
          }
          await t.pump();
          await reference.saveFrame(
            t,
            id,
            language,
            dark,
            state: 'controlled-view-fixture',
            group: 'backup',
            recordFile: 'branch-captures.json',
            fixture: 'Production widget with explicit in-memory view-state injection, isolated SQLite, controlled platform and test font fallback. Rendering only; NOT an executed transaction, interruption or storage failure.',
          );
        }

        try {
          await t.runAsync(service.reconcileStartup);
          await t.pumpWidget(
            reference.wrap(
              BackupPage(
                service: service,
                onWorkout: () async {},
                onHistory: () async {},
                onPlanImport: () async {},
              ),
              language,
              dark,
            ),
          );
          for (var i = 0; i < 12; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 100));
          }
          page = t.state(find.byType(BackupPage));
          page.current = document.data;
          page.currentDigest = 'fixture';
          page.loading = false;
          page.preview = BackupPreview(
            id: 'reference',
            document: document,
            current: document.data,
            epoch: 0,
            restoreSettings: true,
            fileName: 'Long-reference-backup-with-training-history-2026-10-31.settrace.json',
            bytes: 1024,
          );
          page.screen = 'preview';
          page.busy = true;
          service.phase = 'restoring';
          await capture('B08a');
          await capture('B13a');
          page.busy = false;
          service.phase = 'idle';
          page.screen = 'home';
          page.operations = [
            <String, Object?>{
              'id': 'reference',
              'kind': 'restore',
              'restore_settings': 1,
              'phase': 'settings_pending',
            },
          ];
          await capture('B01d');
          page.operations = [
            <String, Object?>{
              'id': 'reference',
              'kind': 'restore',
              'result_seen': 0,
              'phase': 'aborted',
            },
          ];
          await capture('B17');
          page.operations = [
            <String, Object?>{
              'id': 'reference',
              'kind': 'restore',
              'result_seen': 0,
              'phase': 'completed',
            },
          ];
          await capture('B18');
          page.operations = <Map<String, Object?>>[];
          page.screen = 'exportResult';
          page.saved = <String, Object?>{
            'fileName': 'Long-reference-backup-with-training-history-2026-10-31.settrace.json',
            'ledgerPending': true,
            'operationId': 'reference',
          };
          await capture('B04a');
          page.screen = 'result';
          page.result = BackupOperationResult(
            'reference',
            document,
            settingsPending: ['languageTag'],
          );
          await capture('E09');
          page.result = BackupOperationResult(
            'reference',
            document,
            refreshFailed: true,
          );
          await capture('E10');
          for (final state in <String, BackupFailure>{
            'B01c': BackupFailure.readFailed,
            'E01': BackupFailure.unsupportedVersion,
            'E02a': BackupFailure.tooLarge,
            'E03': BackupFailure.planFile,
            'E05': BackupFailure.storage,
            'E06': BackupFailure.protection,
            'E07': BackupFailure.rolledBack,
            'E08': BackupFailure.stalePreview,
            'E11': BackupFailure.missingCopy,
            'E12': BackupFailure.deleteFailed,
            'E13': BackupFailure.rolledBack,
            'E14': BackupFailure.readFailed,
          }.entries) {
            page.screen = state.key == 'B01c' ? 'home' : 'choose';
            page.error = BackupException(state.value);
            await capture(state.key);
          }
          await t.pumpWidget(
            reference.wrap(
              BackupStartupPage(failed: true, onRetry: () {}),
              language,
              dark,
            ),
          );
          await capture('B16a');
        } finally {
          await t.pumpWidget(const SizedBox());
          service.dispose();
          await t.runAsync(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
        }
      }, skip: reference.output.isEmpty);
    }
  }
}
