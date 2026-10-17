import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_codec.dart';
import 'backup_json.dart';
import 'backup_metadata_repository.dart';

class BackupRecoveryStore {
  BackupRecoveryStore(this.directory, this.metadata, {this.checkpoint});
  final Directory directory;
  final BackupMetadataRepository metadata;
  final Future<void> Function(String phase)? checkpoint;
  static final _name = RegExp(r'^[a-zA-Z0-9_-]+\.settrace\.json$');

  File _file(String name) {
    if (!_name.hasMatch(name) || p.basename(name) != name) invalidBackup();
    return File(p.join(directory.path, name));
  }

  Future<String> protect(String operationId, BackupDocument document) async {
    final target = _file('$operationId.settrace.json');
    final temporary = File('${target.path}.partial');
    await directory.create(recursive: true);
    // An operation owns one immutable before-copy. Never overwrite on retry.
    if (await target.exists() || await temporary.exists()) {
      throw const BackupException(BackupFailure.protection);
    }
    await checkpoint?.call('before_write');
    await BackupCodec.writeFile(temporary.path, document);
    await checkpoint?.call('after_flush');
    await temporary.rename(target.path);
    await checkpoint?.call('after_rename');
    final reread = await BackupCodec.readFile(target.path);
    if ((await BackupFingerprints.compute(reread.data)).contentDigest !=
        (await BackupFingerprints.compute(document.data)).contentDigest) {
      throw const BackupException(BackupFailure.protection);
    }
    await checkpoint?.call('after_verify');
    await _register(operationId, target, reread);
    await checkpoint?.call('after_register');
    return operationId;
  }

  Future<void> _register(String id, File file, BackupDocument document) async {
    await metadata.registerCopy({
      'id': id,
      'operation_id': (await metadata.operation(id)) == null ? null : id,
      'snapshot_at': document.snapshotAt.toUtc().toIso8601String(),
      'relative_path': p.basename(file.path),
      'digest': document.digest,
      'schema_version': 1,
      'plan_count': document.data.plans.length,
      'workout_count': document.data.workouts.length,
      'byte_count': await file.length(),
      'state': 'ready',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<BackupDocument> read(String id) async {
    final entry = await metadata.copy(id);
    if (entry == null || entry['state'] != 'ready') {
      throw const BackupException(BackupFailure.missingCopy);
    }
    try {
      final doc = await BackupCodec.readFile(
        _file(entry['relative_path'] as String).path,
      );
      if (doc.digest != entry['digest']) {
        throw const BackupException(BackupFailure.integrity);
      }
      return doc;
    } catch (_) {
      await metadata.setCopyState(id, 'missing');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final row = await metadata.copy(id);
    if (row == null) throw const BackupException(BackupFailure.missingCopy);
    await metadata.setCopyState(id, 'deleting');
    await checkpoint?.call('before_delete');
    final file = _file(row['relative_path'] as String);
    if (await file.exists()) await file.delete();
    await checkpoint?.call('after_delete');
    await metadata.removeDeletedCopy(id);
  }

  /// Only explicitly authorised deleting entries are removed. Complete orphans
  /// are indexed, and missing/corrupt entries remain visible as unavailable.
  Future<void> reconcile() async {
    await directory.create(recursive: true);
    for (final row in await metadata.copies()) {
      final id = row['id'] as String;
      if (row['state'] == 'deleting') {
        await delete(id);
      } else if (row['state'] == 'ready' || row['state'] == 'missing') {
        try {
          if (row['state'] == 'missing') {
            final doc = await BackupCodec.readFile(
              _file(row['relative_path'] as String).path,
            );
            if (doc.digest == row['digest']) {
              await metadata.setCopyState(id, 'ready');
            }
          } else {
            await read(id);
          }
        } on BackupException {
          /* retained as unavailable */
        } on FileSystemException {
          /* retained as unavailable */
        }
      }
    }
    final known = {
      for (final row in await metadata.copies()) row['relative_path'],
    };
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.endsWith('.partial') &&
          _name.hasMatch(name.substring(0, name.length - 8))) {
        await entity.delete();
      } else if (_name.hasMatch(name) && !known.contains(name)) {
        // Invalid complete files are retained for diagnosis, never auto-deleted.
        try {
          final doc = await BackupCodec.readFile(entity.path);
          await _register(
            name.substring(0, name.length - '.settrace.json'.length),
            entity,
            doc,
          );
        } on BackupException {
          /* cannot register an unverified copy */
        }
      }
    }
  }
}
