import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:flutter_test/flutter_test.dart';

// Exact brand names only: a phrase containing a brand needs translation.
const _brands = {'SENTECH', 'Sentech Connect', 'WhatsApp', 'MTN'};
const _textArguments = {
  'label',
  'title',
  'subtitle',
  'tooltip',
  'semanticsLabel',
  'semanticLabel',
  'hintText',
  'labelText',
  'helperText',
  'errorText',
  'content',
  'message',
  'text',
  'prefixText',
  'suffixText',
  'counterText',
  'body',
  'dueLabel',
  'question',
  'answer',
  'description',
  'badge',
  'expiresOn',
};
const _copyVariables = {
  'label',
  'message',
  'dueLabel',
  'items',
  'startupErrorMessage',
};

/// A text-sink guard, not whole-program data-flow analysis. Indirect copy
/// also needs review. Parsing Dart handles comments, escapes and interpolation.
List<String> findHardCodedStrings(String path, String source) {
  final parsed = parseString(content: source);
  final visitor = _CopyVisitor(path, parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.hits;
}

class _CopyVisitor extends RecursiveAstVisitor<void> {
  _CopyVisitor(this.path, this.lines);
  final String path;
  final LineInfo lines;
  final hits = <String>[];

  bool _isCopy(AstNode node) {
    for (
      AstNode? parent = node.parent;
      parent != null;
      parent = parent.parent
    ) {
      if (parent is NamedArgument) {
        final owner = parent.parent?.parent;
        if (parent.name.lexeme == 'text' &&
            ((owner is InstanceCreationExpression &&
                    owner.constructorName.type.name.lexeme ==
                        'TextEditingController') ||
                (owner is MethodInvocation &&
                    owner.methodName.name == 'TextEditingController'))) {
          return false;
        }
        return _textArguments.contains(parent.name.lexeme);
      }
      if (parent is RecordLiteralNamedField) {
        return _textArguments.contains(parent.name.lexeme);
      }
      if (parent is ArgumentList) {
        final owner = parent.parent;
        final name = owner is InstanceCreationExpression
            ? owner.constructorName.type.name.lexeme
            : owner is MethodInvocation
            ? owner.methodName.name
            : '';
        return {'Text', 'SelectableText', '_showMessage'}.contains(name) &&
            parent.arguments.first == _expressionChild(parent, node);
      }
      if (parent is VariableDeclaration) {
        return _copyVariables.contains(parent.name.lexeme);
      }
      if (parent is Statement || parent is Declaration) return false;
    }
    return false;
  }

  AstNode _expressionChild(AstNode parent, AstNode node) {
    var child = node;
    while (child.parent != parent) {
      child = child.parent!;
    }
    return child;
  }

  void _record(AstNode node, String visible) {
    if (!_isCopy(node) || _brands.contains(visible)) return;
    if (!RegExp(r'[A-Za-z\u00c0-\u024f]').hasMatch(visible)) return;
    hits.add('$path:${lines.getLocation(node.offset).lineNumber}: $visible');
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _record(node, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _record(
      node,
      node.elements.whereType<InterpolationString>().map((e) => e.value).join(),
    );
    // Nested expression literals still count: Text('${ok ? "Yes" : "No"}').
    super.visitStringInterpolation(node);
  }
}

Iterable<File> _scanned() sync* {
  for (final directory in ['lib/features', 'lib/app', 'lib/shared']) {
    yield* Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              (directory != 'lib/features' ||
                  file.path.contains('presentation')),
        );
  }
  yield File(
    'lib/features/support/data/repositories/mock_support_repository.dart',
  );
  yield File(
    'lib/features/promotions/data/repositories/mock_promotions_repository.dart',
  );
  yield File('lib/l10n/demo_copy.dart');
}

void main() {
  test('flags const, multiline, ternary, interpolation and escaped copy', () {
    for (final source in [
      "const Text('Plans')",
      "Text(\n  'Hello there',\n)",
      'Text("That code didn\'t work")',
      r"Text('That code didn\'t work')",
      "Text(ok ? 'Yes' : 'No')",
      "Button(label: const Text('Retry'))",
      r"Text('${name} added to cart')",
      r'''Text('${ok ? "Yes" : "No"}')''',
      "Text('''Hello\nthere''')",
      r"Text('\u0048ello')",
      "final message = 'Please retry'; Text(message);",
      "Text('Ask WhatsApp for help')",
      "Notice(subtitle: 'Try later', message: 'Saved', body: 'Please retry')",
      "Faq(id: 'technical-id', question: 'How do I pay?', answer: 'Open Buy')",
      "Promotion(id: 'technical-id', title: 'Save now', description: 'An offer', badge: 'SAVE')",
    ]) {
      expect(
        findHardCodedStrings('fixture.dart', 'void fixture() {\n$source;\n}'),
        isNotEmpty,
        reason: source,
      );
    }
    expect(
      findHardCodedStrings('x', "void f() { Text(ok ? 'Yes' : 'No'); }"),
      hasLength(2),
    );
  });

  test(
    'ignores comments, technical arguments, localized values and exact brands',
    () {
      for (final source in [
        "// Text('Ignore me')\n/* label: 'Ignore me' */",
        "context.go('/main'); const ValueKey('checkout-button');",
        "Text(context.l10n.navHome)",
        "Text(l10n.lookup('technical_key'))",
        r"Text('${context.l10n.navHome} · $amount')",
        "Text(' · ')",
        r"Text('\n')",
        "const Text('WhatsApp')",
        "const Text('SENTECH')",
        "Text(name, style: TextStyle(fontFamily: 'monospace'))",
        "TextEditingController(text: '12 Example Street')",
      ]) {
        expect(
          findHardCodedStrings('fixture.dart', 'void fixture() {\n$source;\n}'),
          isEmpty,
          reason: source,
        );
      }
    },
  );

  test('no hard-coded user-facing strings in presentation code', () {
    final hits = [
      for (final file in _scanned())
        ...findHardCodedStrings(file.path, file.readAsStringSync()),
    ];
    expect(
      hits,
      isEmpty,
      reason: 'move to lib/l10n/app_en.arb:\n${hits.join('\n')}',
    );
  });
}
