import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/theme_color_controller.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/live_backup_preferences.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'theme_color_controller_test.dart' show ControlledColors, tick;
import 'support/backup_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase app;
  late ControlledColors store;
  late ThemeColorController colors;
  late LiveBackupPreferences prefs;
  late BackupCoordinator service;
  late DataWriteCoordinator writes;
  String mode = 'system', language = 'en';
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_live_');
    app = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    writes = DataWriteCoordinator();
    store = ControlledColors();
    colors = ThemeColorController(store, coordinator: writes);
    mode = 'system';
    language = 'en';
    prefs = LiveBackupPreferences(
      db: app.db,
      colors: colors,
      mode: () => mode,
      language: () => language,
      saveMode: (value) async {
        mode = value;
      },
      saveLanguage: (value) async {
        language = value;
      },
    );
    service = BackupCoordinator(
      db: app.db,
      writes: writes,
      preferences: prefs,
      files: FakeBackupFiles(Directory('${dir.path}/files')),
      appVersion: () => 'test',
    );
    await service.reconcileStartup();
  });
  tearDown(() async {
    service.dispose();
    colors.dispose();
    await app.close();
    await dir.delete(recursive: true);
  });
  test('snapshot drains coalesced confirmed saves while rejecting late preview selections', () async {
    colors.select(ThemeColorPreset.blue);
    colors.select(ThemeColorPreset.violet);
    final snapshot = service.snapshot();
    await tick();
    colors.select(ThemeColorPreset.graphite);
    store.pending[0].complete(true);
    await tick();
    expect(store.writes, [ThemeColorPreset.blue, ThemeColorPreset.violet]);
    store.pending[1].complete(true);
    final data = await snapshot.timeout(const Duration(seconds: 3));
    expect(data.settings.themeColor, 'violet');
    expect(colors.committed, ThemeColorPreset.violet);
    expect(store.writes, hasLength(2));
  });
  test(
    'failed save and failed cache reload never enter a backup snapshot',
    () async {
      store.reloadFails = true;
      colors.select(ThemeColorPreset.blue);
      final snapshot = service.snapshot();
      store.pending.single.complete(false);
      expect((await snapshot).settings.themeColor, 'teal');
      expect(colors.selected, ThemeColorPreset.teal);
      expect(colors.failedTarget, ThemeColorPreset.blue);
    },
  );
  test('restoring confirmed color updates preview and failure caches; language/mode apply to live readers', () async {
    colors.select(ThemeColorPreset.blue);
    store.pending.single.complete(false);
    await colors.settled;
    final restore = prefs.apply('themeColor', 'violet');
    await tick();
    store.pending.last.complete(true);
    await restore;
    await prefs.apply('themeMode', 'dark');
    await prefs.apply('languageTag', 'zh');
    final saved = await prefs.readConfirmed();
    expect(saved.themeColor, 'violet');
    expect(saved.themeMode, 'dark');
    expect(saved.languageTag, 'zh');
    expect(colors.selected, ThemeColorPreset.violet);
    expect(colors.failedTarget, isNull);
    expect(store.read(), 'violet');
  });
  test(
    'reminder group commits atomically and preserves permission_requested',
    () async {
      await app.db.update('rest_alert_preferences', {
        'permission_requested': 1,
      });
      final before = (await prefs.readConfirmed()).reminder;
      await expectLater(
        prefs.apply('reminder', {
          ...before,
          'enabled': false,
          'sound': 'invalid',
          'interval': 60,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect((await prefs.readConfirmed()).reminder, before);
      await prefs.apply('reminder', {
        ...before,
        'enabled': false,
        'sound': 'voice',
        'interval': 60,
      });
      final row = (await app.db.query('rest_alert_preferences')).single;
      expect(row['permission_requested'], 1);
      expect(row['enabled'], 0);
      expect(row['sound_id'], 'voice');
      expect(row['interval_seconds'], 60);
    },
  );
}
