import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'backup_json.dart';
import 'backup_models.dart';

/// Control metadata deliberately has no cascading foreign keys to business
/// rows. Methods accepting an executor participate in the caller's transaction.
class BackupMetadataRepository {
  const BackupMetadataRepository(this.db);
  final Database db;

  Future<BackupMap> state([DatabaseExecutor? executor]) async =>
      (await (executor ?? db).query('backup_state', where: 'id=1')).single;
  Future<int> epoch([DatabaseExecutor? executor]) async =>
      (await state(executor))['epoch'] as int;
  Future<BackupMap?> operation(String id, [DatabaseExecutor? executor]) async =>
      (await (executor ?? db).query(
        'backup_operations',
        where: 'id=?',
        whereArgs: [id],
      )).firstOrNull;
  Future<List<BackupMap>> operations() =>
      db.query('backup_operations', orderBy: 'created_at ASC, id ASC');
  Future<List<BackupMap>> copies() =>
      db.query('backup_copies', orderBy: 'created_at DESC, id DESC');
  Future<BackupMap?> copy(String id) async => (await db.query(
    'backup_copies',
    where: 'id=?',
    whereArgs: [id],
  )).firstOrNull;

  Future<void> begin({
    required String id,
    required String kind,
    required String sourceDigest,
    required String targetDigest,
    required int sourceEpoch,
    required bool restoreSettings,
    String? candidateDigest,
    BackupSettings? settingsTarget,
    BackupMap? targetSummary,
    String? undoOf,
    int? now,
  }) async {
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert('backup_operations', {
      'id': id,
      'kind': kind,
      'phase': kind == 'export' ? 'export_pending' : 'preparing',
      'source_digest': sourceDigest,
      'target_digest': targetDigest,
      'candidate_digest': candidateDigest,
      'target_summary': targetSummary == null
          ? null
          : jsonEncode(targetSummary),
      'source_epoch': sourceEpoch,
      'restore_settings': restoreSettings ? 1 : 0,
      'settings_target': settingsTarget == null
          ? null
          : jsonEncode(settingsTarget.toJson()),
      'undo_of': undoOf,
      'created_at': time,
      'updated_at': time,
    });
  }

  Future<void> updateOperation(
    String id,
    BackupMap values, [
    DatabaseExecutor? executor,
  ]) async {
    final count = await (executor ?? db).update(
      'backup_operations',
      {...values, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id=?',
      whereArgs: [id],
    );
    if (count != 1) throw const BackupException(BackupFailure.indeterminate);
  }

  Future<void> registerCopy(
    BackupMap values, [
    DatabaseExecutor? executor,
  ]) async {
    final path = values['relative_path'];
    if (path is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]+\.settrace\.json$').hasMatch(path)) {
      invalidBackup();
    }
    await (executor ?? db).insert('backup_copies', values);
  }

  Future<void> protect(String operationId, String copyId) => db.transaction((
    txn,
  ) async {
    final ready = await txn.query(
      'backup_copies',
      where: 'id=? AND state=?',
      whereArgs: [copyId, 'ready'],
    );
    if (ready.isEmpty) throw const BackupException(BackupFailure.protection);
    final op = await operation(operationId, txn);
    if (op == null || op['phase'] != 'preparing') {
      throw const BackupException(BackupFailure.stalePreview);
    }
    await updateOperation(operationId, {
      'phase': 'protected',
      'before_copy_id': copyId,
    }, txn);
  });

  /// MUST be called inside the same transaction as core data replacement.
  Future<int> commitCore(Transaction txn, String id, int expectedEpoch) async {
    final op = await operation(id, txn);
    if (op == null ||
        op['phase'] != 'protected' ||
        op['source_epoch'] != expectedEpoch) {
      throw const BackupException(BackupFailure.stalePreview);
    }
    final next = expectedEpoch + 1;
    final changed = await txn.update(
      'backup_state',
      {'epoch': next, 'undo_operation_id': op['kind'] == 'undo' ? null : id},
      where: 'id=1 AND epoch=?',
      whereArgs: [expectedEpoch],
    );
    if (changed != 1) throw const BackupException(BackupFailure.stalePreview);
    await updateOperation(id, {
      'phase': 'core_committed',
      'target_epoch': next,
    }, txn);
    if (op['kind'] == 'undo') {
      final original = op['undo_of'] as String?;
      if (original == null) invalidBackup();
      await updateOperation(original, {'undone_by': id}, txn);
    }
    return next;
  }

  Future<void> recordExport(
    String id, {
    required BackupMap result,
    required int exportedAt,
    required bool currentData,
  }) => db.transaction((txn) async {
    final op = await operation(id, txn);
    if (op == null || op['kind'] != 'export') invalidBackup();
    await updateOperation(id, {
      'phase': 'completed',
      'export_result': jsonEncode(result),
    }, txn);
    final previous = await state(txn);
    final order = await txn.rawQuery(
      '''SELECT rowid AS ordinal FROM backup_operations
      WHERE id IN (?, ?) ORDER BY rowid DESC LIMIT 1''',
      [id, previous['last_export_operation_id']],
    );
    final latest = await txn.rawQuery(
      'SELECT rowid AS ordinal FROM backup_operations WHERE id=?',
      [id],
    );
    if (currentData && order.single['ordinal'] == latest.single['ordinal']) {
      await txn.update('backup_state', {
        'last_export_operation_id': id,
        'last_export_digest': op['source_digest'],
        'last_export_at': exportedAt,
        'last_export_result': jsonEncode(result),
      }, where: 'id=1');
    }
  });

  Future<void> setCopyState(String id, String value) async {
    if (!['ready', 'deleting', 'missing'].contains(value)) invalidBackup();
    final changed = await db.update(
      'backup_copies',
      {'state': value},
      where: 'id=?',
      whereArgs: [id],
    );
    if (changed != 1) throw const BackupException(BackupFailure.missingCopy);
  }

  Future<void> removeDeletedCopy(String id) => db.transaction((txn) async {
    final rows = await txn.query(
      'backup_copies',
      where: 'id=? AND state=?',
      whereArgs: [id, 'deleting'],
    );
    if (rows.isEmpty) throw const BackupException(BackupFailure.missingCopy);
    await txn.delete('backup_copies', where: 'id=?', whereArgs: [id]);
    await txn.rawUpdate(
      '''UPDATE backup_state SET undo_operation_id=NULL
      WHERE undo_operation_id IN (SELECT id FROM backup_operations WHERE before_copy_id=?)''',
      [id],
    );
  });
}
