import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/features/backup/backup_files_platform.dart';
import 'package:settrace/features/backup/backup_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('settrace/backup_files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidBackupFilesPlatform files;
  Map<String, Object?> response = {};
  final calls = <MethodCall>[];
  setUp(() async {
    calls.clear();
    files = AndroidBackupFilesPlatform();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') {
        return {
          'status': 'success',
          'stageRoot': 'C:/private/stage',
          'recoveryRoot': 'C:/private/recovery',
        };
      }
      return response;
    });
    await files.initialize();
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('trusted tokens remain under native staging root', () {
    expect(files.pathFor('valid-token_1'), endsWith('valid-token_1.json'));
    for (final token in [
      '../escape',
      'C:/elsewhere',
      'a\\b',
      '',
      '/tmp/escape',
    ]) {
      expect(() => files.pathFor(token), throwsA(isA<BackupException>()));
    }
  });
  test(
    'picker cancellation is distinct from read failure and oversize',
    () async {
      response = {'status': 'cancelled'};
      expect(await files.pick(), isNull);
      for (final code in ['readFailed', 'tooLarge', 'busy']) {
        response = {'status': 'error', 'code': code};
        await expectLater(
          files.pick(),
          throwsA(
            isA<BackupException>().having((e) => e.code, 'code', switch (code) {
              'tooLarge' => BackupFailure.tooLarge,
              'busy' => BackupFailure.busy,
              'readFailed' => BackupFailure.readFailed,
              _ => BackupFailure.storage,
            }),
          ),
        );
      }
    },
  );
  test(
    'picker rejects native path-shaped tokens before constructing candidate',
    () async {
      response = {
        'status': 'success',
        'token': '../bad',
        'fileName': 'backup.json',
        'bytes': 30,
      };
      await expectLater(files.pick(), throwsA(isA<BackupException>()));
    },
  );
  test('reserve publish inspect preserve operation identity without duplicate reserve', () async {
    response = {'status': 'success', 'state': 'reserved'};
    await files.reserve('operation', 'token');
    response = {'status': 'success', 'state': 'published'};
    expect((await files.publish('operation'))['state'], 'published');
    await files.inspect('operation');
    expect(calls.skip(1).map((c) => c.method), [
      'reserve',
      'publish',
      'inspect',
    ]);
    expect(
      calls
          .skip(1)
          .every((c) => (c.arguments as Map)['requestId'] == 'operation'),
      true,
    );
  });
}
