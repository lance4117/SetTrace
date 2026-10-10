import 'package:settrace/l10n/generated/app_localizations_zh.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:characters/characters.dart';
import 'package:settrace/features/plans/plan_transfer.dart';

void main() {
  const codec = PlanTransferCodec();
  Map<String, dynamic> sample() => jsonDecode(
    jsonEncode({
      'format': PlanTransferCodec.format,
      'schemaVersion': 1,
      'plans': [
        {
          'name': '练背 🏋️‍♂️',
          'exercises': [
            {
              'name': '高位下拉',
              'targetSets': 4,
              'restBetweenSetsSeconds': 120,
              'restAfterExerciseSeconds': 150,
              'defaultWeightKg': 45.5,
            },
            {
              'name': '坐姿划船',
              'targetSets': 1,
              'restBetweenSetsSeconds': 0,
              'restAfterExerciseSeconds': 3600,
            },
          ],
        },
        {'name': '空计划', 'exercises': []},
      ],
    }),
  ) as Map<String, dynamic>;
  test(
    'round trip preserves all fields, order and null weight without IDs',
    () {
      final parsed = codec.decode(jsonEncode(sample()));
      final text = codec.encode(parsed);
      final restored = codec.decode(text);
      expect(restored.plans.map((p) => p.name), ['练背 🏋️‍♂️', '空计划']);
      expect(restored.plans.first.exercises.map((e) => e.name), [
        '高位下拉',
        '坐姿划船',
      ]);
      final first = restored.plans.first.exercises.first;
      expect(
        [
          first.targetSets,
          first.restBetweenSetsSeconds,
          first.restAfterExerciseSeconds,
          first.defaultWeightKg,
        ],
        [4, 120, 150, 45.5],
      );
      expect(restored.plans.first.exercises.last.defaultWeightKg, isNull);
      expect(restored.plans.last.exercises, isEmpty);
      expect(text, isNot(contains('planId')));
      expect(text, isNot(contains('session')));
      expect(
        restored.plans.map((p) => p.toJson()).toList(),
        parsed.plans.map((p) => p.toJson()).toList(),
      );
    },
  );
  test('accepts BOM, whitespace, null weight and unknown additive fields', () {
    final data = sample()..['extra'] = 'ignored';
    (data['plans'][0]['exercises'][1] as Map)['defaultWeightKg'] = null;
    final parsed = codec.decode(' \n\uFEFF${jsonEncode(data)} \n');
    expect(parsed.plans.first.exercises.last.defaultWeightKg, isNull);
  });
  test(
    'rejects damaged input, wrong marker, future version and empty plans',
    () {
      for (final text in [
        '',
        '{',
        '[]',
        jsonEncode(sample()..['format'] = 'other'),
        jsonEncode(sample()..['schemaVersion'] = 2),
        jsonEncode(sample()..['schemaVersion'] = 1.0),
        jsonEncode(sample()..['plans'] = []),
      ]) {
        expect(() => codec.decode(text), throwsA(isA<PlanTransferException>()));
      }
    },
  );
  test('one invalid field rejects the entire document with location', () {
    final invalid = <String, List<Object?>>{
      'targetSets': [0, 101, 1.5, '4', null],
      'restBetweenSetsSeconds': [-30, 15, 3630, 30.0, null],
      'restAfterExerciseSeconds': [-1, 10, 3630, null],
      'defaultWeightKg': [0, -2, '45'],
      'name': ['', 'x' * 61],
    };
    for (final entry in invalid.entries) {
      for (final value in entry.value) {
        final data = sample();
        data['plans'][0]['exercises'][0][entry.key] = value;
        expect(
          () => codec.decode(jsonEncode(data)),
          throwsA(
            isA<PlanTransferException>().having(
              (e) => e.location.exercise,
              'exercise index',
              1,
            ),
          ),
        );
      }
    }
    final missing = sample();
    (missing['plans'][0]['exercises'][0] as Map).remove('targetSets');
    expect(
      () => codec.decode(jsonEncode(missing)),
      throwsA(isA<PlanTransferException>()),
    );
    for (final name in ['', 'x' * 41]) {
      final data = sample();
      data['plans'][0]['name'] = name;
      expect(
        () => codec.decode(jsonEncode(data)),
        throwsA(isA<PlanTransferException>()),
      );
    }
  });
  test('export refuses invalid stored configuration and non-finite weight', () {
    for (final weight in [double.nan, double.infinity, -1.0]) {
      final plan = TransferPlan(
        name: '练背',
        exercises: [
          TransferExercise(
            name: '下拉',
            targetSets: 4,
            restBetweenSetsSeconds: 120,
            restAfterExerciseSeconds: 150,
            defaultWeightKg: weight,
          ),
        ],
      );
      expect(
        () => codec.encode(PlanTransferDocument([plan])),
        throwsA(isA<PlanTransferException>()),
      );
    }
    expect(
      () => codec.encode(
        PlanTransferDocument([TransferPlan(name: 'x' * 41, exercises: [])]),
      ),
      throwsA(isA<PlanTransferException>()),
    );
  });
  test('size uses UTF-8 bytes and permits the exact boundary', () {
    expect(
      () => PlanTransferCodec.checkSize('a' * PlanTransferCodec.maxBytes),
      returnsNormally,
    );
    expect(
      () => codec.decode('中' * (PlanTransferCodec.maxBytes ~/ 3 + 1)),
      throwsA(
        isA<PlanTransferException>().having(
          (e) => e.code,
          'size',
          PlanTransferFailure.fileTooLarge,
        ),
      ),
    );
    final plans = List.generate(
      10000,
      (_) => codec.decode(jsonEncode(sample())).plans.first,
    );
    expect(
      () => codec.encode(PlanTransferDocument(plans)),
      throwsA(isA<PlanTransferException>()),
    );
  });
  test(
    'names use visible characters and resolve existing plus batch collisions',
    () {
      final long = '🏋️‍♂️' * 40;
      final plans = [
        TransferPlan(name: long, exercises: []),
        TransferPlan(name: long, exercises: []),
      ];
      final resolved = resolveImportNames(plans, [
        long,
      ], suffixFor: AppLocalizationsZh().importSuffix);
      expect(resolved[0].name.endsWith('（导入）'), isTrue);
      expect(resolved[1].name.endsWith('（导入2）'), isTrue);
      expect(resolved.map((p) => p.name.characters.length), [40, 40]);
      expect(
        resolveImportNames(
          [
            TransferPlan(name: '练背', exercises: []),
            TransferPlan(name: '练背', exercises: []),
          ],
          ['练背', '练背（导入）'],
          suffixFor: AppLocalizationsZh().importSuffix,
        ).map((p) => p.name),
        ['练背（导入2）', '练背（导入3）'],
      );
    },
  );
  test('published documentation example is importable', () {
    final doc = File('docs/plan-transfer-format.md').readAsStringSync();
    final example = RegExp(r'```json\s*([\s\S]*?)```')
        .firstMatch(doc)!
        .group(1)!;
    final parsed = codec.decode(example);
    expect(parsed.plans.single.name, '练背');
    expect(parsed.plans.single.exercises.single.defaultWeightKg, 45);
  });
}
