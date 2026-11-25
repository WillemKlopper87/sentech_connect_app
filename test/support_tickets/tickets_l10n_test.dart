import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) =>
    Map<String, Object?>.from(jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map);

/// Ticket copy that makes a promise or states a policy (what a retry does, what
/// closing or solving means, the hourly limit, that a removed text is gone). It is
/// NEVER machine-drafted: af and zu stay English until a native speaker, and the
/// provider where it is policy, has written it.
const _englishOnly = {
  'ticketsMessageRemoved',
  'ticketsMarkSolvedBody',
  'ticketsResolvedNote',
  'ticketsClosedNote',
  'ticketsClosedRefused',
  'ticketsUnknownOutcome',
  'ticketsCheckFirst',
  'ticketsReplyCheckFirst',
  'ticketsHeldRateLimit',
  'failureTicketClosed',
};

void main() {
  final en = _arb('en');
  final af = _arb('af');
  final zu = _arb('zu');
  final doc = File('docs/L10N_NEEDS_NATIVE_REVIEW.md').readAsStringSync();
  final keys = en.keys.where((k) => !k.startsWith('@') && (k.startsWith('tickets') || k.startsWith('ticketStatus') || k.startsWith('failureTicket'))).toList();

  test('there are ticket keys to guard, and the English-only list names real keys', () {
    expect(keys.length, greaterThan(40));
    for (final key in _englishOnly) {
      expect(keys, contains(key));
    }
  });

  test('promises_and_policy_wording_stay_english_in_af_and_zu', () {
    for (final key in _englishOnly) {
      expect(af[key], en[key], reason: 'af/$key makes a promise or states a policy: English until reviewed');
      expect(zu[key], en[key], reason: 'zu/$key makes a promise or states a policy: English until reviewed');
    }
  });

  test('every other ticket string has an af and a zu draft that is not the English text', () {
    for (final key in keys.where((k) => !_englishOnly.contains(k))) {
      expect(af[key], isNot(en[key]), reason: 'af/$key');
      expect(zu[key], isNot(en[key]), reason: 'zu/$key');
    }
  });

  test('every ticket key is listed in the native review file', () {
    final missing = keys.where((k) => !doc.contains('`$k`')).toList();
    expect(missing, isEmpty, reason: 'list these in docs/L10N_NEEDS_NATIVE_REVIEW.md: $missing');
  });

  test('every ticket machine draft is listed with its af and zu text', () {
    for (final key in keys.where((k) => !_englishOnly.contains(k))) {
      final line = doc.split('\n').firstWhere((l) => l.startsWith('| `$key` |'), orElse: () => '');
      expect(line, isNotEmpty, reason: key);
      expect(line.contains(af[key]! as String), isTrue, reason: 'af/$key');
      expect(line.contains(zu[key]! as String), isTrue, reason: 'zu/$key');
    }
  });

  test('no ticket string promises a response time or an outcome', () {
    final forbidden = RegExp(r'within|hours?\b|minutes? to|as soon as|guarantee|we will (reply|respond|answer|fix)', caseSensitive: false);
    for (final key in keys) {
      // The wait text ("5 minutes") is a measured wait from the server, not a promise.
      if (key == 'ticketsWaitMinutes' || key == 'ticketsWaitSeconds' || key == 'ticketsHeldRateLimit') continue;
      expect(forbidden.hasMatch(en[key]! as String), isFalse, reason: '$key: ${en[key]}');
    }
  });
}
