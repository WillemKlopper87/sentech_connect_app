import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// dart2js and DDC refuse an integer literal that a JavaScript number cannot hold exactly
/// (above 2^53). The VM runs it, so only a web build would catch one: this test does.
void main() {
  test('no_integer_literal_in_lib_is_above_2_pow_53', () {
    final hex = RegExp(r'\b0[xX]([0-9a-fA-F_]+)\b');
    final dec = RegExp(r'(?<![\w.])(\d{16,})(?![\w.])');
    final limit = BigInt.one << 53;
    final hits = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in hex.allMatches(line)) {
          if (BigInt.parse(m.group(1)!.replaceAll('_', ''), radix: 16) > limit) hits.add('${file.path}:${i + 1}: ${m.group(0)}');
        }
        for (final m in dec.allMatches(line)) {
          if (BigInt.parse(m.group(1)!) > limit) hits.add('${file.path}:${i + 1}: ${m.group(0)}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'web builds refuse these; use a portable value');
  });
}
