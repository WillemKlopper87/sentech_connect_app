import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

import '../helpers/fixtures.dart';
import 'openapi_schema.dart';

/// Fixture file -> 2xx response schema in apps/api/openapi.json.
const fixtureSchemas = {
  'app_config.json': 'AppConfig',
  'tenants.json': 'TenantDirectory',
  'products_page_1.json': 'Page_ProductOut_',
  'products_page_2.json': 'Page_ProductOut_',
  'orders_page.json': 'Page_OrderOut_',
  'order_draft.json': 'OrderOut',
  'checkout_fake.json': 'CheckoutOut',
  'checkout_netcash.json': 'CheckoutOut',
  'entitlements_page.json': 'Page_EntitlementOut_',
  'voucher_redeem_ok.json': 'RedeemOut',
  'otp_request.json': 'OtpRequestOut',
  'delete_challenge.json': 'OtpRequestOut', // POST /v1/me/delete-challenge answers the same shape
  'token_pair.json': 'TokenPairOut',
  'profile.json': 'ProfileOut',
  'profile_complete.json': 'ProfileOut',
  'consents.json': 'ConsentState',
  'consent_out.json': 'ConsentOut',
  'export.json': 'CustomerExport',
};

/// Keys each hand-written decoder reads. Change it in the same commit as the decoder.
const decoderReads = <String, Set<String>>{
  'AppConfig': {
    'tenant',
    'min_app_version',
    'feature_flags',
    'legal',
    'support',
    'modules',
    'collection_mode_public',
  },
  'FeatureFlags': {
    'hotspot_passes',
    'rica',
    'cpe',
    'vouchers',
    'hotspot_radius',
  },
  'SupportContact': {'email', 'phone'},
  'TenantPublic': {'slug', 'name', 'type', 'branding'},
  'Branding': {
    'primary_color',
    'secondary_color',
    'accent_color',
    'logo_url',
    'logo_alt',
    'app_display_name',
    'legal_urls',
    'whatsapp_number',
  },
  'LegalUrls': {
    'terms',
    'privacy',
    'cooling-off',
    'service-charter',
    'complaints',
    'paia',
  },
  'LegalVersions': {'terms', 'privacy'},
  'TenantDirectory': {'tenants', 'next_cursor'},
  'OrderOut': {'id', 'status', 'total', 'lines'},
  'OrderLineOut': {'name', 'quantity'},
  'Money': {'amount_cents', 'currency'},
  'CheckoutOut': {
    'payment_id',
    'reference',
    'gateway',
    'method',
    'url',
    'fields',
    'amount',
  },
  'EntitlementOut': {
    'id',
    'order_id',
    'source',
    'product_name',
    'status',
    'starts_at',
    'expires_at',
    'duration_minutes',
    'data_mb',
    'speed_kbps',
    'max_devices',
    'used_bytes',
    'origin_type',
    'scope',
    'funded_by_other',
    'home_serving_differs',
  },
  'EntitlementScopeOut': {'kind'},
  'OtpRequestOut': {'challenge_id', 'expires_in_seconds', 'reference'},
  // Request bodies the app sends (every key must exist in the API schema).
  'OtpRequestIn': {'tenant', 'phone', 'binding'},
  'OtpVerifyIn': {'tenant', 'challenge_id', 'code', 'binding'},
  'DeleteAccountIn': {'challenge_id', 'code'},
  'ProblemDetail': {'code', 'title', 'detail', 'request_id'},
};

/// Keys read before the API serves them (absent = default value).
const aheadOfApi = <String, Set<String>>{
  'Branding': {'app_display_name'},
};

void main() {
  final api = OpenApiSnapshot.load();

  test('every API fixture is mapped to a schema', () {
    final files = Directory('test/fixtures/api')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.json'))
        .toSet();
    expect(files, fixtureSchemas.keys.toSet());
  });

  for (final MapEntry(key: file, value: name) in fixtureSchemas.entries) {
    test('$file matches $name', () {
      expect(api.validate(fixture(file), api.schema(name)), isEmpty);
    });
  }

  for (final MapEntry(key: name, value: keys) in decoderReads.entries) {
    test('$name: every key the app reads exists in the API', () {
      final ahead = aheadOfApi[name] ?? const <String>{};
      expect(keys.difference(api.properties(name)).difference(ahead), isEmpty);
    });
  }

  test('aheadOfApi keys are not in the API yet (move them when they ship)', () {
    for (final MapEntry(key: name, value: keys) in aheadOfApi.entries) {
      expect(keys.intersection(api.properties(name)), isEmpty, reason: name);
    }
  });

  test('every order status the API can send is mapped', () {
    for (final s
        in (api.schema('OrderStatus')['enum']! as List).cast<String>()) {
      expect(() => orderStatusFromApi(s), returnsNormally, reason: s);
    }
  });

  test('every entitlement origin and scope kind is typed, not unknown', () {
    final props = api.schema('EntitlementOut')['properties']! as Map;
    final origins = ((props['origin_type']! as Map)['enum']! as List)
        .cast<String>();
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    expect(origins, isNotEmpty);
    for (final o in origins) {
      expect(
        passFromJson({...base, 'origin_type': o}).origin,
        isNot(PassOrigin.unknown),
        reason: o,
      );
    }
    final scopeProps = api.schema('EntitlementScopeOut')['properties']! as Map;
    final kinds = ((scopeProps['kind']! as Map)['enum']! as List)
        .cast<String>();
    expect(kinds, isNotEmpty);
    for (final k in kinds) {
      final p = passFromJson({
        ...base,
        'scope': [
          {'kind': k},
        ],
      });
      expect(p.scopes.single.kind, isNot(PassScopeKind.unknown), reason: k);
    }
  });

  test('every entitlement status is a PassStatus', () {
    final status =
        (api.schema('EntitlementOut')['properties']! as Map)['status'] as Map;
    final names = PassStatus.values.map((s) => s.name).toSet();
    expect((status['enum']! as List).toSet().difference(names), isEmpty);
  });

  test('every entitlement source parses without throwing or going unknown', () {
    final source =
        (api.schema('EntitlementOut')['properties']! as Map)['source'] as Map;
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    for (final v in (source['enum']! as List).cast<String>()) {
      expect(
        passFromJson({...base, 'source': v}).source,
        isNot(PassSource.unknown),
        reason: v,
      );
    }
  });

  test('a null product_id and the service source are tolerated', () {
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    final pass = passFromJson({...base, 'product_id': null, 'source': 'service'});
    expect(pass.source, PassSource.service);
  });

  test('an unknown entitlement status still fails loudly', () {
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    expect(
      () => passFromJson({...base, 'status': 'frozen'}),
      throwsFormatException,
    );
  });

  test('the delete-challenge route answers OtpRequestOut and takes DeleteChallengeIn', () {
    final route = api.path('/v1/me/delete-challenge', 'post');
    expect(api.responseSchemaName(route, '202'), 'OtpRequestOut');
    expect(
      api.properties('DeleteChallengeIn'),
      contains('turnstile_token'), // sent later (M2)
    );
    final del = api.path('/v1/me', 'delete');
    expect(api.requestBodySchemaName(del), 'DeleteAccountIn');
  });
}
