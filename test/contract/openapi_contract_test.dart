import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';

import '../helpers/fixtures.dart';
import 'openapi_schema.dart';

/// Fixture file -> 2xx response schema in apps/api/openapi.json.
const fixtureSchemas = {
  'app_config.json': 'AppConfig',
  'tenants.json': 'TenantDirectory',
  'products_page_1.json': 'Page_ProductOut_',
  'products_page_2.json': 'Page_ProductOut_',
  'orders_page.json': 'Page_OrderOut_',
  'hotspots_page.json': 'Page_HotspotPublicOut_',
  'order_draft.json': 'OrderOut',
  'checkout_fake.json': 'CheckoutOut',
  'checkout_netcash.json': 'CheckoutOut',
  'entitlements_page.json': 'Page_EntitlementOut_',
  // GET /v1/me/entitlements?status=current: a suspended pass past expires_at is listed (platform d4be7ce).
  'entitlements_current_suspended.json': 'Page_EntitlementOut_',
  'voucher_redeem_ok.json': 'RedeemOut',
  'otp_request.json': 'OtpRequestOut',
  'delete_challenge.json': 'OtpRequestOut', // POST /v1/me/delete-challenge answers the same shape
  'token_pair.json': 'TokenPairOut',
  'profile.json': 'ProfileOut',
  'profile_complete.json': 'ProfileOut',
  'consents.json': 'ConsentState',
  'consent_out.json': 'ConsentOut',
  'export.json': 'CustomerExport',
  // GET /v1/auth/human-check/config (platform ae401a0); the second has no widget (fake verifier).
  'human_check_config.json': 'HumanCheckConfig',
  'human_check_config_no_widget.json': 'HumanCheckConfig',
  'support_accepted.json': 'SupportAcceptedOut', // POST /v1/support/messages 202
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
  'HotspotPublicOut': {'id', 'name', 'address_text', 'lat', 'lon', 'status'},
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
  'HumanCheckConfig': {'turnstile'},
  'TurnstileConfig': {'site_key', 'base_url', 'required'},
  'HumanCheckRequired': {'otp_request', 'delete_challenge', 'support_message', 'lead'},
  'SupportAcceptedOut': {'reference'},
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

  test('every hotspot status the API can send is mapped', () {
    final status =
        (api.schema('HotspotPublicOut')['properties']! as Map)['status'] as Map;
    final names = HotspotStatus.values.map((s) => s.name).toSet();
    expect((status['enum']! as List).toSet(), names);
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

  test('every entitlement status the API can send parses to its own PassStatus', () {
    final status =
        (api.schema('EntitlementOut')['properties']! as Map)['status'] as Map;
    final base = Map<String, Object?>.from(
      (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
    );
    for (final v in (status['enum']! as List).cast<String>()) {
      expect(passFromJson({...base, 'status': v}).status.name, v);
    }
    expect(passFromJson({...base, 'status': 'suspended'}).isCurrent, isFalse);
  });

  test('status=current lists a suspended pass past expires_at, and the app keeps it suspended and not usable', () {
    final items = (fixtureMap('entitlements_current_suspended.json')['items']! as List)
        .map((i) => passFromJson(Map<String, Object?>.from(i as Map)))
        .toList();
    final suspended = items.singleWhere((p) => p.status == PassStatus.suspended);
    expect(suspended.expiresAt.isBefore(DateTime.utc(2026, 10, 29)), isTrue);
    expect(suspended.source, PassSource.service);
    expect(suspended.isCurrent, isFalse, reason: 'RADIUS and voucher redemption still need active');
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

  test('the order cancel route answers OrderOut', () {
    final route = api.path('/v1/orders/{order_id}/cancel', 'post');
    expect(api.responseSchemaName(route, '200'), 'OrderOut');
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

  test('the human-check config route is public and answers HumanCheckConfig', () {
    final route = api.path('/v1/auth/human-check/config', 'get');
    expect(api.responseSchemaName(route, '200'), 'HumanCheckConfig');
    expect(route.containsKey('security'), isFalse);
    final params = (route['parameters']! as List).cast<Map>();
    expect(params.map((p) => p['name']), ['tenant']);
  });

  group('POST /v1/support/messages', () {
    Map<String, Object?> bodySchema() {
      final route = api.path('/v1/support/messages', 'post');
      final content = (route['requestBody']! as Map)['content']! as Map;
      return Map<String, Object?>.from(((content['application/json']! as Map)['schema']!) as Map);
    }

    test('answers 202 SupportAcceptedOut and requires the Idempotency-Key header', () {
      final route = api.path('/v1/support/messages', 'post');
      expect(api.responseSchemaName(route, '202'), 'SupportAcceptedOut');
      final headers = (route['parameters']! as List).cast<Map>().where((p) => p['in'] == 'header');
      expect(headers.single['name'], 'Idempotency-Key');
      expect(headers.single['required'], isTrue);
    });

    test('the body the app sends validates against the request schema', () {
      final body = {
        'tenant': 'sentech',
        'topic': 'connecting',
        'reply': {'type': 'email', 'value': 'thandi@example.co.za'},
        'message': 'My hotspot pass shows active but I cannot connect.',
        'order_ref': 'AB12-CD34',
        'turnstile_token': 'tok',
      };
      expect(api.validate(body, bodySchema()), isEmpty);
    });

    test('every key and topic the app can send exists in the schema', () {
      final props = (bodySchema()['properties']! as Map).keys.toSet();
      expect({'tenant', 'topic', 'reply', 'message', 'order_ref', 'turnstile_token'}.difference(props), isEmpty);
      final topics = (((bodySchema()['properties']! as Map)['topic']! as Map)['enum']! as List).cast<String>();
      expect(topics, ['connecting', 'payment', 'pass', 'account', 'other']);
    });
  });
}
