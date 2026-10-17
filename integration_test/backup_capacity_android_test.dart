import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_models.dart';

import '../tool/benchmark_backup.dart' show buildBenchmarkDocument;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android synthetic backup capacity in background isolates', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Backup capacity QA'))),
    );
    for (final mode in ['decade', 'limit']) {
      final path = '${Directory.systemTemp.path}/backup-capacity-$mode.json';
      final result = await Isolate.run(() async {
        final document = buildBenchmarkDocument(
          mode,
          jsonDecode(empty) as BackupMap,
        );
        final timer = Stopwatch()..start();
        await BackupCodec.writeFile(path, document);
        final writeMs = timer.elapsedMilliseconds;
        timer.reset();
        final decoded = await BackupCodec.readFile(path);
        final readMs = timer.elapsedMilliseconds;
        if (decoded.data.workouts.length != document.data.workouts.length) {
          throw StateError('data loss');
        }
        final bytes = await File(path).length();
        await File(path).delete();
        return {
          'case': mode,
          'bytes': bytes,
          'writeMs': writeMs,
          'readMs': readMs,
          'maxRss': ProcessInfo.maxRss,
          'workouts': decoded.data.workouts.length,
        };
      });
      debugPrint('BACKUP_ANDROID_CAPACITY ${jsonEncode(result)}');
      expect(result['workouts'], mode == 'decade' ? 3653 : 0);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

const empty = r'''{
  "format": "settrace.user-backup",
  "schemaVersion": 1,
  "backupId": "golden-v1-empty",
  "snapshotAt": "2026-10-16T00:00:00.000Z",
  "exportedAt": "2026-10-16T00:00:00.000Z",
  "sourceAppVersion": "0.2.4+10",
  "data": {
    "plans": [],
    "workouts": [],
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
    "digest": "954e9089b74f53e300df407c4d65f0e8f0c3a07c9dc70f2f9ce6ab917162805c"
  }
}
''';
