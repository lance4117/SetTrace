import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_json.dart';
import 'package:settrace/features/backup/backup_models.dart';

BackupMap fixture([String name = 'v1-history']) => jsonDecode(
  File('test/fixtures/backup/$name.settrace.json').readAsStringSync(),
) as BackupMap;
List<int> signed(BackupMap value) {
  value.remove('integrity');
  final digest = backupDigest(value);
  return utf8.encode(
    jsonEncode({
      ...value,
      'integrity': {'algorithm': 'sha256', 'digest': digest},
    }),
  );
}

BackupMap firstExercise(BackupMap doc) =>
    (((doc['data'] as BackupMap)['workouts'] as List).first['exercises']
                as List)
            .first
        as BackupMap;

void main() {
  final codec = BackupCodec();
  final invalid = throwsA(isA<BackupException>());
  test('independently signed v1 golden files and exact round trip', () {
    for (final name in ['v1-empty', 'v1-history']) {
      final doc = codec.decode(
        File('test/fixtures/backup/$name.settrace.json').readAsBytesSync(),
      );
      final result = codec.decode(codec.encode(doc));
      expect(result.data.toJson(), doc.data.toJson());
      expect(result.digest, doc.digest);
    }
    final doc = codec.decode(signed(fixture()));
    expect(doc.data.plans[0]['name'], doc.data.plans[1]['name']);
    expect(doc.data.workouts.first['durationSeconds'], 0);
    expect(doc.data.workouts.first['sourcePlanKey'], null);
    expect(
      () => doc.data.plans.first['name'] = 'mutated',
      throwsUnsupportedError,
    );
  });
  test('RFC 8785 published canonical example and numeric boundaries', () {
    expect(
      canonicalJson({
        'numbers': [333333333.33333329, 1e30, 4.50, 2e-3, 1e-27],
        'string': '\u20ac\$\u000f\nA\'B"\\"/',
        'literals': [null, true, false],
      }),
      r'''{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27],"string":"€$\u000f\nA'B\"\\\"/"}''',
    );
    expect(
      canonicalJson([-0.0, 1e-6, 1e-7, 1e20, 1e21]),
      '[0,0.000001,1e-7,100000000000000000000,1e+21]',
    );
    expect(
      backupDigest({'b': 2, 'a': 1}),
      '43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777',
    );
    expect(
      canonicalJson({'\uE000': 1, '😀': 2, '\r': 3}),
      '{"\\r":3,"😀":2,"\uE000":1}',
    );
  });
  test(
    'reject malformed UTF8, duplicate escaped keys, Unicode and unsafe numbers',
    () {
      expect(() => codec.decode([0xc3, 0x28]), invalid);
      for (final source in [
        r'{"a":1,"\u0061":2}',
        r'"\ud800"',
        r'"\udfff"',
        '9007199254740992',
        '1e999',
        '{"a":1,}',
        '[1,]',
        '01',
        'true false',
        '"a\nb"',
      ]) {
        expect(() => BackupJsonReader(source).read(), invalid, reason: source);
      }
    },
  );
  test('integrity covers metadata and source version', () {
    final doc = fixture();
    doc['sourceAppVersion'] = '99.0.0+200';
    expect(() => codec.decode(utf8.encode(jsonEncode(doc))), invalid);
    expect(codec.decode(signed(doc)).sourceAppVersion, '99.0.0+200');
  });
  test(
    'unknown fields, invalid references, ordering and state reject whole file',
    () {
      final mutations = <void Function(BackupMap)>[
        (d) => (d['data'] as BackupMap)['statistics'] = {},
        (d) => d['requiredCapabilities'] = [],
        (d) => ((d['data'] as BackupMap)['plans'] as List)[1]['key'] = 'p1',
        (d) => firstExercise(d)['sourceExerciseKey'] = 'e1',
        (d) => firstExercise(d)['defaultWeightKg'] = -1,
        (d) => firstExercise(d)['targetSets'] = 2,
        (d) => (firstExercise(d)['sets'] as List)[0]['skippedAt'] = 42,
        (d) =>
            (firstExercise(d)['sets'] as List)[1]['skipBatchKey'] = 'missing',
        (d) => (firstExercise(d)['sets'] as List)[1]['skipBatchKey'] = 'b2',
        (d) =>
            (firstExercise(d)['sets'] as List)[0]['completedSequence'] = null,
        (d) => (firstExercise(d)['sets'] as List)[1]['setNumber'] = 1,
        (d) =>
            ((d['data'] as BackupMap)['workouts']
                    as List)[0]['startedLocalDate'] =
                '2026-02-30',
        (d) => d['snapshotAt'] = '2026-02-30T00:00:00Z',
        (d) =>
            ((d['data'] as BackupMap)['settings'] as BackupMap)['themeColor'] =
                'red',
      ];
      for (final mutation in mutations) {
        final doc = fixture();
        mutation(doc);
        expect(() => codec.decode(signed(doc)), invalid);
      }
    },
  );
  test(
    'extensions only; unsupported future and plan files have distinct failures',
    () {
      final doc = fixture();
      (doc['metadata'] as BackupMap)['extensions'] = {
        'futureInfo': {
          'a': [1, '保留'],
        },
      };
      expect(
        codec.decode(signed(doc)).extensions.containsKey('futureInfo'),
        true,
      );
      expect(
        () => codec.decode(
          File('test/fixtures/backup/synthetic-v2.settrace.json')
              .readAsBytesSync(),
        ),
        throwsA(
          isA<BackupException>().having(
            (e) => e.code,
            'code',
            BackupFailure.unsupportedVersion,
          ),
        ),
      );
      expect(
        () => codec.decode(utf8.encode('{"format":"settrace.training-plans"}')),
        throwsA(
          isA<BackupException>().having(
            (e) => e.code,
            'code',
            BackupFailure.planFile,
          ),
        ),
      );
    },
  );
  test(
    'synthetic migration validates both versions and never mutates input',
    () {
      final original = fixture()..remove('integrity');
      final before = jsonEncode(original);
      final registry = BackupVersionRegistry(
        currentVersion: 2,
        validators: {
          1: validateBackupV1,
          2: (d) {
            expect(d['schemaVersion'], 2);
            BackupData.fromJson(d['data']);
          },
        },
        migrations: {1: (d) => d..['schemaVersion'] = 2},
      );
      expect(registry.upgrade(original)['schemaVersion'], 2);
      expect(jsonEncode(original), before);
      final failing = BackupVersionRegistry(
        currentVersion: 2,
        validators: {1: validateBackupV1},
        migrations: {
          1: (d) {
            (d['data'] as BackupMap)['plans'] = [];
            throw StateError('injected');
          },
        },
      );
      expect(() => failing.upgrade(original), throwsStateError);
      expect(jsonEncode(original), before);
    },
  );
  test('semantic digests ignore local keys but detect same-count edits and settings', () {
    final original = codec.decode(signed(fixture())).data;
    final changed = fixture();
    ((changed['data'] as BackupMap)['plans'] as List)[0]['key'] =
        'new-local-id';
    final renumbered = codec.decode(signed(changed)).data;
    expect(
      BackupFingerprints(renumbered).coreDigest,
      BackupFingerprints(original).coreDigest,
    );
    ((changed['data'] as BackupMap)['plans'] as List)[0]['name'] = 'Changed';
    final renamed = codec.decode(signed(changed)).data;
    expect(
      BackupFingerprints(renamed).coreDigest,
      isNot(BackupFingerprints(original).coreDigest),
    );
    final settings = fixture();
    ((settings['data'] as BackupMap)['settings'] as BackupMap)['languageTag'] =
        'en';
    final updated = BackupFingerprints(codec.decode(signed(settings)).data);
    expect(updated.coreDigest, BackupFingerprints(original).coreDigest);
    expect(
      updated.contentDigest,
      isNot(BackupFingerprints(original).contentDigest),
    );
  });
  test('depth limit checked before descending', () {
    expect(BackupJsonReader('${'[' * 32}0${']' * 32}').read(), isA<List>());
    expect(() => BackupJsonReader('${'[' * 33}0${']' * 33}').read(), invalid);
  });
  test('bounded file worker round trip; >2 MiB accepted', () async {
    final dir = await Directory.systemTemp.createTemp('backup_codec_');
    addTearDown(() => dir.delete(recursive: true));
    final raw = fixture();
    (raw['metadata'] as BackupMap)['extensions'] = {
      'padding': 'x' * (2 * 1024 * 1024),
    };
    final doc = codec.decode(signed(raw));
    final path = '${dir.path}/large.json';
    await BackupCodec.writeFile(path, doc);
    expect((await BackupCodec.readFile(path)).data.toJson(), doc.data.toJson());
    final handle = await File('${dir.path}/oversize')
        .open(mode: FileMode.write);
    await handle.truncate(backupMaxBytes + 1);
    await handle.close();
    expect(
      BackupCodec.readFile('${dir.path}/oversize'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.tooLarge,
        ),
      ),
    );
  });
}
