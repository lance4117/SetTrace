import 'dart:io';

import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_files_platform.dart';
import 'package:settrace/features/backup/backup_models.dart';

class FakeBackupPreferences implements BackupPreferences {
  FakeBackupPreferences(this.value);
  BackupSettings value;
  final failures = <String>{};
  final applied = <String>[];
  Future<void>? pending;
  @override
  Future<void> get settled => pending ?? Future.value();
  @override
  Future<BackupSettings> readConfirmed() async => value;
  @override
  Future<void> apply(String field, Object? target) async {
    applied.add(field);
    if (failures.contains(field)) {
      throw StateError('injected preference failure');
    }
    value = BackupSettings.fromJson({...value.toJson(), field: target});
  }
}

class FakeBackupFiles extends BackupFilesPlatform {
  FakeBackupFiles(this.root);
  final Directory root;
  int counter = 0;
  BackupFileCandidate? selected;
  Future<BackupFileCandidate?>? pendingPick;
  final exports = <String, BackupMap>{};
  bool failPublish = false, failAfterPublish = false;
  @override
  Directory get recoveryDirectory => Directory('${root.path}/recovery');
  @override
  Future<void> initialize() async {
    await root.create(recursive: true);
    await recoveryDirectory.create(recursive: true);
  }

  @override
  String pathFor(String token) => '${root.path}/$token.json';
  @override
  Future<String> allocate() async => 'candidate${counter++}';
  @override
  Future<void> discard(String token) async {
    final file = File(pathFor(token));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<BackupFileCandidate?> pick() async =>
      pendingPick == null ? selected : await pendingPick;
  @override
  Future<BackupMap> reserve(String requestId, String token) async =>
      exports[requestId] = {
        'status': 'success',
        'state': 'reserved',
        'token': token,
        'requestId': requestId,
        'fileName': 'SetTrace-backup-$requestId.settrace.json',
        'location': 'downloads',
        'target': '${root.path}/$requestId.saved',
      };
  @override
  Future<BackupMap> publish(String requestId) async {
    if (failPublish) throw StateError('injected publish failure');
    final result = exports[requestId]!;
    await File(pathFor(result['token'] as String))
        .copy(result['target'] as String);
    final saved = exports[requestId] = {...result, 'state': 'published'};
    if (failAfterPublish) throw StateError('lost publish acknowledgement');
    return saved;
  }

  @override
  Future<BackupMap> inspect(String requestId) async {
    final receipt = exports[requestId]!;
    return receipt['state'] == 'reserved'
        ? exports[requestId] = {...receipt, 'state': 'cleaned'}
        : receipt;
  }

  @override
  Future<void> cleanup(String requestId) async {
    exports.remove(requestId);
  }
}
