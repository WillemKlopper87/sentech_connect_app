import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) =>
    Map<String, Object?>.from(jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map);

/// Coverage copy that makes a claim (a prediction, a band, a speed, a date, a disclaimer, a
/// consent, the waiting list, what happens to the customer's data) or is legal wording. It is
/// NEVER machine-drafted: af and zu stay the platform's English until a native speaker and
/// counsel have written it (platform `docs/coverage/native-review-af-zu.md`, items C1, C2, C4).
final _claimKey = RegExp(
  r'^coverage('
  r'Band.*|Option(Covered|Planned)Heading|OptionPlanned(Text|NoDate)|OptionPredicted(Title|Text)|OptionNearBoundary|'
  r'Speed(Typical|Busy)|Confidence.*|Measure.*|Nearest.*|Footer.*|Source.*|Disclaimer.*|'
  r'NotCoveredTitle|OptionsTitle|StatusPlanned|'
  r'Notify(Prompt|Title|Intro|Consent|ConsentNote|ArrivalConsent|ArrivalNote|Submit|Sent|ConsentRequired|Reconfirm|Pending)|'
  r'Leave(Link|Title|Intro|Send|Requested)|'
  r'SearchPrivacyNote|LocationExplain|NoAddressMatches|MatchedStreet|MatchedArea|SearchRateLimited'
  r')$',
);

void main() {
  final en = _arb('en');
  final af = _arb('af');
  final zu = _arb('zu');
  final doc = File('docs/L10N_NEEDS_NATIVE_REVIEW.md').readAsStringSync();
  final coverageKeys = en.keys.where((k) => !k.startsWith('@') && k.startsWith('coverage')).toList();
  final claimKeys = coverageKeys.where(_claimKey.hasMatch).toList();
  final draftKeys = coverageKeys.where((k) => !_claimKey.hasMatch(k) && af[k] != en[k]).toList();

  test('there are claim keys and draft keys to guard', () {
    expect(claimKeys.length, greaterThan(40));
    expect(draftKeys, isNotEmpty);
  });

  test('claims_and_legal_wording_are_never_machine_drafted_af_and_zu_keep_the_english', () {
    for (final key in claimKeys) {
      expect(af[key], en[key], reason: 'af/$key is a claim: it stays English until native review and counsel');
      expect(zu[key], en[key], reason: 'zu/$key is a claim: it stays English until native review and counsel');
    }
  });

  test('every claim key is listed in the native review file as an English fallback', () {
    final missing = claimKeys.where((k) => !doc.contains('`$k`')).toList();
    expect(missing, isEmpty, reason: 'list these in docs/L10N_NEEDS_NATIVE_REVIEW.md: $missing');
  });

  test('every machine draft is listed with its af and zu text', () {
    for (final key in draftKeys) {
      expect(doc, contains('`$key`'), reason: key);
      expect(doc, contains(af[key]! as String), reason: 'af/$key');
      expect(doc, contains(zu[key]! as String), reason: 'zu/$key');
    }
  });

  test('every coverage string has text and a translator note in English', () {
    for (final key in coverageKeys) {
      expect((en[key]! as String).trim(), isNotEmpty, reason: key);
      expect((af[key]! as String).trim(), isNotEmpty, reason: 'af/$key');
      expect((zu[key]! as String).trim(), isNotEmpty, reason: 'zu/$key');
      expect(((en['@$key']! as Map)['description']! as String).trim(), isNotEmpty, reason: key);
    }
  });

  test('the consent and waiting-list copy is the platform wording, English in every language', () {
    for (final key in ['coverageNotifyConsent', 'coverageNotifyArrivalConsent', 'coverageNotifyConsentNote', 'coverageNotifyArrivalNote']) {
      expect(af[key], en[key], reason: key);
      expect(zu[key], en[key], reason: key);
    }
  });
}
