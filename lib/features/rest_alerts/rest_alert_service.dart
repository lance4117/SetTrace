import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import 'rest_alert_platform.dart';
import 'rest_alert_repository.dart';

class RestAlertService extends ChangeNotifier {
  RestAlertService(this.repository, this.platform) {
    platform.onTap = (id) => onTap?.call(id);
    platform.onDelivered = (body) => onDelivered?.call(body);
  }
  final RestAlertRepository repository;
  final RestAlertPlatform platform;
  AppLocalizations? _strings;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  bool enabled = true, failed = false, permissionRequested = false;
  RestAlertCapabilities? capability;
  bool permissionNeeded = false;
  void Function(int)? onTap;
  void Function(String)? onDelivered;
  final Map<int, int> _scheduled = {};

  Future<void> configure(
    AppLocalizations strings, {
    bool expireElapsed = false,
  }) {
    _strings = strings;
    return synchronize(expireElapsed: expireElapsed);
  }

  Future<void> synchronize({
    bool expireElapsed = false,
    bool offerPermission = false,
  }) {
    final next = _tail.then(
      (_) => _synchronize(expireElapsed, offerPermission),
    );
    // Expose the original failure to callers, while keeping the serial queue usable.
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _synchronize(bool expireElapsed, bool offerPermission) async {
    if (_disposed || _strings == null) return;
    try {
      final l = _strings!;
      await platform.initialize(
        repository.db.path,
        l.restAlertChannelName,
        l.restAlertChannelDescription,
      );
      await repository.restore(expireElapsed: expireElapsed);
      final prefs = await repository.preferences();
      enabled = prefs['enabled'] == 1;
      permissionRequested = prefs['permission_requested'] == 1;
      final previous = capability;
      capability = await platform.capabilities();
      if (previous?.exact != capability!.exact ||
          previous?.notifications != capability!.notifications) {
        _scheduled.clear();
      }
      var pending = await repository.pending();
      if (!enabled || permissionRequested || capability!.notifications) {
        permissionNeeded = false;
      } else if (offerPermission &&
          pending.any((e) => e.dueAt > repository.nowMs)) {
        permissionNeeded = true;
      }
      final valid = await repository.db.rawQuery("""
        SELECT a.id FROM rest_alerts a JOIN workout_sessions s ON s.id = a.session_id
        WHERE a.state IN ('pending', 'consumed') AND s.status = 'in_progress'
          AND s.current_rest_alert_id = a.id
      """);
      final ids = enabled ? valid.map((e) => e['id'] as int).toSet() : <int>{};
      await platform.cancelExcept(ids);
      _scheduled.removeWhere((id, _) => !ids.contains(id));
      for (var event in pending) {
        event = await repository.setContent(
          event,
          l.restEnded,
          l.restEndedBody(
            event.row['name_snapshot'] as String,
            event.row['set_number'] as int,
            event.row['target_sets'] as int,
          ),
        );
        if (event.row['state'] != 'pending') continue;
        if (event.dueAt <= repository.nowMs) {
          if (!expireElapsed) await platform.deliver(event);
        } else if (_scheduled[event.id] != event.revision) {
          await platform.schedule(event);
          _scheduled[event.id] = event.revision;
        }
      }
      final shouldNotify = failed;
      failed = false;
      // Settings capabilities and permissions can change outside this process.
      if (!_disposed &&
          (shouldNotify || permissionNeeded || _lastStatus != status)) {
        _lastStatus = status;
        notifyListeners();
      }
    } catch (_) {
      final changed = !failed;
      failed = true;
      if (!_disposed && changed) notifyListeners();
      rethrow;
    }
  }

  String _lastStatus = '';
  String get status =>
      '$enabled:$failed:${capability?.notifications}:${capability?.exact}:$permissionRequested';

  Future<void> setEnabled(bool value) async {
    // No UI or platform side effects before the preference transaction commits.
    await repository.setEnabled(value);
    enabled = value;
    if (value && !permissionRequested && capability?.notifications != true) {
      permissionNeeded = true;
    }
    notifyListeners();
    await synchronize();
    if (value && !permissionRequested && capability?.notifications != true) {
      permissionNeeded = true;
      notifyListeners();
    }
  }

  Future<void> acknowledgePermission({required bool request}) async {
    await repository.markPermissionRequested();
    permissionRequested = true;
    permissionNeeded = false;
    if (request) await platform.requestNotifications();
    await synchronize();
  }

  Future<int?> takeInitialTap() => platform.takeInitialTap();
  @override
  void dispose() {
    _disposed = true;
    platform.dispose();
    super.dispose();
  }
}
