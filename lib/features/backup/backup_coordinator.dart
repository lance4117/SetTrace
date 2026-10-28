import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostic_observation.dart';
import '../../core/diagnostics/diagnostics_client.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'backup_codec.dart';
import 'backup_data_repository.dart';
import 'backup_files_platform.dart';
import 'backup_json.dart';
import 'backup_metadata_repository.dart';
import 'backup_models.dart';
import 'backup_recovery_store.dart';
import 'data_write_coordinator.dart';

abstract class BackupPreferences {
  Future<void> get settled;
  Future<BackupSettings> readConfirmed();
  Future<void> apply(String field, Object? value);
}

class BackupPreview {
  const BackupPreview({
    required this.id,
    required this.document,
    required this.current,
    required this.epoch,
    required this.restoreSettings,
    this.fileName = '',
    this.bytes = 0,
    this.token,
    this.copyId,
    this.undoOf,
  });
  final String id;
  final BackupDocument document;
  final BackupData current;
  final int epoch;
  final bool restoreSettings;
  final String fileName;
  final int bytes;
  final String? token, copyId, undoOf;
  BackupPreview withSettings(bool value) => BackupPreview(
    id: id,
    document: document,
    current: current,
    epoch: epoch,
    restoreSettings: value,
    fileName: fileName,
    bytes: bytes,
    token: token,
    copyId: copyId,
    undoOf: undoOf,
  );
}

class BackupOperationResult {
  const BackupOperationResult(
    this.operationId,
    this.document, {
    this.settingsPending = const [],
    this.refreshFailed = false,
  });
  final String operationId;
  final BackupDocument document;
  final List<String> settingsPending;
  final bool refreshFailed;
}

class BackupCoordinator extends ChangeNotifier {
  BackupCoordinator({
    required this.db,
    required this.writes,
    required this.preferences,
    required this.files,
    required this.appVersion,
    this.onCommitted,
    this.protectionCheckpoint,
    this.diagnostics,
  }) : metadata = BackupMetadataRepository(db),
       data = BackupDataRepository(db) {
    writes.settlers.add(_settle);
  }
  final DiagnosticsClient? diagnostics;
  DiagnosticsClient get _diagnostics =>
      diagnostics ?? DiagnosticsClient.instance;
  final Database db;
  final DataWriteCoordinator writes;
  final BackupPreferences preferences;
  final BackupFilesPlatform files;
  final FutureOr<String> Function() appVersion;
  final Future<void> Function()? onCommitted;
  final Future<void> Function(String)? protectionCheckpoint;
  final BackupMetadataRepository metadata;
  final BackupDataRepository data;
  late final BackupRecoveryStore copies = BackupRecoveryStore(
    files.recoveryDirectory,
    metadata,
    checkpoint: protectionCheckpoint,
  );
  String phase = 'idle';
  String? _candidateToken;
  int _selection = 0;
  bool _disposed = false;
  bool _exporting = false;
  BackupOperationResult? lastResult;
  Object? copyCheckError;
  Future<void> _settle() => preferences.settled;
  void _phase(String value) {
    phase = value;
    if (!_disposed) notifyListeners();
  }

  void _coreConfirmed(String id, int sourceEpoch, int targetEpoch) {
    final scope = DiagnosticScope.current;
    scope?.commit();
    scope?.operation.emit(
      DiagnosticPhase.core_committed,
      DiagnosticOutcome.committed,
      resultObjects: {DiagnosticObject.backup: id},
      fields: {
        DiagnosticField.source_epoch: sourceEpoch,
        DiagnosticField.target_epoch: targetEpoch,
      },
    );
  }

  void _pendingSettings(int count) {
    if (count == 0) return;
    final scope = DiagnosticScope.current;
    if (scope != null) {
      scope.followupFailed = true;
      scope.operation.emit(
        DiagnosticPhase.settings_pending,
        DiagnosticOutcome.partial_success,
        reason: DiagnosticReason.followup_failed,
        fields: {DiagnosticField.count: count},
      );
    }
  }

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<BackupDocument> _document(BackupData snapshot, {String? id}) async {
    final now = DateTime.now().toUtc();
    return BackupDocument(
      backupId: id ?? newId(),
      snapshotAt: now,
      exportedAt: now,
      sourceAppVersion: await appVersion(),
      data: snapshot,
    );
  }

  Future<BackupData> snapshot() => writes.exclusive(
    () async => data.snapshot(await preferences.readConfirmed()),
  );
  Future<BackupData> overview() => writes.exclusive(
    () async =>
        data.snapshot(await preferences.readConfirmed(), overview: true),
  );
  Future<BackupDocument> createExportSnapshot() async =>
      _document(await snapshot());

  Future<void> clearCandidate() async {
    _selection++;
    if (['selecting', 'validating'].contains(phase)) _phase('idle');
    final token = _candidateToken;
    _candidateToken = null;
    if (token != null) await files.discard(token);
  }

  Future<BackupPreview?> selectFile({bool restoreSettings = true}) async {
    await clearCandidate();
    final selection = _selection;
    _phase('selecting');
    final selected = await files.pick();
    if (selected == null) {
      if (selection != _selection) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      _phase('idle');
      return null;
    }
    try {
      if (selection != _selection) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      _phase('validating');
      final doc = await BackupCodec.readFile(files.pathFor(selected.token));
      if (selection != _selection) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      _candidateToken = selected.token;
      final preview = await _preview(
        doc,
        restoreSettings: restoreSettings,
        token: selected.token,
        fileName: selected.fileName,
        bytes: selected.bytes,
      );
      if (selection != _selection) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      _phase('preview');
      return preview;
    } catch (_) {
      await files.discard(selected.token);
      if (_candidateToken == selected.token) _candidateToken = null;
      if (selection == _selection) _phase('idle');
      rethrow;
    }
  }

  Future<BackupPreview> previewCopy(
    String id, {
    bool restoreSettings = true,
    String? undoOf,
  }) async {
    final doc = await copies.read(id);
    final row = (await metadata.copy(id))!;
    return _preview(
      doc,
      restoreSettings: restoreSettings,
      copyId: id,
      undoOf: undoOf,
      fileName: row['relative_path'] as String,
      bytes: row['byte_count'] as int,
    );
  }

  Future<BackupPreview> previewUndo() async {
    final id = (await metadata.state())['undo_operation_id'] as String?;
    final op = id == null ? null : await metadata.operation(id);
    if (op == null || op['undone_by'] != null || op['before_copy_id'] == null) {
      throw const BackupException(BackupFailure.missingCopy);
    }
    return previewCopy(
      op['before_copy_id'] as String,
      restoreSettings: op['restore_settings'] == 1,
      undoOf: id,
    );
  }

  Future<BackupPreview> _preview(
    BackupDocument doc, {
    required bool restoreSettings,
    String? token,
    String? copyId,
    String? undoOf,
    String fileName = '',
    int bytes = 0,
  }) => writes.exclusive(
    () async => BackupPreview(
      id: newId(),
      document: doc,
      current: await data.snapshot(await preferences.readConfirmed()),
      epoch: await metadata.epoch(),
      restoreSettings: restoreSettings,
      token: token,
      copyId: copyId,
      undoOf: undoOf,
      fileName: fileName,
      bytes: bytes,
    ),
  );

  Future<BackupOperationResult> restore(
    BackupPreview preview,
  ) => diagnosticObserve(
    _diagnostics,
    (preview.undoOf == null
        ? DiagnosticName.backupRestore
        : DiagnosticName.backupUndo),
    () => writes.exclusive(() async {
      _phase('checking');
      if (await metadata.operation(preview.id) != null) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      if (preview.token != null && preview.token != _candidateToken) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      final target = preview.copyId != null
          ? await copies.read(preview.copyId!)
          : await BackupCodec.readFile(files.pathFor(preview.token!));
      if (target.digest != preview.document.digest ||
          await metadata.epoch() != preview.epoch) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      final settings = await preferences.readConfirmed();
      final current = await data.snapshot(settings);
      final before = (await BackupFingerprints.compute(current));
      if (before.contentDigest !=
          (await BackupFingerprints.compute(preview.current)).contentDigest) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      if (preview.undoOf != null) {
        final original = await metadata.operation(preview.undoOf!);
        if (original == null ||
            original['undone_by'] != null ||
            original['before_copy_id'] != preview.copyId ||
            (original['restore_settings'] == 1) != preview.restoreSettings) {
          throw const BackupException(BackupFailure.stalePreview);
        }
      }
      await supersedeSettings();
      await metadata.begin(
        id: preview.id,
        kind: preview.undoOf == null ? 'restore' : 'undo',
        sourceDigest: before.contentDigest,
        targetDigest: (await BackupFingerprints.compute(target.data))
            .contentDigest,
        candidateDigest: target.digest,
        sourceEpoch: preview.epoch,
        restoreSettings: preview.restoreSettings,
        settingsTarget: target.data.settings,
        targetSummary: {
          'snapshotAt': target.snapshotAt.toUtc().toIso8601String(),
          'planCount': target.data.plans.length,
          'workoutCount': target.data.workouts.length,
        },
        undoOf: preview.undoOf,
      );
      var protected = false;
      try {
        _phase('protecting');
        final copy = await copies.protect(preview.id, await _document(current));
        await metadata.protect(preview.id, copy);
        _diagnostics.event(
          DiagnosticName.backupProtect,
          phase: DiagnosticPhase.protected,
          outcome: DiagnosticOutcome.committed,
          parent: DiagnosticScope.current?.operation.id,
          objects: {DiagnosticObject.backup: preview.id},
        );
        protected = true;
        _phase('restoring');
        final epoch = await data.replace(
          operationId: preview.id,
          expectedEpoch: preview.epoch,
          expectedCoreDigest: before.coreDigest,
          target: target.data,
          currentSettings: settings,
        );
        writes.committed(epoch);
        _coreConfirmed(preview.id, preview.epoch, epoch);
      } catch (_) {
        // A thrown commit acknowledgement is not proof of rollback.
        try {
          final op = await metadata.operation(preview.id);
          if (op?['phase'] == 'core_committed') {
            writes.committed(op!['target_epoch'] as int);
            _coreConfirmed(
              preview.id,
              preview.epoch,
              op['target_epoch'] as int,
            );
          } else {
            final actual = await data.snapshot(
              await preferences.readConfirmed(),
            );
            if ((await BackupFingerprints.compute(actual)).contentDigest !=
                before.contentDigest) {
              throw const BackupException(BackupFailure.indeterminate);
            }
            await metadata.updateOperation(preview.id, {
              'phase': 'aborted',
              'error_code': protected ? 'rolledBack' : 'protection',
            });
            _phase('idle');
            if (protected) DiagnosticScope.current?.rollbackConfirmed = true;
            throw BackupException(
              protected ? BackupFailure.rolledBack : BackupFailure.protection,
            );
          }
        } on BackupException catch (e) {
          if (e.code == BackupFailure.rolledBack ||
              e.code == BackupFailure.protection) {
            rethrow;
          }
          writes.restrict();
          _phase('indeterminate');
          throw const BackupException(BackupFailure.indeterminate);
        } catch (_) {
          writes.restrict();
          _phase('indeterminate');
          throw const BackupException(BackupFailure.indeterminate);
        }
      }
      _phase('settings');
      DiagnosticScope.current?.phase = DiagnosticPhase.settings_pending;
      List<String> pending = [];
      if (preview.restoreSettings) {
        try {
          pending = await _applySettings(preview.id);
        } catch (_) {
          pending = ['themeMode', 'themeColor', 'languageTag', 'reminder'];
        }
      } else {
        // Core success is already durable. A failed bookkeeping write must not
        // turn a successful replacement into a generic restore failure.
        try {
          await metadata.updateOperation(preview.id, {'phase': 'completed'});
        } catch (_) {
          // Startup resolves core_committed without replaying the transaction.
        }
      }
      var refreshFailed = false;
      _pendingSettings(pending.length);
      DiagnosticScope.current?.phase = DiagnosticPhase.refresh;
      try {
        await onCommitted?.call();
      } catch (error, stack) {
        refreshFailed = true;
        DiagnosticScope.current?.followupFailure(
          error,
          stack,
          at: DiagnosticPhase.refresh,
        );
      }
      lastResult = BackupOperationResult(
        preview.id,
        target,
        settingsPending: pending,
        refreshFailed: refreshFailed,
      );
      _phase(pending.isEmpty ? 'completed' : 'settings_pending');
      return lastResult!;
    }),
    inferCommitOnSuccess: false,
    objects: {DiagnosticObject.backup: preview.id},
    backupOperation: preview.id,
  );

  Future<List<String>> _applySettings(
    String id, {
    bool writesAllowed = true,
  }) async {
    final op = (await metadata.operation(id))!;
    if (op['restore_settings'] != 1) return [];
    final target = jsonDecode(op['settings_target'] as String) as BackupMap;
    final results = jsonDecode(op['settings_results'] as String) as BackupMap;
    await metadata.updateOperation(id, {'phase': 'settings_pending'});
    for (final field in [
      'themeMode',
      'themeColor',
      'languageTag',
      'reminder',
    ]) {
      if (['done', 'superseded', 'skipped'].contains(results[field])) continue;
      try {
        var actual = (await preferences.readConfirmed()).toJson()[field];
        if (canonicalJson(actual) != canonicalJson(target[field]) &&
            writesAllowed) {
          await preferences.apply(field, target[field]);
          actual = (await preferences.readConfirmed()).toJson()[field];
        }
        results[field] = canonicalJson(actual) == canonicalJson(target[field])
            ? 'done'
            : 'pending';
      } catch (_) {
        results[field] = 'pending';
      }
      await metadata.updateOperation(id, {
        'settings_results': jsonEncode(results),
      });
    }
    final pending = target.keys
        .where(
          (key) => !['done', 'superseded', 'skipped'].contains(results[key]),
        )
        .toList();
    await metadata.updateOperation(id, {
      'phase': pending.isEmpty ? 'completed' : 'settings_pending',
    });
    return pending;
  }

  Future<List<String>> retrySettings(String id) => diagnosticObserve(
    _diagnostics,
    DiagnosticName.backupSettings,
    () => writes.exclusive(() async {
      final op = await metadata.operation(id);
      if (op == null ||
          op['phase'] != 'settings_pending' ||
          op['target_epoch'] != await metadata.epoch()) {
        throw const BackupException(BackupFailure.stalePreview);
      }
      final pending = await _applySettings(id);
      DiagnosticScope.current?.commit();
      _pendingSettings(pending.length);
      _phase(pending.isEmpty ? 'completed' : 'settings_pending');
      return pending;
    }),
    inferCommitOnSuccess: false,
    objects: {DiagnosticObject.backup: id},
    backupOperation: id,
  );
  Future<void> skipSettings(String id) => writes.exclusive(() async {
    final op = await metadata.operation(id);
    if (op == null || op['phase'] != 'settings_pending') {
      throw const BackupException(BackupFailure.stalePreview);
    }
    final result = jsonDecode(op['settings_results'] as String) as BackupMap;
    for (final field in [
      'themeMode',
      'themeColor',
      'languageTag',
      'reminder',
    ]) {
      if (result[field] != 'done') result[field] = 'skipped';
    }
    await metadata.updateOperation(id, {
      'settings_results': jsonEncode(result),
      'phase': 'settings_skipped',
    });
    _phase('completed');
  });

  /// Called inside admission BEFORE any later manual preference write.
  Future<void> supersedeSettings([String? field]) => db.transaction((
    txn,
  ) async {
    final rows = await txn.query(
      'backup_operations',
      where: "phase IN ('core_committed','settings_pending')",
    );
    for (final row in rows) {
      final result = jsonDecode(row['settings_results'] as String) as BackupMap;
      for (final key
          in field == null
              ? ['themeMode', 'themeColor', 'languageTag', 'reminder']
              : [field]) {
        if (result[key] != 'done') result[key] = 'superseded';
      }
      await metadata.updateOperation(row['id'] as String, {
        'settings_results': jsonEncode(result),
        if (['themeMode', 'themeColor', 'languageTag', 'reminder'].every(
          (key) => ['done', 'superseded', 'skipped'].contains(result[key]),
        ))
          'phase': 'settings_skipped',
      }, txn);
    }
  });

  Future<BackupMap> export(
    BackupDocument document, {
    required bool currentData,
  }) async {
    return diagnosticObserve(_diagnostics, DiagnosticName.backupExport, () async {
      if (_exporting) throw const BackupException(BackupFailure.busy);
      _exporting = true;
      final id = newId();
      String? token;
      final exportTime = DateTime.now().toUtc();
      final output = BackupDocument(
        backupId: document.backupId,
        snapshotAt: document.snapshotAt,
        exportedAt: exportTime,
        sourceAppVersion: document.sourceAppVersion,
        data: document.data,
        extensions: document.extensions,
      );
      _phase('exporting');
      try {
        final digest = (await BackupFingerprints.compute(document.data))
            .contentDigest;
        // Resolve an earlier reservation before another public file is created.
        // A retry after a lost publish acknowledgement completes that request.
        for (final operation in await metadata.operations()) {
          if (operation['kind'] != 'export' ||
              ['completed', 'aborted'].contains(operation['phase'])) {
            continue;
          }
          final receipt = await reconcileExport(operation['id'] as String);
          if (receipt['state'] == 'published') {
            final flags = jsonDecode(
              operation['settings_results'] as String,
            ) as BackupMap;
            if (operation['source_digest'] == digest &&
                flags['currentData'] == currentData) {
              DiagnosticScope.current?.commit();
              _phase('completed');
              return {
                ...receipt,
                'operationId': operation['id'],
                'ledgerPending': false,
              };
            }
          } else if (receipt['state'] != 'cleaned') {
            throw const BackupException(BackupFailure.storage);
          }
        }
        token = await files.allocate();
        await BackupCodec.writeFile(files.pathFor(token), output);
        await metadata.begin(
          id: id,
          kind: 'export',
          sourceDigest: digest,
          targetDigest: digest,
          sourceEpoch: await metadata.epoch(),
          restoreSettings: false,
          now: exportTime.millisecondsSinceEpoch,
        );
        // The flag is durable BEFORE reserve/publish, including copy exports.
        await metadata.updateOperation(id, {
          'settings_results': jsonEncode({'currentData': currentData}),
        });
        final reserved = await files.reserve(id, token);
        await metadata.updateOperation(id, {
          'export_target': jsonEncode(reserved),
        });
        final result = await files.publish(id);
        if (result['state'] != 'published') {
          throw const BackupException(BackupFailure.storage);
        }
        DiagnosticScope.current?.commit();
        DiagnosticScope.current?.phase = DiagnosticPhase.refresh;
        try {
          await metadata.recordExport(
            id,
            result: result,
            exportedAt: exportTime.millisecondsSinceEpoch,
            currentData: currentData,
          );
        } catch (error, stack) {
          DiagnosticScope.current?.followupFailure(error, stack);
          _phase('export_published');
          return {...result, 'operationId': id, 'ledgerPending': true};
        }
        _phase('completed');
        return {...result, 'operationId': id, 'ledgerPending': false};
      } finally {
        _exporting = false;
        // Journaled public results remain independently reconcilable.
        try {
          if (token != null) await files.discard(token);
        } catch (_) {
          /* cache cleanup can retry */
        }
      }
    }, inferCommitOnSuccess: false);
  }

  Future<BackupMap> reconcileExport(String id) async {
    final op = await metadata.operation(id);
    if (op == null || op['kind'] != 'export') invalidBackup();
    final result = await files.inspect(id);
    if (result['state'] == 'published') {
      final flags = jsonDecode(op['settings_results'] as String) as BackupMap;
      await metadata.recordExport(
        id,
        result: result,
        exportedAt: op['created_at'] as int,
        currentData: flags['currentData'] == true,
      );
    } else if (result['state'] == 'cleaned') {
      await metadata.updateOperation(id, {'phase': 'aborted'});
    }
    return result;
  }

  Future<void> reconcileStartup() => diagnosticObserve(
    _diagnostics,
    DiagnosticName.backupRecovery,
    () => writes.exclusive(() async {
      _phase('checking');
      try {
        await files.initialize();
        try {
          await copies.reconcile();
          copyCheckError = null;
        } catch (error, stack) {
          DiagnosticScope.current?.followupFailure(
            error,
            stack,
            at: DiagnosticPhase.inspecting,
          );
          // A failed copy deletion/index repair is not uncertainty about the
          // core transaction. Retain it for an explicit copy-management retry.
          copyCheckError = error;
        }
        final epoch = await metadata.epoch();
        if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
          invalidBackup();
        }
        for (final op in await metadata.operations()) {
          final id = op['id'] as String;
          if (op['kind'] == 'export') {
            if (!['completed', 'aborted'].contains(op['phase'])) {
              try {
                await reconcileExport(id);
              } catch (error, stack) {
                DiagnosticScope.current?.followupFailure(
                  error,
                  stack,
                  at: DiagnosticPhase.inspecting,
                );
                /* pending verification remains visible */
              }
            }
            continue;
          }
          if ([
            'preparing',
            'protected',
            'indeterminate',
          ].contains(op['phase'])) {
            final snapshot = await data.snapshot(
              await preferences.readConfirmed(),
            );
            if (op['source_epoch'] != epoch ||
                (await BackupFingerprints.compute(snapshot)).contentDigest !=
                    op['source_digest']) {
              throw const BackupException(BackupFailure.indeterminate);
            }
            await metadata.updateOperation(id, {'phase': 'aborted'});
          } else if ([
            'core_committed',
            'settings_pending',
          ].contains(op['phase'])) {
            if (op['target_epoch'] == epoch) {
              if (op['restore_settings'] == 1) {
                await _applySettings(id, writesAllowed: false);
              } else {
                await metadata.updateOperation(id, {'phase': 'completed'});
              }
            }
            // Later legitimate workouts are allowed. Never compare current rows
            // to the snapshot at the old operation's commit, or replay replacement.
          }
        }
        writes.reconcile(epoch);
        _phase('idle');
      } catch (_) {
        writes.restrict();
        _phase('indeterminate');
        rethrow;
      }
    }, reconciliation: true),
    inferCommitOnSuccess: false,
    recordSuccess: true,
  );

  @override
  void dispose() {
    _disposed = true;
    writes.settlers.remove(_settle);
    super.dispose();
  }
}
