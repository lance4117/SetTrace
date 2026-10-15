import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_color_preset.dart';

abstract interface class ThemeColorStore {
  Object? read();
  Future<bool> write(ThemeColorPreset preset);
  Future<void> recover(ThemeColorPreset confirmed);
}

class PreferencesThemeColorStore implements ThemeColorStore {
  PreferencesThemeColorStore(this.preferences);
  static const key = 'theme_color';
  final SharedPreferences preferences;
  // The legacy API mutates its cache even when the platform write fails.
  // Keep confirmed values across controllers using that same cache instance,
  // including when reload itself fails. No unconfirmed value is promoted.
  static final _confirmed = Expando<ThemeColorPreset>();

  @override
  Object? read() => _confirmed[preferences]?.name ?? preferences.get(key);

  @override
  Future<bool> write(ThemeColorPreset preset) async {
    final saved = await preferences.setString(key, preset.name);
    if (saved) _confirmed[preferences] = preset;
    return saved;
  }

  @override
  Future<void> recover(ThemeColorPreset confirmed) async {
    _confirmed[preferences] = confirmed;
    await preferences.reload();
  }
}

class ThemeColorController extends ChangeNotifier {
  ThemeColorController(this.store) {
    try {
      _committed = ThemeColorPreset.parse(store.read());
    } catch (_) {
      _committed = ThemeColorPreset.teal;
    }
    _desired = _committed;
  }

  final ThemeColorStore store;
  late ThemeColorPreset _committed, _desired;
  ThemeColorPreset? _failed;
  bool _saving = false, _disposed = false;
  int _revision = 0;
  Future<void>? _work;

  ThemeColorPreset get selected => _desired;
  ThemeColorPreset get committed => _committed;
  ThemeColorPreset? get failedTarget => _failed;
  bool get saving => _saving;
  Future<void> get settled => _work ?? Future<void>.value();

  void select(ThemeColorPreset next) {
    if (_disposed || next == _desired) return;
    _desired = next;
    _failed = null;
    _revision++;
    if (!_saving) {
      _saving = true;
      _work = _save();
    }
    _emit();
  }

  void retry() {
    final target = _failed;
    if (target != null && !_saving) select(target);
  }

  Future<void> _save() async {
    while (_desired != _committed) {
      final target = _desired;
      final revision = _revision;
      var saved = false;
      try {
        saved = await store.write(target);
      } catch (_) {
        // Failure categories are displayed in the current UI language.
      }
      if (saved) {
        _committed = target;
      } else {
        try {
          await store.recover(_committed);
        } catch (_) {
          // Our confirmed value remains authoritative if cache reload fails.
        }
        if (revision == _revision) {
          _failed = target;
          _desired = _committed;
          break;
        }
      }
    }
    _saving = false;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
