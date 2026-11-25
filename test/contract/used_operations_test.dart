import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps `test/contract/used_operations.json` honest.
///
/// Extraction: every string literal in lib/ that starts with `/v1/` is an API
/// path the app can call. Interpolations (`${...}`) and OpenAPI parameters
/// (`{name}`) both normalise to `{}`. Limits: the HTTP method is not
/// extracted (the manifest is its source and is checked against the snapshot),
/// and a path built from a constant plus a suffix (`'$ticketsPath/$ref/close'`)
/// is not a literal, so the manifest marks it `"composed": true` and the test
/// requires a literal prefix for it.
String normalise(String path) =>
    path.replaceAll(RegExp(r'\$\{[^}]*\}'), '{}').replaceAll(RegExp(r'\{[^}]*\}'), '{}');

Set<String> literalPathsInLib() {
  final found = <String>{};
  final literal = RegExp(r'''(?<![\w/$])(['"])(/v1/[^'"\s]*)\1''');
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    for (final line in file.readAsLinesSync()) {
      final code = line.trimLeft();
      if (code.startsWith('//')) continue;
      for (final m in literal.allMatches(line)) {
        found.add(normalise(m.group(2)!));
      }
    }
  }
  return found;
}

void main() {
  final manifest = jsonDecode(File('test/contract/used_operations.json').readAsStringSync()) as Map;
  final operations = [for (final o in manifest['operations'] as List) Map<String, Object?>.from(o as Map)];
  final outside = [for (final o in manifest['outsideContract'] as List) Map<String, Object?>.from(o as Map)];
  final snapshot = jsonDecode(File('test/contract/openapi.json').readAsStringSync()) as Map;
  final literals = literalPathsInLib();

  test('every /v1 path literal in lib/ is in the manifest', () {
    final known = {for (final o in [...operations, ...outside]) normalise(o['path']! as String)};
    expect(literals.difference(known), isEmpty,
        reason: 'lib/ calls a path that used_operations.json does not list: add it (method + path template)');
  });

  test('every manifest path is a literal in lib/ or marked composed with a literal prefix', () {
    final stale = <String>[];
    for (final o in [...operations, ...outside]) {
      final path = normalise(o['path']! as String);
      if (literals.contains(path)) continue;
      final composedOk = o['composed'] == true && literals.any((l) => path.startsWith('$l/'));
      if (!composedOk) stale.add('${o['method']} ${o['path']}');
    }
    expect(stale, isEmpty, reason: 'in the manifest but not called from lib/');
  });

  test('every manifest operation exists in the saved snapshot (outsideContract does not)', () {
    final paths = snapshot['paths'] as Map;
    final missing = [
      for (final o in operations)
        if ((paths[o['path']] as Map?)?.containsKey(o['method']) != true) '${o['method']} ${o['path']}',
    ];
    expect(missing, isEmpty);
    final wrong = [
      for (final o in outside)
        if ((paths[o['path']] as Map?)?.containsKey(o['method']) == true) '${o['method']} ${o['path']}',
    ];
    expect(wrong, isEmpty, reason: 'outsideContract entries that are in the snapshot belong in operations');
  });

  test('the manifest is sorted, unique and uses lower-case methods', () {
    final keys = [for (final o in operations) '${o['path']} ${o['method']}'];
    expect(keys.toSet().length, keys.length);
    expect(keys, [...keys]..sort());
    expect(operations.every((o) => o['method'] == (o['method']! as String).toLowerCase()), isTrue);
  });

  test('the extraction itself sees the known paths (guards against a broken regex)', () {
    expect(literals, containsAll(['/v1/app-config', '/v1/orders/{}/checkout', '/v1/me/subscriber/services/{}/data']));
  });
}
