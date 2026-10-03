import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('settrace/plan_transfer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test('save receives the exact snapshot and reports actual filename only on success', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {
        'status': 'success',
        'fileName': 'backup-2.settrace.json',
        'location': '下载',
      };
    });
    final result = await AndroidPlanTransferPlatform().saveFile('snapshot');
    expect(calls.single.method, 'saveFile');
    expect(calls.single.arguments, {'text': 'snapshot'});
    expect(result.fileName, 'backup-2.settrace.json');
    expect(result.location, '下载');
  });
  test(
    'cancelled picker returns null and errors never return old text',
    () async {
      var result = <String, Object?>{'status': 'cancelled', 'text': 'stale'};
      messenger.setMockMethodCallHandler(channel, (_) async => result);
      final platform = AndroidPlanTransferPlatform();
      expect(await platform.pickFile(), isNull);
      result = {'status': 'error', 'message': '文件已删除'};
      await expectLater(
        platform.pickFile(),
        throwsA(
          isA<PlanTransferException>().having(
            (e) => e.message,
            'message',
            '文件已删除',
          ),
        ),
      );
      result = {'status': 'success', 'text': ''};
      await expectLater(
        platform.pickFile(),
        throwsA(isA<PlanTransferException>()),
      );
      result = {
        'status': 'success',
        'text': 'a' * (PlanTransferCodec.maxBytes + 1),
      };
      await expectLater(
        platform.pickFile(),
        throwsA(isA<PlanTransferException>()),
      );
    },
  );
  test(
    'in-flight file request rejects duplicates and completes exactly once',
    () async {
      final reply = Completer<Map<String, String>>();
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) {
        calls++;
        return reply.future;
      });
      final platform = AndroidPlanTransferPlatform();
      final first = platform.pickFile();
      await expectLater(
        platform.pickFile(),
        throwsA(isA<PlanTransferException>()),
      );
      reply.complete({'status': 'success', 'text': 'valid snapshot'});
      expect(await first, 'valid snapshot');
      expect(calls, 1);
      expect(await platform.pickFile(), 'valid snapshot');
      expect(calls, 2);
    },
  );
  test('oversized save is rejected before channel and failed results cannot claim private storage success', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return {
        'status': 'success',
        'fileName': 'private.json',
        'location': 'private',
      };
    });
    final platform = AndroidPlanTransferPlatform();
    await expectLater(
      platform.saveFile('a' * (PlanTransferCodec.maxBytes + 1)),
      throwsA(isA<PlanTransferException>()),
    );
    expect(calls, 0);
    await expectLater(
      platform.saveFile('valid'),
      throwsA(isA<PlanTransferException>()),
    );
    expect(calls, 1);
  });
  test('clipboard is accessed only by explicit calls and failures are user readable', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      if (call.method == 'Clipboard.getData') return {'text': 'import'};
      return null;
    });
    final platform = AndroidPlanTransferPlatform();
    expect(calls, isEmpty);
    await platform.copyText('export');
    expect(await platform.readClipboard(), 'import');
    expect(calls.map((c) => c.method), [
      'Clipboard.setData',
      'Clipboard.getData',
    ]);
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async =>
          throw PlatformException(code: 'failed', message: 'native stack'),
    );
    await expectLater(
      platform.copyText('text'),
      throwsA(
        isA<PlanTransferException>().having(
          (e) => e.message,
          'message',
          isNot(contains('native stack')),
        ),
      ),
    );
    await expectLater(
      platform.readClipboard(),
      throwsA(isA<PlanTransferException>()),
    );
  });
}
