import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  late ApiHarness h;
  late HttpTenantRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpTenantRepository(h.api);
  });

  test('lists the ISP directory without authentication', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, fixture('tenants.json')));
    final tenants = (await repo.listTenants()).getOrElse((f) => throw StateError(f.message));
    expect(tenants.map((t) => t.slug), ['sentech', 'acme-wifi']);
    expect(tenants[1].isReseller, isTrue);
    expect(tenants[1].branding.primaryColor, const Color(0xFF123456));
    expect(tenants[1].branding.logoUrl, Uri.parse('https://cdn.example.test/acme.png'));
    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('loads app-config for the chosen tenant', () async {
    h.adapter.on('GET', '/v1/app-config', (_) => FakeReply(200, fixture('app_config.json')));
    final config = (await repo.getAppConfig('acme-wifi')).getOrElse((f) => throw StateError(f.message));
    expect(h.adapter.requests.single.uri.queryParameters, {'tenant': 'acme-wifi'});
    expect(config.tenant.name, 'Acme Wi-Fi');
    expect(config.featureFlags, const FeatureFlags(hotspotPasses: true, rica: false, cpe: false));
    expect(config.legal, const LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'));
    expect(config.minAppVersion, '1.0.0');
  });

  test('an unknown or suspended tenant is a NotFoundFailure', () async {
    h.adapter.on('GET', '/v1/app-config', (_) => FakeReply.problem(404, 'tenant_not_found', detail: 'Unknown tenant.'));
    expect((await repo.getAppConfig('gone')).match((f) => f, (_) => null), isA<NotFoundFailure>());
  });

  test('branding ignores non-https logos and malformed colours', () {
    final branding = TenantBranding.fromJson({'primary_color': 'red', 'logo_url': 'http://x.test/logo.png'});
    expect(branding.primaryColor, isNull);
    expect(branding.logoUrl, isNull);
  });

  test('a config missing required fields is rejected, not half-applied', () {
    expect(() => AppConfig.fromJson({'tenant': fixtureMap('app_config.json')['tenant']}), throwsFormatException);
  });

  test('app-config round-trips through JSON (used for the offline cache)', () {
    final config = AppConfig.fromJson(fixtureMap('app_config.json'));
    expect(AppConfig.fromJson(config.toJson()), config);
  });
}
