import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Structure checks are independent of Flutter generation so fixtures can run
/// quickly. ICU grammar is checked by gen-l10n in the command-line entry point.
List<String> checkLanguagePacks(Directory directory) {
  final errors = <String>[];
  final packs = <String, Map<String, dynamic>>{};
  for (final file in directory.listSync().whereType<File>().where(
    (f) => RegExp(r'app_.+\.arb$').hasMatch(f.path),
  )) {
    try {
      packs[file.path] =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      errors.add('${file.path}: invalid ARB JSON: $e');
    }
  }
  final templateEntry = packs.entries
      .where((e) => e.key.replaceAll('\\', '/').endsWith('/app_en.arb'))
      .firstOrNull;
  if (templateEntry == null) {
    return [...errors, '${directory.path}: missing app_en.arb template'];
  }
  final template = templateEntry.value;
  Set<String> keys(Map<String, dynamic> pack) =>
      pack.keys.where((k) => !k.startsWith('@')).toSet();
  Map<String, String> parameters(Map<String, dynamic> pack, String key) {
    final metadata = pack['@$key'];
    if (metadata is! Map || metadata['placeholders'] is! Map) return {};
    return (metadata['placeholders'] as Map).map(
      (name, data) => MapEntry(
        name.toString(),
        data is Map ? '${data['type']}' : 'invalid',
      ),
    );
  }

  final tags = <String>{}, names = <String>{};
  for (final entry in packs.entries) {
    final file = entry.key, pack = entry.value;
    void fail(String message) => errors.add('$file: $message');
    final tag = pack['@@locale'];
    if (tag is! String ||
        !RegExp(r'^[a-z]{2,3}(?:_[A-Z][a-z]{3})?(?:_(?:[A-Z]{2}|\d{3}))?$')
            .hasMatch(tag)) {
      fail('invalid @@locale');
    } else {
      if (!file.replaceAll('\\', '/').endsWith('/app_$tag.arb')) {
        fail('filename must match @@locale $tag');
      }
      if (!tags.add(tag)) fail('duplicate locale $tag');
    }
    final name = pack['languageSelfName'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.contains(RegExp(r'[{}\r\n]'))) {
      fail('invalid languageSelfName');
    } else if (!names.add(name.trim())) {
      fail('duplicate languageSelfName $name');
    }
    for (final missing in keys(template).difference(keys(pack))) {
      fail('missing key $missing');
    }
    for (final extra in keys(pack).difference(keys(template))) {
      fail('unexpected key $extra');
    }
    for (final key in keys(pack)) {
      final value = pack[key];
      if (value is! String || value.trim().isEmpty) {
        fail('$key: empty or non-text translation');
        continue;
      }
      final expected = parameters(template, key),
          actual = parameters(pack, key);
      if (jsonEncode(expected) != jsonEncode(actual) &&
          (expected.length != actual.length ||
              expected.entries.any((e) => actual[e.key] != e.value))) {
        fail(
          '$key: placeholder names/types differ: expected $expected, got $actual',
        );
      }
      for (final parameter in expected.keys) {
        if (!RegExp('\\{\\s*$parameter\\s*[,}]').hasMatch(value)) {
          fail('$key: missing placeholder $parameter in message');
        }
      }
      final used = RegExp(r'\{\s*([a-zA-Z]\w*)\s*[,}]')
          .allMatches(value)
          .map((m) => m[1]!)
          .where((p) => p != 'other');
      for (final parameter in used) {
        if (!expected.containsKey(parameter)) {
          fail('$key: unknown placeholder $parameter');
        }
      }
      if (file == templateEntry.key &&
          (pack['@$key'] is! Map ||
              (pack['@$key'] as Map)['description'] == null)) {
        fail('$key: missing context description');
      }
    }
  }
  return errors;
}

List<String> checkDartText(String source, {String path = 'fixture.dart'}) {
  final result = parseString(content: source, path: path);
  final visitor = _TextVisitor(path, result.lineInfo);
  result.unit.accept(visitor);
  return visitor.errors;
}

class _TextVisitor extends RecursiveAstVisitor<void> {
  _TextVisitor(this.path, this.lines);
  final String path;
  final LineInfo lines;
  final errors = <String>[];
  // Brand is the only human-readable constant allowed in a UI text sink.
  static const allowedText = {'SetTrace'};
  static const sinks = {
    'Text',
    'TextSpan',
    'Tooltip',
    'Semantics',
    'AppButton',
    'InputDecoration',
    'SnackBarAction',
    'StepPicker',
    'IconButton',
    'PopupMenuButton',
  };
  static const namedSinks = {
    'text',
    'label',
    'hintText',
    'labelText',
    'helperText',
    'errorText',
    'tooltip',
    'message',
    'semanticLabel',
    'value',
    'hint',
  };
  void inspect(AstNode node) {
    node.accept(
      _LiteralVisitor((literal) {
        if (allowedText.contains(literal) ||
            !RegExp(r'[A-Za-z\u3400-\u9fff]').hasMatch(literal)) {
          return;
        }
        final location = lines.getLocation(node.offset);
        errors.add(
          '$path:${location.lineNumber}:${location.columnNumber}: hardcoded UI text "$literal"',
        );
      }),
    );
  }

  void checkArguments(String name, ArgumentList arguments) {
    if (!sinks.contains(name)) return;
    final args = arguments.arguments;
    if (name == 'Text' && args.isNotEmpty) inspect(args.first);
    for (final arg in args.whereType<NamedExpression>()) {
      if (namedSinks.contains(arg.name.label.name)) inspect(arg.expression);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    checkArguments(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name.lexeme;
    if (sinks.contains(name)) {
      final args = node.argumentList.arguments;
      if (name == 'Text' && args.isNotEmpty) inspect(args.first);
      for (final arg in args.whereType<NamedExpression>()) {
        if (namedSinks.contains(arg.name.label.name)) inspect(arg.expression);
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

class _LiteralVisitor extends RecursiveAstVisitor<void> {
  _LiteralVisitor(this.onText);
  final void Function(String) onText;
  @override
  void visitConditionalExpression(ConditionalExpression node) {
    // Protocol literals in a condition are not displayed to the user.
    node.thenExpression.accept(this);
    node.elseExpression.accept(this);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    onText(node.value);
  }

  @override
  void visitInterpolationString(InterpolationString node) {
    onText(node.value);
  }
}

Future<void> main(List<String> args) async {
  final root = Directory(args.firstOrNull ?? '.');
  final errors = checkLanguagePacks(Directory('${root.path}/lib/l10n'));
  for (final file
      in Directory('${root.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.replaceAll('\\', '/').contains('/generated/'),
          )) {
    errors.addAll(checkDartText(file.readAsStringSync(), path: file.path));
    // Native/protocol and business files must not contain cached Chinese text.
    if (!file.path.endsWith('localization.dart') &&
        RegExp(r'[\u3400-\u9fff]').hasMatch(
          file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), ''),
        )) {
      errors.add('${file.path}: Chinese literal outside language packs');
    }
  }
  for (final file
      in Directory('${root.path}/android/app/src/main')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.kt'))) {
    if (RegExp(
      r'[\u3400-\u9fff]',
    ).hasMatch(file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), ''))) {
      errors.add('${file.path}: translated text in native protocol');
    }
  }
  if (errors.isEmpty) {
    final generation = await Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      ['gen-l10n'],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    if (generation.exitCode != 0) {
      errors.add('gen-l10n: ${generation.stdout}\n${generation.stderr}');
    }
    final report = File('${root.path}/build/l10n-untranslated.json');
    if (!report.existsSync() ||
        (jsonDecode(report.readAsStringSync()) as Map).values.any(
          (value) => value is List && value.isNotEmpty,
        )) {
      errors.add('Missing or nonempty untranslated messages report');
    }
  }
  if (errors.isEmpty) {
    final runtime = await Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      [
        'test',
        '--no-pub',
        'test/localization_resources_test.dart',
        '--reporter',
        'expanded',
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    if (runtime.exitCode != 0) {
      errors.add(
        'Generated resource validation: ${runtime.stdout}\n${runtime.stderr}',
      );
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
      'Language packs, UI text sinks, ICU generation and untranslated report passed.',
    );
  }
}
