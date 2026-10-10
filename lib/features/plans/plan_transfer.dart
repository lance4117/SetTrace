import 'dart:convert';

import 'package:characters/characters.dart';

import 'plan_models.dart';

enum PlanTransferFailure {
  fileTooLarge,
  emptyContent,
  damagedContent,
  wrongFormat,
  unsupportedVersion,
  noImportPlans,
  selectPlans,
  invalidObject,
  invalidName,
  invalidInteger,
  invalidRest,
  invalidWeight,
  invalidExercises,
  clipboardCopyFailed,
  clipboardReadFailed,
  clipboardEmpty,
  fileBusy,
  fileIncomplete,
  fileOperationFailed,
  fileUnsupported,
  fileNotDownloads,
  fileReadFailed,
  fileEmpty,
  filePickerFailed,
  permissionDenied,
  fileSaveFailed,
  plansChanged,
}

enum PlanTransferField { name, exercises, sets, betweenRest, afterRest, weight }

class PlanTransferLocation {
  const PlanTransferLocation({this.plan = 0, this.exercise = 0, this.field});
  final int plan, exercise;
  final PlanTransferField? field;
  PlanTransferLocation withField(PlanTransferField value) =>
      PlanTransferLocation(plan: plan, exercise: exercise, field: value);
}

class PlanTransferException implements Exception {
  const PlanTransferException(
    this.code, {
    this.location = const PlanTransferLocation(),
    this.min = 0,
    this.max = 0,
  });
  final PlanTransferFailure code;
  final PlanTransferLocation location;
  final int min, max;
  @override
  String toString() => 'PlanTransferException(${code.name})';
}

class TransferExercise {
  const TransferExercise({
    required this.name,
    required this.targetSets,
    required this.restBetweenSetsSeconds,
    required this.restAfterExerciseSeconds,
    this.defaultWeightKg,
  });
  final String name;
  final int targetSets, restBetweenSetsSeconds, restAfterExerciseSeconds;
  final double? defaultWeightKg;
  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'targetSets': targetSets,
    'restBetweenSetsSeconds': restBetweenSetsSeconds,
    'restAfterExerciseSeconds': restAfterExerciseSeconds,
    'defaultWeightKg': defaultWeightKg,
  };
}

class TransferPlan {
  TransferPlan({required this.name, required List<TransferExercise> exercises})
    : exercises = List.unmodifiable(exercises);
  final String name;
  final List<TransferExercise> exercises;
  int get totalSets => exercises.fold(0, (sum, e) => sum + e.targetSets);
  TransferPlan withName(String value) =>
      TransferPlan(name: value.trim(), exercises: exercises);
  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
  factory TransferPlan.fromPlan(WorkoutPlan plan) => TransferPlan(
    name: plan.name.trim(),
    exercises: plan.exercises
        .map(
          (e) => TransferExercise(
            name: e.name.trim(),
            targetSets: e.targetSets,
            restBetweenSetsSeconds: e.restBetweenSetsSeconds,
            restAfterExerciseSeconds: e.restAfterExerciseSeconds,
            defaultWeightKg: e.defaultWeightKg,
          ),
        )
        .toList(),
  );
}

class PlanTransferDocument {
  PlanTransferDocument(List<TransferPlan> plans, {this.exportedAt})
    : plans = List.unmodifiable(plans);
  final List<TransferPlan> plans;
  final DateTime? exportedAt;
}

class PlanTransferCodec {
  const PlanTransferCodec();
  static const maxBytes = 2 * 1024 * 1024;
  static const format = 'settrace.training-plans';
  static void checkSize(String text) {
    if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
      throw const PlanTransferException(PlanTransferFailure.fileTooLarge);
    }
  }

  String encode(PlanTransferDocument document) {
    validatePlans(document.plans);
    final text = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'schemaVersion': 1,
      if (document.exportedAt != null)
        'exportedAt': document.exportedAt!.toUtc().toIso8601String(),
      'plans': document.plans.map((p) => p.toJson()).toList(),
    });
    checkSize(text);
    return text;
  }

  PlanTransferDocument decode(String text) {
    checkSize(text);
    var cleaned = text.trim();
    if (cleaned.startsWith('\uFEFF')) cleaned = cleaned.substring(1).trim();
    if (cleaned.isEmpty) {
      throw const PlanTransferException(PlanTransferFailure.emptyContent);
    }
    Object? json;
    try {
      json = jsonDecode(cleaned);
    } on FormatException {
      throw const PlanTransferException(PlanTransferFailure.damagedContent);
    }
    final root = _object(json, const PlanTransferLocation());
    if (root['format'] != format) {
      throw const PlanTransferException(PlanTransferFailure.wrongFormat);
    }
    if (root['schemaVersion'] is! int || root['schemaVersion'] != 1) {
      throw const PlanTransferException(PlanTransferFailure.unsupportedVersion);
    }
    final values = root['plans'];
    if (values is! List || values.isEmpty) {
      throw const PlanTransferException(PlanTransferFailure.noImportPlans);
    }
    final plans = <TransferPlan>[];
    for (var i = 0; i < values.length; i++) {
      plans.add(_plan(values[i], PlanTransferLocation(plan: i + 1)));
    }
    final stamp = root['exportedAt'];
    return PlanTransferDocument(
      plans,
      exportedAt: stamp is String ? DateTime.tryParse(stamp) : null,
    );
  }

  void validatePlans(List<TransferPlan> plans) {
    if (plans.isEmpty) {
      throw const PlanTransferException(PlanTransferFailure.selectPlans);
    }
    for (var i = 0; i < plans.length; i++) {
      _plan(plans[i].toJson(), PlanTransferLocation(plan: i + 1));
    }
  }

  TransferPlan _plan(Object? value, PlanTransferLocation path) {
    final json = _object(value, path);
    final name = _name(
      json['name'],
      40,
      path.withField(PlanTransferField.name),
    );
    final list = json['exercises'];
    if (list is! List) {
      throw PlanTransferException(
        PlanTransferFailure.invalidExercises,
        location: path,
      );
    }
    final exercises = <TransferExercise>[];
    for (var i = 0; i < list.length; i++) {
      final location = PlanTransferLocation(plan: path.plan, exercise: i + 1);
      final item = _object(list[i], location);
      final exerciseName = _name(
        item['name'],
        60,
        location.withField(PlanTransferField.name),
      );
      final sets = _integer(
        item['targetSets'],
        1,
        100,
        location.withField(PlanTransferField.sets),
      );
      final between = _rest(
        item['restBetweenSetsSeconds'],
        location.withField(PlanTransferField.betweenRest),
      );
      final after = _rest(
        item['restAfterExerciseSeconds'],
        location.withField(PlanTransferField.afterRest),
      );
      final weight = item['defaultWeightKg'];
      if (weight != null &&
          (weight is! num || !weight.isFinite || weight <= 0)) {
        throw PlanTransferException(
          PlanTransferFailure.invalidWeight,
          location: location.withField(PlanTransferField.weight),
        );
      }
      exercises.add(
        TransferExercise(
          name: exerciseName,
          targetSets: sets,
          restBetweenSetsSeconds: between,
          restAfterExerciseSeconds: after,
          defaultWeightKg: (weight as num?)?.toDouble(),
        ),
      );
    }
    return TransferPlan(name: name, exercises: exercises);
  }

  Map<String, dynamic> _object(Object? value, PlanTransferLocation path) {
    if (value is! Map<String, dynamic>) {
      throw PlanTransferException(
        PlanTransferFailure.invalidObject,
        location: path,
      );
    }
    return value;
  }

  String _name(Object? value, int max, PlanTransferLocation path) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.trim().characters.length > max) {
      throw PlanTransferException(
        PlanTransferFailure.invalidName,
        location: path,
        min: 1,
        max: max,
      );
    }
    return value.trim();
  }

  int _integer(Object? value, int min, int max, PlanTransferLocation path) {
    if (value is! int || value < min || value > max) {
      throw PlanTransferException(
        PlanTransferFailure.invalidInteger,
        location: path,
        min: min,
        max: max,
      );
    }
    return value;
  }

  int _rest(Object? value, PlanTransferLocation path) {
    final seconds = _integer(value, 0, 3600, path);
    if (seconds % 30 != 0) {
      throw PlanTransferException(
        PlanTransferFailure.invalidRest,
        location: path,
      );
    }
    return seconds;
  }
}

typedef ImportSuffix = String Function(int number);

List<TransferPlan> resolveImportNames(
  List<TransferPlan> plans,
  Iterable<String> existing, {
  required ImportSuffix suffixFor,
}) {
  const PlanTransferCodec().validatePlans(plans);
  final used = existing.map((name) => name.trim()).toSet();
  return plans.map((plan) {
    final original = plan.name.trim();
    var name = original;
    var suffixNumber = 1;
    while (used.contains(name)) {
      final suffix = suffixFor(suffixNumber++);
      if (suffix.trim().isEmpty || suffix.characters.length >= 40) {
        throw StateError('invalidImportSuffix');
      }
      name =
          original.characters.take(40 - suffix.characters.length).toString() +
          suffix;
    }
    used.add(name);
    return plan.withName(name);
  }).toList();
}

class ImportNameConflict implements Exception {
  ImportNameConflict(this.plans);
  final List<TransferPlan> plans;
}
