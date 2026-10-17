import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_pages.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_files_platform.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/backup/backup_json.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/plans/plan_repository.dart';

import '../test/support/backup_fakes.dart' show FakeBackupPreferences;

/// Files use the real native bridge. Only picker navigation is substituted:
/// this adapter stages bytes read from the actual public Downloads output.
class StagedDownloads extends BackupFilesPlatform {
  StagedDownloads(this.native);
  final AndroidBackupFilesPlatform native;
  String? inputPath;
  @override
  Future<void> initialize() => native.initialize();
  @override
  Directory get recoveryDirectory => native.recoveryDirectory;
  @override
  String pathFor(String token) => native.pathFor(token);
  @override
  Future<String> allocate() => native.allocate();
  @override
  Future<void> discard(String token) => native.discard(token);
  @override
  Future<BackupMap> reserve(String id, String token) =>
      native.reserve(id, token);
  @override
  Future<BackupMap> publish(String id) => native.publish(id);
  @override
  Future<BackupMap> inspect(String id) => native.inspect(id);
  @override
  Future<void> cleanup(String id) => native.cleanup(id);
  @override
  Future<BackupFileCandidate?> pick() async {
    if (const bool.fromEnvironment('USE_SYSTEM_PICKER')) return native.pick();
    final token = await allocate();
    final input = File(inputPath!);
    final output = File(pathFor(token));
    await input.copy(output.path);
    return BackupFileCandidate(
      token: token,
      fileName: input.uri.pathSegments.last,
      bytes: await output.length(),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Downloads export, existing-data restore, add, undo and recover',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Backup integration QA'))),
      );
      final files = StagedDownloads(AndroidBackupFilesPlatform());
      await files.initialize();
      final db = await AppDatabase.open(
        filePath:
            '${Directory.systemTemp.path}/backup-qa-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final target = BackupCodec().decode(utf8.encode(fixture));
      final writes = DataWriteCoordinator();
      final preferences = FakeBackupPreferences(target.data.settings);
      var service = BackupCoordinator(
        db: db.db,
        writes: writes,
        preferences: preferences,
        files: files,
        appVersion: () => 'android-qa',
      );
      try {
        await service.reconcileStartup();
        final sourceId = 'qa_source_${DateTime.now().microsecondsSinceEpoch}';
        await service.copies.protect(sourceId, target);
        final saved = await service.export(target, currentData: false);
        expect(saved['state'], 'published');
        expect(
          (await files.inspect(saved['operationId'] as String))['state'],
          'published',
        );
        final path = '/storage/emulated/0/Download/${saved['fileName']}';
        final decoded = BackupCodec().decode(await File(path).readAsBytes());
        expect(
          BackupFingerprints(decoded.data).contentDigest,
          BackupFingerprints(target.data).contentDigest,
        );
        final plans = PlanRepository(db.db, coordinator: writes);
        await plans.createPlan('existing before restore');
        files.inputPath =
            const String.fromEnvironment(
                  'EXTERNAL_BACKUP_PATH',
                  defaultValue: '',
                ) ==
                ''
            ? path
            : const String.fromEnvironment('EXTERNAL_BACKUP_PATH');
        final preview = (await service.selectFile())!;
        expect(preview.current.plans.length, 1);
        await service.restore(preview.withSettings(false));
        expect(
          BackupFingerprints(await service.snapshot()).coreDigest,
          BackupFingerprints(target.data).coreDigest,
        );
        await plans.createPlan('added after restore');
        final undo = await service.previewUndo();
        await service.restore(undo);
        expect(
          (await service.snapshot()).plans.single['name'],
          'existing before restore',
        );
        service.dispose();
        service = BackupCoordinator(
          db: db.db,
          writes: DataWriteCoordinator(),
          preferences: preferences,
          files: files,
          appVersion: () => 'android-qa',
        );
        await service.reconcileStartup();
        await service.restore(
          await service.previewCopy(undo.id, restoreSettings: false),
        );
        final restored = await service.snapshot();
        expect(restored.plans.last['name'], 'added after restore');
        expect(restored.workouts.length, target.data.workouts.length);
        final history = restored.workouts.single;
        expect(
          history['startedLocalDate'],
          target.data.workouts.single['startedLocalDate'],
        );
        expect(
          history['durationSeconds'],
          target.data.workouts.single['durationSeconds'],
        );
        if (const bool.fromEnvironment('CAPTURE_BACKUP_UI')) {
          await db.db.update('backup_operations', {'result_seen': 1});
          await t.pumpWidget(
            MaterialApp(
              theme: AppTheme.forPreset(
                Brightness.light,
                ThemeColorPreset.teal,
              ),
              themeAnimationDuration: Duration.zero,
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: BackupPage(
                service: service,
                onWorkout: () async {},
                onHistory: () async {},
                onPlanImport: () async {},
              ),
            ),
          );
          Future<void> ready() async {
            for (var n = 0; n < 100; n++) {
              await Future<void>.delayed(const Duration(milliseconds: 30));
              await t.pump();
              if (!(t.state(find.byType(BackupPage)) as dynamic).busy) break;
            }
            await t.pumpAndSettle();
          }

          Future<void> tap(String label) async {
            final finder = find.text(label);
            if (finder.hitTestable().evaluate().isEmpty) {
              await t.scrollUntilVisible(
                finder,
                120,
                scrollable: find
                    .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await t.pumpAndSettle();
              await Scrollable.ensureVisible(
                t.element(finder.first),
                alignment: 0.5,
              );
              await t.pumpAndSettle();
            }
            await t.tap(finder.hitTestable().last);
            await ready();
          }

          await ready();
          await binding.convertFlutterSurfaceToImage();
          await t.pumpAndSettle();
          Future<void> capture(String name) async {
            final bytes = await binding.takeScreenshot(name);
            await File('/sdcard/Download/SetTrace-qa-ui-$name.png')
                .writeAsBytes(bytes, flush: true);
          }

          final l = lookupAppLocalizations(const Locale('zh'));
          await capture('home');
          await tap(l.backupCopies);
          await tap(l.backupCounts(2, 1));
          await tap(l.backupCopyRestore);
          await capture('preview');
          await tap(l.backupContinue);
          await capture('confirmation');
          await tap(l.cancel);
          debugPrint('BACKUP_UI_CAPTURED home preview confirmation');
          await t.pumpWidget(const SizedBox());
        }
        debugPrint(
          'BACKUP_ANDROID_QA ${jsonEncode({'fileName': saved['fileName'], 'target': saved['target'], 'sourceDigest': BackupFingerprints(target.data).contentDigest, 'finalPlans': restored.plans.length, 'finalWorkouts': restored.workouts.length, 'databaseVersion': await db.db.getVersion(), 'deviceTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes, 'picker': const bool.fromEnvironment('USE_SYSTEM_PICKER') ? 'system-action-open-document' : 'staged-from-real-download-not-OS-navigation'})}',
        );
      } finally {
        service.dispose();
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets('native picker cancellation rejects concurrent requests', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Picker cancellation QA'))),
    );
    final files = AndroidBackupFilesPlatform();
    await files.initialize();
    final result = files.pick();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await expectLater(
      files.allocate(),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.busy,
        ),
      ),
    );
    debugPrint('BACKUP_PICKER_CANCEL_READY');
    expect(await result, isNull);
    final token = await files.allocate();
    await files.discard(token);
    debugPrint('BACKUP_PICKER_CANCEL_PASSED');
  }, timeout: const Timeout(Duration(minutes: 2)));
  testWidgets(
    'native legacy Downloads permission denial never reserves an output',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Permission denial QA'))),
      );
      final files = AndroidBackupFilesPlatform();
      await files.initialize();
      final token = await files.allocate();
      final source = File(files.pathFor(token));
      await source.writeAsString(fixture, flush: true);
      final requestId = 'qa_denied_${DateTime.now().microsecondsSinceEpoch}';
      debugPrint('BACKUP_PERMISSION_DENY_READY');
      final response = await const MethodChannel('settrace/backup_files')
          .invokeMapMethod<String, Object?>('reserve', {
            'requestId': requestId,
            'token': token,
          });
      expect(response, {'status': 'error', 'code': 'permissionDenied'});
      expect(await source.readAsString(), fixture);
      expect((await files.inspect(requestId))['state'], 'cleaned');
      final nextToken = await files.allocate();
      await files.discard(nextToken);
      await files.discard(token);
      debugPrint('BACKUP_PERMISSION_DENY_PASSED');
    },
    skip: !const bool.fromEnvironment('LEGACY_PERMISSION_DENIAL'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

const fixture = r'''{
  "format": "settrace.user-backup",
  "schemaVersion": 1,
  "backupId": "golden-v1-history",
  "snapshotAt": "2026-10-16T00:00:00.000Z",
  "exportedAt": "2026-10-16T00:00:00.000Z",
  "sourceAppVersion": "0.2.4+10",
  "data": {
    "plans": [
      {
        "key": "p1",
        "name": "力量 Strength",
        "createdAt": 1000,
        "updatedAt": 2000,
        "exercises": [
          {
            "key": "e1",
            "name": "深蹲 Squat",
            "targetSets": 3,
            "restBetweenSetsSeconds": 60,
            "restAfterExerciseSeconds": 90,
            "defaultWeightKg": 25.5
          }
        ]
      },
      {
        "key": "p2",
        "name": "力量 Strength",
        "createdAt": 1000,
        "updatedAt": 2000,
        "exercises": []
      }
    ],
    "workouts": [
      {
        "key": "w1",
        "sourcePlanKey": null,
        "planNameSnapshot": "已删除的计划",
        "startedAt": 2000,
        "startedLocalDate": "2026-10-15",
        "endedAt": 1000,
        "durationSeconds": 0,
        "exercises": [
          {
            "key": "we1",
            "sourceExerciseKey": null,
            "nameSnapshot": "深蹲 Squat",
            "targetSets": 3,
            "restBetweenSetsSeconds": 60,
            "restAfterExerciseSeconds": 90,
            "defaultWeightKg": 25.5,
            "skipBatches": [
              {
                "key": "b1",
                "createdAt": 3000,
                "undoneAt": null
              },
              {
                "key": "b2",
                "createdAt": 4000,
                "undoneAt": 5000
              }
            ],
            "sets": [
              {
                "setNumber": 1,
                "completedAt": 3000,
                "completedSequence": 1,
                "skippedAt": null,
                "skipBatchKey": null
              },
              {
                "setNumber": 2,
                "completedAt": null,
                "completedSequence": null,
                "skippedAt": 3000,
                "skipBatchKey": "b1"
              },
              {
                "setNumber": 3,
                "completedAt": null,
                "completedSequence": null,
                "skippedAt": null,
                "skipBatchKey": null
              }
            ]
          }
        ]
      }
    ],
    "settings": {
      "themeMode": "system",
      "themeColor": "teal",
      "languageTag": "zh",
      "reminder": {
        "enabled": true,
        "sound": "three_tone",
        "vibration": true,
        "repeat": true,
        "interval": 10
      }
    }
  },
  "metadata": {
    "extensions": {}
  },
  "integrity": {
    "algorithm": "sha256",
    "digest": "4ce331ba4773700a285fd8983e67333b5991aaed054ec00bf54ab418b6352dd5"
  }
}
''';
