import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

import 'helpers/fixtures.dart';

Map<String, Object?> first([Map<String, Object?> extra = const {}]) => {
  ...Map<String, Object?>.from(
    (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
  ),
  ...extra,
};

void main() {
  test('an older server: origin falls back to source, no scope or flags', () {
    final json = first()
      ..remove('origin_type')
      ..remove('scope')
      ..remove('funded_by_other')
      ..remove('home_serving_differs');
    final p = passFromJson(json);
    expect(p.origin, PassOrigin.order);
    expect(p.scopes, isEmpty);
    expect(p.fundedByOther, isFalse);
    expect(p.homeServingDiffers, isFalse);
    expect(
      passFromJson({...json, 'source': 'voucher'}).origin,
      PassOrigin.voucher,
    );
    expect(
      passFromJson({...json, 'source': 'gift'}).origin,
      PassOrigin.unknown,
    );
  });

  test('the current API shape is read as sent', () {
    final p = passFromJson(
      first({
        'origin_type': 'sponsored',
        'scope': [
          {'kind': 'site'},
          {'kind': 'time_window'},
        ],
        'funded_by_other': true,
        'home_serving_differs': true,
      }),
    );
    expect(p.origin, PassOrigin.sponsored);
    expect(p.scopes.map((s) => s.kind), [
      PassScopeKind.site,
      PassScopeKind.timeWindow,
    ]);
    expect(p.fundedByOther, isTrue);
    expect(p.homeServingDiffers, isTrue);
  });

  test('every origin and scope kind the API names has a typed value', () {
    const origins = {
      'order': PassOrigin.order,
      'voucher': PassOrigin.voucher,
      'admin': PassOrigin.admin,
      'service': PassOrigin.service,
      'free_time': PassOrigin.freeTime,
      'credits': PassOrigin.credits,
      'sponsored': PassOrigin.sponsored,
      'roaming': PassOrigin.roaming,
    };
    for (final MapEntry(:key, :value) in origins.entries) {
      expect(
        passFromJson(first({'origin_type': key})).origin,
        value,
        reason: key,
      );
    }
    const kinds = {
      'site': PassScopeKind.site,
      'zone': PassScopeKind.zone,
      'tenant': PassScopeKind.tenant,
      'time_window': PassScopeKind.timeWindow,
      'nas_class': PassScopeKind.nasClass,
    };
    for (final MapEntry(:key, :value) in kinds.entries) {
      final p = passFromJson(
        first({
          'scope': [
            {'kind': key},
          ],
        }),
      );
      expect(p.scopes.single.kind, value, reason: key);
    }
  });

  test('unknown or malformed new values never throw and never leak', () {
    final p = passFromJson(
      first({
        'origin_type': 'teleport',
        'scope': [
          {'kind': 'galaxy'},
          'junk',
          {'kind': 7},
          {'no_kind': true},
          {'kind': 'zone', 'ref_text': 'ignored'},
        ],
        'funded_by_other': 'yes',
        'home_serving_differs': 1,
      }),
    );
    expect(p.origin, PassOrigin.unknown);
    expect(p.scopes.map((s) => s.kind), [
      PassScopeKind.unknown,
      PassScopeKind.zone,
    ]);
    expect(p.fundedByOther, isFalse);
    expect(p.homeServingDiffers, isFalse);
    expect(passFromJson(first({'origin_type': 5})).origin, PassOrigin.unknown);
    expect(passFromJson(first({'scope': 'site'})).scopes, isEmpty);
  });

  test('an unknown status still fails the load', () {
    expect(
      () => passFromJson(first({'status': 'frozen', 'origin_type': 'order'})),
      throwsFormatException,
    );
  });

  test('the new fields take part in equality', () {
    final a = passFromJson(first({'funded_by_other': true}));
    expect(a, isNot(passFromJson(first())));
    expect(a, passFromJson(first({'funded_by_other': true})));
  });
}
