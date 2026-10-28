import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostic_observation.dart';
import '../../core/diagnostics/diagnostics_client.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import 'rest_alert_platform.dart';
import 'rest_alert_repository.dart';
import 'rest_alert_options.dart';

class RestAlertService extends ChangeNotifier {
  RestAlertService(this.repository, this.platform, {this.diagnostics}) {
    platform.onTap = (id) => onTap?.call(id);
    platform.onTapDetails = (tap) => onTapDetails?.call(tap);
    platform.onDelivered = (body) {
      onDelivered?.call(body);
      unawaited(
        synchronize(trigger: DiagnosticValue.delivered_callback)
            .catchError((Object _) {}),
      );
    };
  }
  final DiagnosticsClient? diagnostics;
  DiagnosticsClient get _diagnostics =>
      diagnostics ?? DiagnosticsClient.instance;
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
  final Map<int, String> _scheduled = {};
  final Map<int, int> _notificationRevisions = {};
  RestAlertOptions options = const RestAlertOptions();
  List<RestAlertEvent> awaiting = [];
  void Function(RestAlertTap)? onTapDetails;
  String get localeName => _strings?.localeName ?? 'en';

  Future<void> setOptions(RestAlertOptions value) async {
    return diagnosticObserve(
      _diagnostics,
      DiagnosticName.settingsSave,
      () async {
        await repository.setOptions(value);
        DiagnosticScope.current?.commit();
        options = value;
        notifyListeners();
        try {
          await synchronize(trigger: DiagnosticValue.settings_change);
        } catch (error, stack) {
          DiagnosticScope.current?.followupFailure(
            error,
            stack,
            at: DiagnosticPhase.schedule,
          );
          /* Training and saved settings remain valid. */
        }
      },
      inferCommitOnSuccess: false,
    );
  }

  Future<void> acknowledge(RestAlertEvent event, {int? revision}) async {
    return diagnosticObserve(
      _diagnostics,
      DiagnosticName.restAcknowledge,
      () async {
        final current = await repository.awaiting();
        final matching = current.where(
          (e) => e.id == event.id && e.sessionId == event.sessionId,
        );
        if (matching.isEmpty) {
          await synchronize(trigger: DiagnosticValue.acknowledge);
          return;
        }
        if (!await repository.acknowledge(
          event.id,
          event.sessionId,
          revision: revision ?? matching.first.revision,
        )) {
          // A competing confirmation or training action may already have stopped it.
          final remaining = await repository.awaiting();
          if (!remaining.any(
            (e) => e.id == event.id && e.sessionId == event.sessionId,
          )) {
            await synchronize(trigger: DiagnosticValue.acknowledge);
            return;
          }
          throw StateError('reminderChanged');
        }
        DiagnosticScope.current?.commit();
        DiagnosticScope.current?.phase = DiagnosticPhase.cancelled;
        awaiting = awaiting.where((e) => e.id != event.id).toList();
        notifyListeners();
        // Confirmation is durable even if platform projection cleanup fails.
        try {
          await platform.stopOutput(event.id);
          await synchronize(trigger: DiagnosticValue.acknowledge);
        } catch (error, stack) {
          DiagnosticScope.current?.followupFailure(
            error,
            stack,
            at: DiagnosticPhase.cancelled,
          );
          failed = true;
          notifyListeners();
        }
      },
      inferCommitOnSuccess: false,
      objects: {
        DiagnosticObject.rest_alert: event.id,
        DiagnosticObject.session: event.sessionId,
      },
    );
  }

  Future<void> acknowledgeTap(RestAlertTap tap) async {
    if (tap.eventId == null) return;
    final matches = (await repository.awaiting()).where(
      (e) => e.id == tap.eventId && e.sessionId == tap.sessionId,
    );
    if (matches.isNotEmpty) {
      await acknowledge(matches.first, revision: tap.revision);
    }
  }

  Future<void> configure(
    AppLocalizations strings, {
    bool expireElapsed = false,
  }) {
    _strings = strings;
    return synchronize(
      expireElapsed: expireElapsed,
      trigger: expireElapsed
          ? DiagnosticValue.startup
          : DiagnosticValue.settings_change,
    );
  }

  Future<void> synchronize({
    bool expireElapsed = false,
    bool offerPermission = false,
    DiagnosticValue trigger = DiagnosticValue.training_change,
  }) {
    final context = DiagnosticContext.capture(
      trigger,
      epoch: _diagnostics.datasetEpoch,
    );
    final next = _tail.then(
      (_) => context.run(() => _synchronize(expireElapsed, offerPermission)),
    );
    // Expose the original failure to callers, while keeping the serial queue usable.
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _synchronize(bool expireElapsed, bool offerPermission) async {
    return diagnosticObserve(
      _diagnostics,
      DiagnosticName.restSynchronize,
      () async {
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
          options = RestAlertOptions.fromMap(prefs);
          await platform.configureOutput(options, l.localeName);
          permissionRequested = prefs['permission_requested'] == 1;
          final previous = capability;
          capability = await platform.capabilities();
          if (previous?.exact != capability!.exact ||
              previous?.notifications != capability!.notifications) {
            _diagnostics.event(
              DiagnosticName.restSynchronize,
              phase: DiagnosticPhase.completed,
              parent: DiagnosticScope.current?.visibleOperation,
              fields: {
                DiagnosticField.trigger: diagnosticTrigger,
                DiagnosticField.exact_allowed: capability!.exact,
                DiagnosticField.notifications_allowed:
                    capability!.notifications,
              },
            );
          }
          if (previous?.exact != capability!.exact ||
              previous?.notifications != capability!.notifications) {
            _scheduled.clear();
          }
          var pending = await repository.active();
          if (!enabled || permissionRequested || capability!.notifications) {
            permissionNeeded = false;
          } else if (offerPermission &&
              pending.any((e) => e.dueAt > repository.nowMs)) {
            permissionNeeded = true;
          }
          final ids = enabled ? pending.map((e) => e.id).toSet() : <int>{};
          await platform.cancelExcept(ids);
          _scheduled.removeWhere((id, _) => !ids.contains(id));
          _notificationRevisions.removeWhere((id, _) => !ids.contains(id));
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
            if (event.awaitingConfirmation &&
                _notificationRevisions[event.id] != event.revision) {
              await platform.refreshNotification(event);
              _notificationRevisions[event.id] = event.revision;
            }
            final at = event.deliveryAt;
            if (at == null) continue;
            if (at <= repository.nowMs) {
              if (!expireElapsed) {
                await _observeRequest(
                  event,
                  DiagnosticName.restOutput,
                  () => platform.deliver(event),
                );
              }
            } else if (_scheduled[event.id] != event.scheduleKey) {
              await _observeRequest(
                event,
                DiagnosticName.restSchedule,
                () => platform.schedule(event),
              );
              _scheduled[event.id] = event.scheduleKey;
            }
          }
          awaiting = await repository.awaiting();
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
      },
      inferCommitOnSuccess: false,
      recordSuccess: false,
      readOnly: true,
      nestReadScope: true,
    );
  }

  String _lastStatus = '';
  Future<void> _observeRequest(
    RestAlertEvent event,
    DiagnosticName name,
    Future<void> Function() request,
  ) => diagnosticObserve(
    _diagnostics,
    name,
    request,
    readOnly: true,
    nestReadScope: true,
    objects: {
      DiagnosticObject.rest_alert: event.id,
      DiagnosticObject.session: event.sessionId,
    },
    fields: {
      DiagnosticField.trigger: diagnosticTrigger,
      DiagnosticField.revision: event.revision,
      DiagnosticField.round: event.sequence,
      DiagnosticField.due_utc: ?event.deliveryAt,
    },
  );
  String get status =>
      '$enabled:$failed:${capability?.notifications}:${capability?.exact}:$permissionRequested:${options.toMap()}:${awaiting.map((e) => '${e.id}:${e.scheduleKey}').join(',')}';

  Future<void> setEnabled(bool value) async {
    return diagnosticObserve(
      _diagnostics,
      DiagnosticName.settingsSave,
      () async {
        // No UI or platform side effects before the preference transaction commits.
        await repository.setEnabled(value);
        DiagnosticScope.current?.commit(
          fields: {DiagnosticField.enabled: value},
        );
        DiagnosticScope.current?.phase = DiagnosticPhase.schedule;
        enabled = value;
        if (value &&
            !permissionRequested &&
            capability?.notifications != true) {
          permissionNeeded = true;
        }
        notifyListeners();
        await synchronize(trigger: DiagnosticValue.settings_change);
        if (value &&
            !permissionRequested &&
            capability?.notifications != true) {
          permissionNeeded = true;
          notifyListeners();
        }
      },
      inferCommitOnSuccess: false,
    );
  }

  Future<void> acknowledgePermission({required bool request}) async {
    return diagnosticObserve(
      _diagnostics,
      DiagnosticName.settingsSave,
      () async {
        await repository.markPermissionRequested();
        DiagnosticScope.current?.commit();
        DiagnosticScope.current?.phase = DiagnosticPhase.schedule;
        permissionRequested = true;
        permissionNeeded = false;
        if (request) await platform.requestNotifications();
        await synchronize(trigger: DiagnosticValue.settings_change);
      },
      inferCommitOnSuccess: false,
    );
  }

  Future<int?> takeInitialTap() => platform.takeInitialTap();
  Future<RestAlertTap?> takeInitialTapDetails() =>
      platform.takeInitialTapDetails();
  @override
  void dispose() {
    _disposed = true;
    platform.dispose();
    super.dispose();
  }
}
