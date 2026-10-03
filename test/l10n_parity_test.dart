import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) => Map<String, Object?>.from(
  jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map,
);

Iterable<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

void main() {
  final en = _arb('en');

  test('every English message has translator context', () {
    for (final key in _messageKeys(en)) {
      final metadata = en['@$key'] as Map?;
      expect(metadata?['description'], isA<String>(), reason: key);
      expect(
        (metadata!['description'] as String).trim(),
        isNotEmpty,
        reason: key,
      );
    }
  });

  for (final locale in ['zu', 'af']) {
    test('$locale defines every English key (no silent English fallbacks)', () {
      final other = _arb(locale);
      final missing = _messageKeys(
        en,
      ).where((k) => !other.containsKey(k)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'add these keys to app_$locale.arb: $missing',
      );
    });

    test('$locale keeps every placeholder of the English message', () {
      final other = _arb(locale);
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final key in _messageKeys(en)) {
        final source = en[key];
        final translated = other[key];
        if (source is! String || translated is! String) continue;
        final expected = placeholder
            .allMatches(source)
            .map((m) => m.group(1))
            .toSet();
        final actual = placeholder
            .allMatches(translated)
            .map((m) => m.group(1))
            .toSet();
        expect(actual, expected, reason: '$locale/$key');
      }
    });

    test('$locale has no keys unknown to English', () {
      final other = _arb(locale);
      final extra = _messageKeys(
        other,
      ).where((k) => !en.containsKey(k)).toList();
      expect(extra, isEmpty);
    });

    test('$locale preserves placeholder metadata', () {
      final other = _arb(locale);
      for (final key in _messageKeys(en)) {
        final expected = (en['@$key'] as Map?)?['placeholders'];
        final actual = (other['@$key'] as Map?)?['placeholders'];
        expect(actual, expected, reason: '$locale/$key');
      }
    });

    test('$locale never mentions password login', () {
      final other = _arb(locale);
      final hits = _messageKeys(other)
          .where(
            (k) =>
                (other[k] as String? ?? '').toLowerCase().contains('password'),
          )
          .toList();
      expect(hits, isEmpty, reason: 'password wording in $locale: $hits');
    });
  }
}
