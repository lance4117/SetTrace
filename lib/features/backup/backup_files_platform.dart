import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'backup_json.dart';
import 'backup_models.dart';

class BackupFileCandidate {
  const BackupFileCandidate({
    required this.token,
    required this.fileName,
    required this.bytes,
  });
  final String token, fileName;
  final int bytes;
}

abstract class BackupFilesPlatform {
  Future<void> initialize();
  Directory get recoveryDirectory;
  String pathFor(String token);
  Future<String> allocate();
  Future<BackupFileCandidate?> pick();
  Future<void> discard(String token);
  Future<BackupMap> reserve(String requestId, String token);
  Future<BackupMap> publish(String requestId);
  Future<BackupMap> inspect(String requestId);
  Future<void> cleanup(String requestId);
}

class AndroidBackupFilesPlatform implements BackupFilesPlatform {
  AndroidBackupFilesPlatform({
    this.channel = const MethodChannel('settrace/backup_files'),
  });
  final MethodChannel channel;
  String? _stageRoot, _recoveryRoot;
  static final tokenPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  @override
  Future<void> initialize() async {
    final result = await _call('initialize');
    _stageRoot = result['stageRoot'] as String;
    _recoveryRoot = result['recoveryRoot'] as String;
  }

  @override
  Directory get recoveryDirectory => Directory(_recoveryRoot!);
  @override
  String pathFor(String token) {
    if (!tokenPattern.hasMatch(token) || _stageRoot == null) invalidBackup();
    return p.join(_stageRoot!, '$token.json');
  }

  @override
  Future<String> allocate() async =>
      (await _call('allocate'))['token'] as String;
  @override
  Future<BackupFileCandidate?> pick() async {
    final result = await _call('pick');
    if (result['status'] == 'cancelled') return null;
    final token = result['token'] as String;
    pathFor(token);
    return BackupFileCandidate(
      token: token,
      fileName: result['fileName'] as String,
      bytes: result['bytes'] as int,
    );
  }

  @override
  Future<void> discard(String token) async {
    await _call('discard', {'token': token});
  }

  @override
  Future<BackupMap> reserve(String requestId, String token) =>
      _call('reserve', {'requestId': requestId, 'token': token});
  @override
  Future<BackupMap> publish(String requestId) =>
      _call('publish', {'requestId': requestId});
  @override
  Future<BackupMap> inspect(String requestId) =>
      _call('inspect', {'requestId': requestId});
  @override
  Future<void> cleanup(String requestId) async {
    await _call('cleanup', {'requestId': requestId});
  }

  Future<BackupMap> _call(
    String method, [
    BackupMap arguments = const {},
  ]) async {
    try {
      final raw = await channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      if (raw == null) throw const BackupException(BackupFailure.storage);
      if (raw['status'] == 'error') {
        throw BackupException(switch (raw['code']) {
          'tooLarge' => BackupFailure.tooLarge,
          'busy' => BackupFailure.busy,
          'readFailed' => BackupFailure.readFailed,
          _ => BackupFailure.storage,
        });
      }
      return raw;
    } on PlatformException {
      throw const BackupException(BackupFailure.storage);
    }
  }
}
