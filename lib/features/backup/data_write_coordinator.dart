import 'dart:async';

import 'backup_json.dart';

/// Stops admission BEFORE draining. No lock needed by an admitted writer is
/// held while waiting, including coalesced preference/controller work.
class DataWriteCoordinator {
  DataWriteCoordinator({this._epoch = 0});
  int _epoch;
  bool _epochKnown = false;
  bool _exclusive = false, _restricted = false;
  int _writers = 0;
  Completer<void>? _drained;
  final Object _zoneKey = Object();
  final List<Future<void> Function()> settlers = [];
  int get epoch => _epoch;
  int? get diagnosticEpoch => _epochKnown ? _epoch : null;
  bool get blocked => _exclusive || _restricted;

  void restrict() => _restricted = true;
  void reconcile(int epoch) {
    _epoch = epoch;
    _epochKnown = true;
    _restricted = false;
  }

  Future<T> write<T>(Future<T> Function() action, {int? expectedEpoch}) {
    final parent = Zone.current[_zoneKey];
    if (parent is _WriteLease && parent.active && parent.epoch == _epoch) {
      return action();
    }
    if (blocked) return Future.error(const BackupException(BackupFailure.busy));
    if (expectedEpoch != null && expectedEpoch != _epoch) {
      return Future.error(const BackupException(BackupFailure.stalePreview));
    }
    final lease = _WriteLease(_epoch);
    _writers++;
    return runZoned(() async {
      try {
        if (lease.epoch != _epoch) {
          throw const BackupException(BackupFailure.stalePreview);
        }
        return await action();
      } finally {
        lease.active = false;
        if (--_writers == 0) {
          _drained?.complete();
          _drained = null;
        }
      }
    }, zoneValues: {_zoneKey: lease});
  }

  Future<T> exclusive<T>(
    Future<T> Function() action, {
    bool reconciliation = false,
  }) async {
    if (_exclusive || (_restricted && !reconciliation)) {
      throw const BackupException(BackupFailure.busy);
    }
    _exclusive = true;
    try {
      if (_writers != 0) await (_drained ??= Completer<void>()).future;
      for (final settle in settlers) {
        await settle();
      }
      final lease = _WriteLease(_epoch);
      try {
        return await runZoned(action, zoneValues: {_zoneKey: lease});
      } finally {
        lease.active = false;
      }
    } finally {
      _exclusive = false;
    }
  }

  void committed(int epoch) {
    if (!_exclusive || epoch <= _epoch) {
      throw StateError('Invalid dataset commit');
    }
    _epoch = epoch;
    _epochKnown = true;
    final lease = Zone.current[_zoneKey];
    if (lease is _WriteLease) lease.epoch = epoch;
  }
}

class _WriteLease {
  _WriteLease(this.epoch);
  int epoch;
  bool active = true;
}
