import 'dart:convert';

import 'package:characters/characters.dart';

import 'plan_models.dart';

class PlanTransferException implements Exception {
  const PlanTransferException(this.message);
  final String message;
  @override
  String toString() => message;
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
      throw const PlanTransferException('计划内容超过 2 MiB，请减少计划数量后重试');
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
    if (cleaned.isEmpty) throw const PlanTransferException('没有计划内容，请粘贴文本或选择文件');
    Object? json;
    try {
      json = jsonDecode(cleaned);
    } on FormatException {
      throw const PlanTransferException('计划内容损坏，请使用完整的计划导出文本或文件');
    }
    final root = _object(json, '计划内容');
    if (root['format'] != format) {
      throw const PlanTransferException('无法识别此文件，请选择训练本导出的计划');
    }
    if (root['schemaVersion'] is! int || root['schemaVersion'] != 1) {
      throw const PlanTransferException('计划格式版本不受支持，请更新应用后重试');
    }
    final values = root['plans'];
    if (values is! List || values.isEmpty) {
      throw const PlanTransferException('没有可导入的计划');
    }
    final plans = <TransferPlan>[];
    for (var i = 0; i < values.length; i++) {
      plans.add(_plan(values[i], '第 ${i + 1} 个计划'));
    }
    final stamp = root['exportedAt'];
    return PlanTransferDocument(
      plans,
      exportedAt: stamp is String ? DateTime.tryParse(stamp) : null,
    );
  }

  void validatePlans(List<TransferPlan> plans) {
    if (plans.isEmpty) throw const PlanTransferException('请至少选择一个计划');
    for (var i = 0; i < plans.length; i++) {
      _plan(plans[i].toJson(), '第 ${i + 1} 个计划');
    }
  }

  TransferPlan _plan(Object? value, String path) {
    final json = _object(value, path);
    final name = _name(json['name'], 40, '$path 的名称');
    final list = json['exercises'];
    if (list is! List) throw PlanTransferException('「$name」缺少有效的动作列表');
    final exercises = <TransferExercise>[];
    for (var i = 0; i < list.length; i++) {
      final location = '「$name」第 ${i + 1} 个动作';
      final item = _object(list[i], location);
      final exerciseName = _name(item['name'], 60, '$location 名称');
      final sets = _integer(item['targetSets'], 1, 100, '$location 组数');
      final between = _rest(item['restBetweenSetsSeconds'], '$location 组间休息');
      final after = _rest(item['restAfterExerciseSeconds'], '$location 动作后休息');
      final weight = item['defaultWeightKg'];
      if (weight != null && (weight is! num || !weight.isFinite || weight <= 0)) {
        throw PlanTransferException('$location 重量必须为空或有效的正数');
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

  Map<String, dynamic> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      throw PlanTransferException('$path 必须是有效的对象');
    }
    return value;
  }

  String _name(Object? value, int max, String path) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.trim().characters.length > max) {
      throw PlanTransferException('$path 必须为 1–$max 个字符');
    }
    return value.trim();
  }

  int _integer(Object? value, int min, int max, String path) {
    if (value is! int || value < min || value > max) {
      throw PlanTransferException('$path 必须为 $min–$max 的整数');
    }
    return value;
  }

  int _rest(Object? value, String path) {
    final seconds = _integer(value, 0, 3600, path);
    if (seconds % 30 != 0) throw PlanTransferException('$path 必须为 30 秒的倍数');
    return seconds;
  }
}

List<TransferPlan> resolveImportNames(
  List<TransferPlan> plans,
  Iterable<String> existing,
) {
  const PlanTransferCodec().validatePlans(plans);
  final used = existing.map((name) => name.trim()).toSet();
  return plans.map((plan) {
    final original = plan.name.trim();
    var name = original;
    var suffixNumber = 1;
    while (used.contains(name)) {
      final suffix = suffixNumber == 1 ? '（导入）' : '（导入$suffixNumber）';
      name =
          original.characters.take(40 - suffix.characters.length).toString() +
          suffix;
      suffixNumber++;
    }
    used.add(name);
    return plan.withName(name);
  }).toList();
}

class ImportNameConflict implements Exception {
  ImportNameConflict(this.plans);
  final List<TransferPlan> plans;
}
