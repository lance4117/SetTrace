import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/backup/backup_json.dart';

void main() {
  test(
    'stop admission, drain admitted nested writes, then acquire exclusive',
    () async {
      final c = DataWriteCoordinator();
      final release = Completer<void>();
      final order = <String>[];
      final write = c.write(() async {
        await release.future;
        await c.write(() async => order.add('nested'));
        order.add('write');
      });
      final exclusive = c.exclusive(() async => order.add('exclusive'));
      await expectLater(
        c.write(() async => order.add('unexpected')),
        throwsA(isA<BackupException>()),
      );
      expect(order, isEmpty);
      release.complete();
      await Future.wait([write, exclusive]);
      expect(order, ['nested', 'write', 'exclusive']);
    },
  );
  test(
    'old epoch rejected, failed exclusive releases admission, unknown blocks',
    () async {
      final c = DataWriteCoordinator();
      await c.exclusive(() async => c.committed(1));
      await expectLater(
        c.write(() async {}, expectedEpoch: 0),
        throwsException,
      );
      await expectLater(
        c.exclusive(() async => throw StateError('injected')),
        throwsStateError,
      );
      await c.write(() async {});
      c.restrict();
      await expectLater(c.write(() async {}), throwsException);
      await c.exclusive(() async => c.reconcile(1), reconciliation: true);
      await c.write(() async {});
    },
  );
  test(
    'settled coalesced work completes without holding its write lock',
    () async {
      final c = DataWriteCoordinator();
      final release = Completer<void>();
      final saving = c.write(() async {
        await release.future;
      });
      c.settlers.add(() => saving);
      final snapshot = c.exclusive(() async => 'confirmed');
      release.complete();
      expect(await snapshot.timeout(const Duration(seconds: 1)), 'confirmed');
    },
  );
}
