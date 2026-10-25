import 'dart:convert';

import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostic_observation.dart';

const backupMaxBytes = 64 * 1024 * 1024;
const backupMaxDepth = 32;
const backupMaxInteger = 9007199254740991;

enum BackupFailure {
  tooLarge,
  damaged,
  wrongFormat,
  planFile,
  unsupportedVersion,
  invalidData,
  integrity,
  activeWorkout,
  busy,
  stalePreview,
  storage,
  readFailed,
  deleteFailed,
  protection,
  rolledBack,
  indeterminate,
  missingCopy,
}

class BackupException implements Exception, DiagnosticClassifiedFailure {
  const BackupException(this.code);
  final BackupFailure code;
  @override
  DiagnosticReason get diagnosticReason => switch (code) {
    BackupFailure.tooLarge => DiagnosticReason.size_limit,
    BackupFailure.unsupportedVersion => DiagnosticReason.unsupported_version,
    BackupFailure.activeWorkout => DiagnosticReason.active_session,
    BackupFailure.busy => DiagnosticReason.busy,
    BackupFailure.stalePreview => DiagnosticReason.stale_position,
    BackupFailure.readFailed ||
    BackupFailure.missingCopy => DiagnosticReason.read_failed,
    BackupFailure.storage ||
    BackupFailure.deleteFailed ||
    BackupFailure.protection => DiagnosticReason.storage_unavailable,
    BackupFailure.indeterminate => DiagnosticReason.unknown,
    _ => DiagnosticReason.invalid_format,
  };
  @override
  bool get diagnosticRejection => !{
    BackupFailure.storage,
    BackupFailure.readFailed,
    BackupFailure.deleteFailed,
    BackupFailure.protection,
    BackupFailure.rolledBack,
    BackupFailure.indeterminate,
    BackupFailure.missingCopy,
  }.contains(code);
  @override
  String toString() => 'BackupException(${code.name})';
}

Never invalidBackup() => throw const BackupException(BackupFailure.invalidData);

/// Reject duplicate members before constructing a map, and bound recursion
/// before descending. dart:convert alone would silently retain the last key.
class BackupJsonReader {
  BackupJsonReader(this.source);
  final String source;
  int _offset = 0;

  Object? read() {
    final value = _value(0);
    _space();
    if (_offset != source.length) invalidBackup();
    return value;
  }

  void _space() {
    while (_offset < source.length &&
        const [0x20, 0x09, 0x0a, 0x0d].contains(source.codeUnitAt(_offset))) {
      _offset++;
    }
  }

  bool _take(String token) {
    if (!source.startsWith(token, _offset)) return false;
    _offset += token.length;
    return true;
  }

  Object? _value(int depth) {
    _space();
    if (_offset >= source.length) invalidBackup();
    final char = source[_offset];
    if (char == '{' || char == '[') {
      if (depth >= backupMaxDepth) invalidBackup();
      _offset++;
      _space();
      if (char == '{') {
        final result = <String, Object?>{};
        if (_take('}')) return result;
        while (true) {
          _space();
          final key = _string();
          if (result.containsKey(key)) invalidBackup();
          _space();
          if (!_take(':')) invalidBackup();
          result[key] = _value(depth + 1);
          _space();
          if (_take('}')) return result;
          if (!_take(',')) invalidBackup();
        }
      }
      final result = <Object?>[];
      if (_take(']')) return result;
      while (true) {
        result.add(_value(depth + 1));
        _space();
        if (_take(']')) return result;
        if (!_take(',')) invalidBackup();
      }
    }
    if (char == '"') return _string();
    if (_take('true')) return true;
    if (_take('false')) return false;
    if (_take('null')) return null;
    final match = _number.matchAsPrefix(source, _offset);
    if (match == null) invalidBackup();
    _offset = match.end;
    final value = num.tryParse(match[0]!);
    if (value == null ||
        !value.isFinite ||
        (value == value.truncateToDouble() && value.abs() > backupMaxInteger)) {
      invalidBackup();
    }
    return value;
  }

  static final _number = RegExp(
    r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
  );

  String _string() {
    if (!_take('"')) invalidBackup();
    final start = _offset - 1;
    while (_offset < source.length) {
      final code = source.codeUnitAt(_offset++);
      if (code == 0x5c) {
        if (_offset == source.length) invalidBackup();
        _offset++;
      } else if (code == 0x22) {
        try {
          final value = jsonDecode(source.substring(start, _offset)) as String;
          validateUnicode(value);
          return value;
        } on FormatException {
          invalidBackup();
        }
      } else if (code < 0x20) {
        invalidBackup();
      }
    }
    invalidBackup();
  }
}

void validateUnicode(String value) {
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code >= 0xd800 && code <= 0xdbff) {
      if (++i >= value.length) invalidBackup();
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) invalidBackup();
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      invalidBackup();
    }
  }
}

/// RFC 8785: UTF-16 member order, no whitespace, ECMAScript number spelling.
/// Business/schema validation additionally restricts integers to the safe range.
String canonicalJson(Object? value) {
  final output = StringBuffer();
  writeCanonicalJson(value, output.write);
  return output.toString();
}

void writeCanonicalJson(Object? value, void Function(String) output) {
  void write(Object? item, int depth) {
    if (item is Map<String, Object?>) {
      if (depth >= backupMaxDepth) invalidBackup();
      final keys = item.keys.toList()..sort();
      output('{');
      for (var i = 0; i < keys.length; i++) {
        if (i != 0) output(',');
        validateUnicode(keys[i]);
        output(jsonEncode(keys[i]));
        output(':');
        write(item[keys[i]], depth + 1);
      }
      output('}');
    } else if (item is List) {
      if (depth >= backupMaxDepth) invalidBackup();
      output('[');
      for (var i = 0; i < item.length; i++) {
        if (i != 0) output(',');
        write(item[i], depth + 1);
      }
      output(']');
    } else if (item is String) {
      validateUnicode(item);
      output(jsonEncode(item));
    } else if (item is num) {
      output(_canonicalNumber(item));
    } else if (item == null || item is bool) {
      output('$item');
    } else {
      invalidBackup();
    }
  }

  write(value, 0);
}

void validateJsonTree(Object? value, [int depth = 0]) {
  if (value is Map<String, Object?>) {
    if (depth >= backupMaxDepth) invalidBackup();
    for (final entry in value.entries) {
      validateUnicode(entry.key);
      validateJsonTree(entry.value, depth + 1);
    }
  } else if (value is List) {
    if (depth >= backupMaxDepth) invalidBackup();
    for (final item in value) {
      validateJsonTree(item, depth + 1);
    }
  } else if (value is String) {
    validateUnicode(value);
  } else if (value is num) {
    if (!value.isFinite ||
        (value == value.truncateToDouble() && value.abs() > backupMaxInteger)) {
      invalidBackup();
    }
  } else if (value != null && value is! bool) {
    invalidBackup();
  }
}

String _canonicalNumber(num value) {
  if (!value.isFinite) invalidBackup();
  if (value == 0) return '0';
  final negative = value < 0;
  final parts = value.abs().toDouble().toString().toLowerCase().split('e');
  final mantissa = parts[0];
  var point = mantissa.contains('.') ? mantissa.indexOf('.') : mantissa.length;
  point += parts.length == 2 ? int.parse(parts[1]) : 0;
  var digits = mantissa.replaceAll('.', '');
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
    point--;
  }
  while (digits.endsWith('0')) {
    digits = digits.substring(0, digits.length - 1);
  }
  final sign = negative ? '-' : '';
  if (point > 0 && point <= 21) {
    if (point >= digits.length) {
      return '$sign$digits${'0' * (point - digits.length)}';
    }
    return '$sign${digits.substring(0, point)}.${digits.substring(point)}';
  }
  if (point <= 0 && point > -6) return '${sign}0.${'0' * -point}$digits';
  final exponent = point - 1;
  final fraction = digits.length == 1 ? '' : '.${digits.substring(1)}';
  return '$sign${digits[0]}${fraction}e${exponent >= 0 ? '+' : ''}$exponent';
}
