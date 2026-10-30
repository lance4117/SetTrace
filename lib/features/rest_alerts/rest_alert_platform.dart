import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostic_observation.dart';
import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostics_client.dart';

import 'rest_alert_repository.dart';
import 'rest_alert_options.dart';
import 'rest_delivery_status.dart';

class RestAlertTap {
  const RestAlertTap(this.sessionId, {this.eventId, this.revision});
  final int sessionId;
  final int? eventId, revision;
  factory RestAlertTap.fromValue(dynamic value) => value is int
      ? RestAlertTap(value)
      : RestAlertTap(
          (value['session_id'] as num).toInt(),
          eventId: (value['id'] as num?)?.toInt(),
          revision: (value['revision'] as num?)?.toInt(),
        );
}

class RestAlertCapabilities {
  const RestAlertCapabilities({
    required this.notifications,
    required this.exact,
  });
  final bool notifications, exact;
  factory RestAlertCapabilities.fromMap(Map<dynamic, dynamic> value) =>
      RestAlertCapabilities(
        notifications: value['notifications'] == true,
        exact: value['exact'] == true,
      );
}

abstract class RestAlertPlatform {
  void Function(int sessionId)? onTap;
  void Function(RestAlertTap)? onTapDetails;
  void Function(String body)? onDelivered;
  Future<void> initialize(
    String databasePath,
    String channelName,
    String description,
  );
  Future<RestAlertCapabilities> capabilities();
  Future<void> schedule(RestAlertEvent event);
  Future<void> deliver(RestAlertEvent event);
  Future<void> cancelExcept(Set<int> validIds);
  Future<void> requestNotifications();
  Future<void> openSettings({required bool exact});
  Future<int?> takeInitialTap();
  Future<RestAlertTap?> takeInitialTapDetails() async {
    final id = await takeInitialTap();
    return id == null ? null : RestAlertTap(id);
  }

  Future<void> configureOutput(RestAlertOptions options, String locale) async {}
  Future<void> preview(String sound, String locale) async {}
  Future<Map<String, dynamic>> soundStatus() async => {'condition': 'unknown'};
  Future<void> previewSystem() => preview('system', 'en');
  Future<void> stopPreview() async {}
  Future<void> stopOutput(int id) async {}
  Future<void> refreshNotification(RestAlertEvent event) async {}
  Future<bool> initialRecoveryIsWarm() async => false;
  Future<bool> takeSettingsReturn() async => false;
  Future<void> startTraining(int sessionId, String title, String body) async {}
  Future<void> reconcileTraining({String? recovery}) async {}
  Future<void> suspendTraining() async {}
  Future<void> updateTrainingLabels(String title, String body) async {}
  Future<RestDeliveryStatus> deliveryStatus() async =>
      RestDeliveryStatus.unsupported();
  void dispose() {}
}

class AndroidRestAlertPlatform extends RestAlertPlatform {
  Map<String, Object?> get _diagnosticContext => {
    if (DiagnosticScope.current case final scope?)
      'diagnostic_operation': scope.visibleOperation,
    'diagnostic_epoch': ?(DiagnosticScope.current != null
        ? DiagnosticScope.current!.operation.epoch
        : DiagnosticsClient.instance.datasetEpoch),
    'diagnostic_trigger':
        DiagnosticScope.current?.operation.name ==
            DiagnosticName.restAcknowledge
        ? 'acknowledge'
        : diagnosticTrigger.name,
    'cancel_reason': diagnosticRestCancellation.name,
  };
  final MethodChannel channel = const MethodChannel('settrace/rest_alerts');
  @override
  Future<bool> initialRecoveryIsWarm() async =>
      await channel.invokeMethod<bool>('initialRecoveryIsWarm') ?? false;
  @override
  Future<bool> takeSettingsReturn() async =>
      await channel.invokeMethod<bool>('takeSettingsReturn') ?? false;
  @override
  Future<void> startTraining(int sessionId, String title, String body) =>
      channel.invokeMethod('startTraining', {
        'session_id': sessionId,
        'title': title,
        'body': body,
      });
  @override
  Future<void> reconcileTraining({String? recovery}) =>
      channel.invokeMethod('reconcileTraining', {'recovery': recovery});
  @override
  Future<void> suspendTraining() => channel.invokeMethod('suspendTraining');
  @override
  Future<void> updateTrainingLabels(String title, String body) =>
      channel.invokeMethod('trainingLabels', {'title': title, 'body': body});
  @override
  Future<RestDeliveryStatus> deliveryStatus() async =>
      RestDeliveryStatus.fromMap(
        (await channel.invokeMapMethod<String, dynamic>('deliveryStatus'))!,
      );
  AndroidRestAlertPlatform() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTap') {
        final tap = RestAlertTap.fromValue(call.arguments);
        if (onTapDetails != null) {
          onTapDetails!(tap);
        } else {
          onTap?.call(tap.sessionId);
        }
      }
      if (call.method == 'delivered') {
        onDelivered?.call(
          call.arguments is String
              ? call.arguments as String
              : (call.arguments as Map)['body'] as String,
        );
      }
    });
  }
  @override
  Future<void> initialize(
    String databasePath,
    String channelName,
    String description,
  ) => channel.invokeMethod('initialize', {
    'path': databasePath,
    'channelName': channelName,
    'description': description,
  });
  @override
  Future<RestAlertCapabilities> capabilities() async =>
      RestAlertCapabilities.fromMap(
        (await channel.invokeMapMethod('capabilities'))!,
      );
  @override
  Future<void> schedule(RestAlertEvent event) =>
      channel.invokeMethod('schedule', {...event.row, ..._diagnosticContext});
  @override
  Future<void> deliver(RestAlertEvent event) =>
      channel.invokeMethod('deliver', {
        'id': event.id,
        'revision': event.revision,
        'sequence': event.sequence,
        'dataset_epoch': event.row['dataset_epoch'],
        ..._diagnosticContext,
      });
  @override
  Future<void> cancelExcept(Set<int> validIds) => channel.invokeMethod(
    'cancelExcept',
    {'ids': validIds.toList(), ..._diagnosticContext},
  );
  @override
  Future<void> requestNotifications() =>
      channel.invokeMethod('requestNotifications');
  @override
  Future<void> openSettings({required bool exact}) =>
      channel.invokeMethod('openSettings', {'exact': exact});
  @override
  Future<int?> takeInitialTap() async =>
      (await takeInitialTapDetails())?.sessionId;
  @override
  Future<RestAlertTap?> takeInitialTapDetails() async {
    final value = await channel.invokeMethod('takeInitialTap');
    return value == null ? null : RestAlertTap.fromValue(value);
  }

  @override
  Future<void> configureOutput(RestAlertOptions options, String locale) =>
      channel.invokeMethod('configureOutput', {
        ...options.toMap(),
        'locale': locale,
      });
  @override
  Future<void> preview(String sound, String locale) =>
      channel.invokeMethod('preview', {'sound': sound, 'locale': locale});
  @override
  Future<void> refreshNotification(RestAlertEvent event) =>
      channel.invokeMethod('refreshNotification', {
        'id': event.id,
        'revision': event.revision,
      });
  @override
  Future<Map<String, dynamic>> soundStatus() async =>
      (await channel.invokeMapMethod<String, dynamic>('soundStatus'))!;
  @override
  Future<void> previewSystem() async {
    final result = await channel.invokeMapMethod<String, dynamic>('preview');
    final state = result?['state'];
    if (state != 'completed' && state != 'stopped') {
      throw PlatformException(code: state as String? ?? 'previewFailed');
    }
  }

  @override
  Future<void> stopPreview() => channel.invokeMethod('stopPreview');
  @override
  Future<void> stopOutput(int id) =>
      channel.invokeMethod('stopOutput', {'id': id, ..._diagnosticContext});
  @override
  void dispose() {
    channel.setMethodCallHandler(null);
  }
}
