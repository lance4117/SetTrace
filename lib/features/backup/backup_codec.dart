import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'backup_json.dart';
import 'backup_models.dart';

const backupFormat = 'settrace.user-backup';
typedef BackupVersionValidator = void Function(BackupMap document);
typedef BackupMigration = BackupMap Function(BackupMap document);

class BackupDocument {
  BackupDocument({
    required this.backupId,
    required this.snapshotAt,
    required this.exportedAt,
    required this.sourceAppVersion,
    required this.data,
    BackupMap extensions = const {},
    this.digest = '',
  }) : extensions = freeze(extensions) as BackupMap;
  final String backupId, sourceAppVersion, digest;
  final DateTime snapshotAt, exportedAt;
  final BackupData data;
  final BackupMap extensions;

  BackupMap unsignedJson() => {
    'format': backupFormat,
    'schemaVersion': 1,
    'backupId': backupId,
    'snapshotAt': snapshotAt.toUtc().toIso8601String(),
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'sourceAppVersion': sourceAppVersion,
    'data': data.toJson(),
    'metadata': {'extensions': extensions},
  };
}

/// Each published reader validates its ORIGINAL structure before conversion.
/// Migrations receive a private mutable copy, never the caller's document.
class BackupVersionRegistry {
  BackupVersionRegistry({
    this.currentVersion = 1,
    Map<int, BackupVersionValidator>? validators,
    this.migrations = const {},
  }) : validators = validators ?? {1: validateBackupV1};
  final int currentVersion;
  final Map<int, BackupVersionValidator> validators;
  final Map<int, BackupMigration> migrations;

  BackupMap upgrade(BackupMap original) {
    var version = integer(original['schemaVersion'], min: 1);
    if (version > currentVersion || !validators.containsKey(version)) {
      throw const BackupException(BackupFailure.unsupportedVersion);
    }
    var document = version == currentVersion
        ? original
        : jsonDecode(jsonEncode(original)) as BackupMap;
    while (true) {
      final validator = validators[version];
      if (validator == null) {
        throw const BackupException(BackupFailure.unsupportedVersion);
      }
      validator(document);
      if (version == currentVersion) return document;
      final migrate = migrations[version];
      if (migrate == null) {
        throw const BackupException(BackupFailure.unsupportedVersion);
      }
      document = migrate(document);
      version++;
      if (document['schemaVersion'] != version) invalidBackup();
    }
  }
}

class BackupCodec {
  BackupCodec({BackupVersionRegistry? registry})
    : registry = registry ?? BackupVersionRegistry();
  final BackupVersionRegistry registry;

  Uint8List encode(BackupDocument document) {
    final unsigned = document.unsignedJson();
    validateBackupV1(unsigned);
    final result = <String, Object?>{
      ...unsigned,
      'integrity': {'algorithm': 'sha256', 'digest': backupDigest(unsigned)},
    };
    final bytes = Uint8List.fromList(utf8.encode(canonicalJson(result)));
    if (bytes.length > backupMaxBytes) {
      throw const BackupException(BackupFailure.tooLarge);
    }
    // The reader uses this same validator. Avoid allocating a second full tree
    // just to revalidate an export whose domain and JSON have already passed.
    return bytes;
  }

  BackupDocument decode(List<int> bytes) {
    if (bytes.length > backupMaxBytes) {
      throw const BackupException(BackupFailure.tooLarge);
    }
    late Object? parsed;
    try {
      parsed = BackupJsonReader(utf8.decode(bytes, allowMalformed: false))
          .read();
    } on FormatException {
      throw const BackupException(BackupFailure.damaged);
    }
    if (parsed is! BackupMap) invalidBackup();
    if (parsed['format'] == 'settrace.training-plans') {
      throw const BackupException(BackupFailure.planFile);
    }
    if (parsed['format'] != backupFormat) {
      throw const BackupException(BackupFailure.wrongFormat);
    }
    final version = integer(parsed['schemaVersion'], min: 1);
    if (version > registry.currentVersion) {
      throw const BackupException(BackupFailure.unsupportedVersion);
    }
    final integrity = object(parsed['integrity'], const [
      'algorithm',
      'digest',
    ]);
    if (integrity['algorithm'] != 'sha256' ||
        integrity['digest'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(integrity['digest'] as String)) {
      throw const BackupException(BackupFailure.integrity);
    }
    final unsigned = <String, Object?>{...parsed}..remove('integrity');
    final digest = backupDigest(unsigned);
    if (digest != integrity['digest']) {
      throw const BackupException(BackupFailure.integrity);
    }
    final document = registry.upgrade(unsigned);
    return BackupDocument(
      backupId: document['backupId'] as String,
      snapshotAt: DateTime.parse(document['snapshotAt'] as String),
      exportedAt: DateTime.parse(document['exportedAt'] as String),
      sourceAppVersion: document['sourceAppVersion'] as String,
      data: BackupData.fromJson(document['data']),
      extensions:
          (document['metadata'] as BackupMap)['extensions'] as BackupMap,
      digest: digest,
    );
  }

  static Future<BackupDocument> readFile(String trustedPath) =>
      Isolate.run(() async {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in File(trustedPath).openRead()) {
          if (builder.length + chunk.length > backupMaxBytes) {
            throw const BackupException(BackupFailure.tooLarge);
          }
          builder.add(chunk);
        }
        return BackupCodec().decode(builder.takeBytes());
      });

  static Future<void> writeFile(String trustedPath, BackupDocument document) =>
      Isolate.run(() async {
        final bytes = BackupCodec().encode(document);
        final handle = await File(trustedPath).open(mode: FileMode.write);
        try {
          await handle.writeFrom(bytes);
          await handle.flush();
        } finally {
          await handle.close();
        }
      });
}

void validateBackupV1(BackupMap document) {
  object(document, const [
    'format',
    'schemaVersion',
    'backupId',
    'snapshotAt',
    'exportedAt',
    'sourceAppVersion',
    'data',
    'metadata',
  ]);
  if (document['format'] != backupFormat || document['schemaVersion'] != 1) {
    invalidBackup();
  }
  string(document['backupId']);
  string(document['sourceAppVersion']);
  for (final k in ['snapshotAt', 'exportedAt']) {
    final value = string(document[k]);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$')
        .hasMatch(value)) {
      invalidBackup();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        parsed.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
      invalidBackup();
    }
  }
  final metadata = object(document['metadata'], const ['extensions']);
  if (metadata['extensions'] is! BackupMap) invalidBackup();
  // Also checks unsafe numbers/Unicode in arbitrary extension metadata on export.
  validateJsonTree(document);
  BackupData.validate(document['data']);
}

String backupDigest(Object? value) {
  final result = _DigestSink();
  final bytes = sha256.startChunkedConversion(result);
  final text = const Utf8Encoder().startChunkedConversion(bytes);
  writeCanonicalJson(value, text.add);
  text.close();
  return result.value!.toString();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class BackupFingerprints {
  static final _cache = Expando<Future<BackupFingerprints>>();

  /// Immutable snapshots can reuse their digest without doing normalization
  /// during widget builds or blocking the UI isolate.
  static Future<BackupFingerprints> compute(BackupData data) =>
      _cache[data] ??= Isolate.run(() => BackupFingerprints(data));

  BackupFingerprints(BackupData data) {
    // Renumber all document-local references in traversal order. Reallocated
    // SQLite IDs must not make equivalent restored data appear different.
    final normalized = jsonDecode(jsonEncode(data.toJson())) as BackupMap;
    final plans = (normalized['plans'] as List).cast<BackupMap>();
    final workouts = (normalized['workouts'] as List).cast<BackupMap>();
    final planKeys = <Object?, String>{};
    final exerciseKeys = <Object?, String>{};
    for (var i = 0; i < plans.length; i++) {
      final p = plans[i];
      planKeys[p['key']] = 'p$i';
      p['key'] = 'p$i';
      final exercises = (p['exercises'] as List).cast<BackupMap>();
      for (var j = 0; j < exercises.length; j++) {
        final e = exercises[j];
        exerciseKeys[e['key']] = 'p$i/e$j';
        e['key'] = 'p$i/e$j';
      }
    }
    for (var i = 0; i < workouts.length; i++) {
      final w = workouts[i];
      w['key'] = 'w$i';
      w['sourcePlanKey'] = planKeys[w['sourcePlanKey']];
      final exercises = (w['exercises'] as List).cast<BackupMap>();
      for (var j = 0; j < exercises.length; j++) {
        final e = exercises[j];
        e['key'] = 'w$i/e$j';
        e['sourceExerciseKey'] = exerciseKeys[e['sourceExerciseKey']];
        final batches = (e['skipBatches'] as List).cast<BackupMap>();
        final keys = <Object?, String>{};
        for (var k = 0; k < batches.length; k++) {
          final b = batches[k];
          keys[b['key']] = 'w$i/e$j/b$k';
          b['key'] = 'w$i/e$j/b$k';
        }
        for (final s in (e['sets'] as List).cast<BackupMap>()) {
          s['skipBatchKey'] = keys[s['skipBatchKey']];
        }
      }
    }
    coreDigest = backupDigest({'plans': plans, 'workouts': workouts});
    settingsDigest = backupDigest(data.settings.toJson());
    contentDigest = backupDigest({
      'core': coreDigest,
      'settings': settingsDigest,
    });
  }
  late final String coreDigest, settingsDigest, contentDigest;
}
