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
  'token_pair.json': 'TokenPairOut',
  'profile.json': 'ProfileOut',
  'profile_complete.json': 'ProfileOut',
  'consents.json': 'ConsentState',
  'consent_out.json': 'ConsentOut',
  'export.json': 'CustomerExport',
};

/// Keys each hand-written decoder reads. Change it in the same commit as the decoder.
const decoderReads = <String, Set<String>>{
  'AppConfig': {'tenant', 'min_app_version', 'feature_flags', 'legal', 'support', 'modules', 'collection_mode_public'},
  'FeatureFlags': {'hotspot_passes', 'rica', 'cpe', 'vouchers', 'hotspot_radius'},
  'SupportContact': {'email', 'phone'},
  'TenantPublic': {'slug', 'name', 'type', 'branding'},
  'Branding': {
    'primary_color', 'secondary_color', 'accent_color', 'logo_url', 'logo_alt',
    'app_display_name', 'legal_urls', 'whatsapp_number',
  },
  'LegalUrls': {'terms', 'privacy', 'cooling-off', 'service-charter', 'complaints', 'paia'},
  'LegalVersions': {'terms', 'privacy'},
  'TenantDirectory': {'tenants', 'next_cursor'},
  'OrderOut': {'id', 'status', 'total', 'lines'},
  'OrderLineOut': {'name', 'quantity'},
  'Money': {'amount_cents', 'currency'},
  'CheckoutOut': {'payment_id', 'reference', 'gateway', 'method', 'url', 'fields', 'amount'},
  'EntitlementOut': {
    'id', 'order_id', 'source', 'product_name', 'status', 'starts_at', 'expires_at',
    'duration_minutes', 'data_mb', 'speed_kbps', 'max_devices', 'used_bytes',
  },
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
    for (final s in (api.schema('OrderStatus')['enum']! as List).cast<String>()) {
      expect(() => orderStatusFromApi(s), returnsNormally, reason: s);
    }
  });

  test('every entitlement status is a PassStatus', () {
    final status = (api.schema('EntitlementOut')['properties']! as Map)['status'] as Map;
    final names = PassStatus.values.map((s) => s.name).toSet();
    expect((status['enum']! as List).toSet().difference(names), isEmpty);
  });
}
