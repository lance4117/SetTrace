import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/theme_color_controller.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';

class ControlledColors implements ThemeColorStore {
  Object? value;
  bool readFails = false, reloadFails = false;
  final writes = <ThemeColorPreset>[];
  final pending = <Completer<bool>>[];
  @override
  Object? read() {
    if (readFails) throw StateError('read');
    return value;
  }

  @override
  Future<bool> write(ThemeColorPreset preset) async {
    writes.add(preset);
    final c = Completer<bool>();
    pending.add(c);
    final result = await c.future;
    if (result) value = preset.name;
    return result;
  }

  @override
  Future<void> recover(ThemeColorPreset confirmed) async {
    if (reloadFails) throw StateError('reload');
  }
}

class FailingColorPreferences extends InMemorySharedPreferencesStore {
  FailingColorPreferences() : super.withData({});
  bool failWrite = true, failReload = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async =>
      failWrite ? false : super.setValue(type, key, value);
  @override
  Future<Map<String, Object>> getAll() async {
    if (failReload) throw StateError('reload');
    return super.getAll();
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy cache cannot promote a failed value after reload fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final original = SharedPreferencesStorePlatform.instance;
      final platform = FailingColorPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final c = ThemeColorController(PreferencesThemeColorStore(prefs));
      c.select(ThemeColorPreset.blue);
      await c.settled;
      expect(prefs.getString('theme_color'), 'blue'); // Legacy cache is dirty.
      expect(c.selected, ThemeColorPreset.teal);
      final recreated = ThemeColorController(PreferencesThemeColorStore(prefs));
      expect(recreated.selected, ThemeColorPreset.teal);
      platform.failWrite = false;
      platform.failReload = false;
      c.retry();
      await c.settled;
      await prefs.reload();
      expect(prefs.getString('theme_color'), 'blue');
      c.dispose();
      recreated.dispose();
    },
  );
  test('valid values restore and invalid/read failures safely default', () {
    for (final value in [
      null,
      5,
      'unknown',
      ...ThemeColorPreset.values.map((p) => p.name),
    ]) {
      final store = ControlledColors()..value = value;
      final c = ThemeColorController(store);
      expect(c.selected, ThemeColorPreset.parse(value));
      expect(store.writes, isEmpty);
      c.dispose();
    }
    final c = ThemeColorController(ControlledColors()..readFails = true);
    expect(c.selected, ThemeColorPreset.teal);
    c.dispose();
  });
  test('preview precedes save, duplicate taps coalesce, latest wins', () async {
    final store = ControlledColors();
    final c = ThemeColorController(store);
    c.select(ThemeColorPreset.blue);
    expect(c.selected, ThemeColorPreset.blue);
    expect(c.saving, isTrue);
    final beforeCommit = ThemeColorController(store);
    expect(beforeCommit.selected, ThemeColorPreset.teal);
    beforeCommit.dispose();
    c.select(ThemeColorPreset.blue);
    c.select(ThemeColorPreset.violet);
    c.select(ThemeColorPreset.graphite);
    expect(store.writes, [ThemeColorPreset.blue]);
    store.pending[0].complete(true);
    await tick();
    expect(c.selected, ThemeColorPreset.graphite);
    expect(store.writes, [ThemeColorPreset.blue, ThemeColorPreset.graphite]);
    store.pending[1].complete(true);
    await c.settled;
    expect(c.committed, ThemeColorPreset.graphite);
    expect(c.saving, isFalse);
    final restarted = ThemeColorController(store);
    expect(restarted.selected, ThemeColorPreset.graphite);
    c.dispose();
    restarted.dispose();
  });
  for (final throws in [false, true]) {
    test(
      'failure ($throws) rolls back despite reload failure and retry saves',
      () async {
        final store = ControlledColors()..reloadFails = true;
        final c = ThemeColorController(store);
        c.select(ThemeColorPreset.blue);
        if (throws) {
          store.pending[0].completeError(StateError('write'));
        } else {
          store.pending[0].complete(false);
        }
        await c.settled;
        expect(c.selected, ThemeColorPreset.teal);
        expect(c.failedTarget, ThemeColorPreset.blue);
        c.retry();
        c.retry();
        expect(c.selected, ThemeColorPreset.blue);
        expect(store.writes.length, 2);
        store.pending[1].complete(true);
        await c.settled;
        expect(c.failedTarget, isNull);
        expect(c.committed, ThemeColorPreset.blue);
        c.dispose();
      },
    );
  }
  for (final firstSuccess in [false, true]) {
    test(
      'stale result ($firstSuccess) does not replace latest preview',
      () async {
        final store = ControlledColors();
        final c = ThemeColorController(store);
        c.select(ThemeColorPreset.blue);
        c.select(ThemeColorPreset.violet);
        store.pending[0].complete(firstSuccess);
        await tick();
        expect(c.selected, ThemeColorPreset.violet);
        expect(c.failedTarget, isNull);
        store.pending[1].complete(false);
        await c.settled;
        expect(
          c.selected,
          firstSuccess ? ThemeColorPreset.blue : ThemeColorPreset.teal,
        );
        expect(c.failedTarget, ThemeColorPreset.violet);
        c.select(ThemeColorPreset.graphite);
        c.retry();
        store.pending[2].complete(true);
        await c.settled;
        expect(c.committed, ThemeColorPreset.graphite);
        expect(store.writes.length, 3);
        c.dispose();
      },
    );
  }
  test(
    'return to original while saving compensates intermediate success',
    () async {
      final store = ControlledColors();
      final c = ThemeColorController(store);
      c.select(ThemeColorPreset.blue);
      c.select(ThemeColorPreset.teal);
      store.pending[0].complete(true);
      await tick();
      expect(store.writes, [ThemeColorPreset.blue, ThemeColorPreset.teal]);
      store.pending[1].complete(true);
      await c.settled;
      expect(store.value, 'teal');
      c.dispose();
    },
  );
  test(
    'disposed presentation does not cancel the latest persistence',
    () async {
      final store = ControlledColors();
      final c = ThemeColorController(store);
      c.select(ThemeColorPreset.blue);
      c.select(ThemeColorPreset.violet);
      c.dispose();
      store.pending[0].complete(true);
      await tick();
      store.pending[1].complete(true);
      await c.settled;
      expect(store.value, 'violet');
    },
  );
}
