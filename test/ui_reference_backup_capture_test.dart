// Opt-in backup reference, using production pages and isolated test storage.
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/widgets/app_card.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_files_platform.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/backup/backup_pages.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';

import 'support/backup_fakes.dart';
import 'ui_reference_capture_test.dart' as reference;

class ReferenceBackupFiles extends FakeBackupFiles {
  ReferenceBackupFiles(super.root);
  Completer<void>? publishGate;
  bool publishReached = false;
  @override
  Future<BackupMap> publish(String id) async {
    publishReached = true;
    await publishGate?.future;
    return super.publish(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  // Load the same actual fonts as the core reference test without running it.
  // Font loading is performed by this test's explicit setUpAll below.
  setUpAll(reference.loadReferenceFonts);
  for (final language in ['zh', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('backup reference $language dark=$dark', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(360, 800);
        final dir = await t.runAsync(
          () => Directory.systemTemp.createTemp('ui_reference_backup_'),
        );
        final db = await t.runAsync(
          () => AppDatabase.open(
            filePath: '${dir!.path}/db',
            factory: databaseFactoryFfi,
          ),
        );
        final document = BackupCodec().decode(
          File('test/fixtures/backup/v1-history.settrace.json')
              .readAsBytesSync(),
        );
        final files = ReferenceBackupFiles(Directory('${dir!.path}/files'));
        Completer<void>? protectionGate;
        var protectionReached = false;
        final service = BackupCoordinator(
          db: db!.db,
          writes: DataWriteCoordinator(),
          preferences: FakeBackupPreferences(document.data.settings),
          files: files,
          appVersion: () => '0.3.1+12 widget fixture',
          protectionCheckpoint: (_) async {
            if (protectionGate != null) {
              protectionReached = true;
              await protectionGate.future;
            }
          },
        );
        final l = lookupAppLocalizations(Locale(language));
        Future<void> settle() async {
          for (var i = 0; i < 200; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 100));
            final page = find.byType(BackupPage);
            if (i > 2 &&
                (page.evaluate().isEmpty || !(t.state(page) as dynamic).busy)) {
              break;
            }
          }
          await t.pumpAndSettle();
        }

        Future<void> click(String text) async {
          final finder = find.text(text).last;
          if (finder.hitTestable().evaluate().isEmpty) {
            await t.scrollUntilVisible(
              finder,
              150,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 40,
            );
          }
          await t.ensureVisible(finder);
          await t.pumpAndSettle();
          await t.tap(finder);
          await settle();
        }

        Future<void> capture(String id, {String state = 'normal'}) =>
            reference.saveFrame(
              t,
              id,
              language,
              dark,
              state: state,
              group: 'backup',
              recordFile: 'backup-captures.json',
            );
        Future<void> bottom(String id) async {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -1600));
          await t.pumpAndSettle();
          await capture(id, state: 'scroll-bottom');
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
          await settle();
          await capture('B01b');
          await click(l.backupCreate);
          await capture('B02');
          files.publishGate = Completer<void>();
          await t.tap(find.text(l.backupSaveFile));
          for (var i = 0; i < 150 && !files.publishReached; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          expect(files.publishReached, isTrue);
          await capture('B03');
          files.publishGate!.complete();
          files.publishGate = null;
          await settle();
          await capture('B04');
          await click(l.backupDone);
          await capture('B01');
          await click(l.backupRestore);
          await capture('B05');
          final badToken = await files.allocate();
          await t.runAsync(
            () =>
                File(files.pathFor(badToken))
                    .writeAsString('{broken reference fixture'),
          );
          files.selected = BackupFileCandidate(
            token: badToken,
            fileName: 'invalid-reference.json',
            bytes: 25,
          );
          await click(l.backupChooseFile);
          await capture('E02');
          final token = await files.allocate();
          await t.runAsync(
            () =>
                File(files.pathFor(token))
                    .writeAsBytes(BackupCodec().encode(document)),
          );
          files.selected = BackupFileCandidate(
            token: token,
            fileName: 'UIReference-backup.settrace.json',
            bytes: File(files.pathFor(token)).lengthSync(),
          );
          await click(l.backupChooseFile);
          await capture('B06');
          await bottom('B06');
          final continueFinder = find.text(l.backupContinue);
          await t.ensureVisible(continueFinder);
          await t.pumpAndSettle();
          await t.tap(continueFinder);
          await t.pumpAndSettle();
          await capture('B07');
          await t.tap(find.text(l.cancel).last);
          await settle();
          expect(find.text(l.backupContinue), findsOneWidget);
          await click(l.backupContinue);
          protectionGate = Completer<void>();
          protectionReached = false;
          await t.tap(find.text(l.backupReplace));
          for (var i = 0; i < 150 && !protectionReached; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          expect(protectionReached, isTrue);
          await capture('B08');
          protectionGate.complete();
          protectionGate = null;
          await settle();
          await capture('B09');
          await click(l.backupCopies);
          await capture('B10');
          await t.tap(find.byType(AppCard).last);
          await settle();
          await capture('B19');
          await bottom('B19');
          final deleteFinder = find.text(l.backupCopyDelete).last;
          await t.ensureVisible(deleteFinder);
          await t.pumpAndSettle();
          await t.tap(deleteFinder);
          await t.pumpAndSettle();
          await capture('B20');
          await t.tap(find.text(l.cancel).last);
          await settle();
          final dynamic pageState = t.state(find.byType(BackupPage));
          await t.runAsync(() async {
            await pageState.back();
          });
          await settle();
          await t.runAsync(() async {
            await pageState.back();
          });
          await settle();
          await capture('B01', state: 'restored');
          await click(l.backupUndo);
          await capture('B11');
          await t.tap(find.text(l.backupContinue));
          await t.pumpAndSettle();
          await capture('B12');
          protectionGate = Completer<void>();
          protectionReached = false;
          await t.tap(find.text(l.backupUndoConfirm));
          for (var i = 0; i < 150 && !protectionReached; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          expect(protectionReached, isTrue);
          await capture('B13');
          protectionGate.complete();
          protectionGate = null;
          await settle();
          await capture('B14');
          await click(l.backupDone);
          await t.runAsync(() async {
            final plans = PlanRepository(db.db, coordinator: service.writes);
            final plan = await plans.createPlan('Active UIReference');
            await plans.addExercise(
              planId: plan,
              name: 'ReferenceRow',
              targetSets: 4,
              restBetweenSetsSeconds: 60,
              restAfterExerciseSeconds: 60,
            );
            await WorkoutRepository(
              db.db,
              coordinator: service.writes,
            ).start(plan);
          });
          await click(l.backupCreate);
          await capture('B15');
          expect(find.text(l.backupActiveHelp), findsWidgets);
        } finally {
          await t.pumpWidget(const SizedBox());
          service.dispose();
          await t.runAsync(() async {
            await db.close();
            await dir.delete(recursive: true);
          });
        }
      }, skip: reference.output.isEmpty);
    }
  }
}
