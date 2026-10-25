import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostic_observation.dart';
import '../../core/diagnostics/diagnostics_client.dart';

import 'rest_alert_repository.dart';
import 'rest_alert_options.dart';

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
  Future<void> stopPreview() async {}
  Future<void> stopOutput(int id) async {}
  Future<void> refreshNotification(RestAlertEvent event) async {}
  void dispose() {}
}

class AndroidRestAlertPlatform extends RestAlertPlatform {
  Map<String, Object?> get _diagnosticContext => {
    if (DiagnosticScope.current case final scope?)
      'diagnostic_operation': scope.operation.id,
    'diagnostic_epoch': ?DiagnosticsClient.instance.datasetEpoch,
  };
  final MethodChannel channel = const MethodChannel('settrace/rest_alerts');
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
        ..._diagnosticContext,
      });
  @override
  Future<void> cancelExcept(Set<int> validIds) =>
      channel.invokeMethod('cancelExcept', {'ids': validIds.toList()});
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
  Future<void> stopPreview() => channel.invokeMethod('stopPreview');
  @override
  Future<void> stopOutput(int id) =>
      channel.invokeMethod('stopOutput', {'id': id});
  @override
  void dispose() {
    channel.setMethodCallHandler(null);
  }
}
