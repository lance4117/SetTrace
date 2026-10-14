import 'package:flutter/services.dart';

import 'rest_alert_repository.dart';

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
  void dispose() {}
}

class AndroidRestAlertPlatform extends RestAlertPlatform {
  final MethodChannel channel = const MethodChannel('settrace/rest_alerts');
  AndroidRestAlertPlatform() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTap') onTap?.call(call.arguments as int);
      if (call.method == 'delivered') {
        onDelivered?.call(call.arguments as String);
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
      channel.invokeMethod('schedule', event.row);
  @override
  Future<void> deliver(RestAlertEvent event) => channel.invokeMethod(
    'deliver',
    {'id': event.id, 'revision': event.revision},
  );
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
  Future<int?> takeInitialTap() => channel.invokeMethod<int>('takeInitialTap');
  @override
  void dispose() {
    channel.setMethodCallHandler(null);
  }
}
