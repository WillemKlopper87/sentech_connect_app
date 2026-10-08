import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

class _RecordingReporter extends CrashReporter {
  final reports = <CrashReport>[];

  @override
  Future<void> report(CrashReport report) async => reports.add(report);
}

void main() {
  late ApiHarness h;
  late HttpTenantRepository repo;
  late List<String> logLines;
  late _RecordingReporter reporter;

  setUp(() {
    h = ApiHarness();
    logLines = [];
    reporter = _RecordingReporter();
    repo = HttpTenantRepository(h.api, log: logLines.add, crashReporter: reporter, isRelease: true);
  });

  test('lists the ISP directory without authentication', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, fixture('tenants.json')));
    final tenants = (await repo.listTenants()).getOrElse((f) => throw StateError(f.message)).tenants;
    expect(tenants.map((t) => t.slug), ['sentech', 'acme-wifi']);
    expect(tenants[1].isReseller, isTrue);
    expect(tenants[1].branding.primaryColor, const Color(0xFF123456));
    expect(tenants[1].branding.logoUrl, Uri.parse('https://cdn.example.test/acme.png'));
    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('follows next_cursor so more than one page of ISPs is not truncated (bounded)', () async {
    Map<String, Object?> t(String slug) => {'slug': slug, 'name': slug, 'type': 'operator', 'branding': <String, Object?>{}};
    h.adapter.on('GET', '/v1/tenants', (r) {
      return switch (r.uri.queryParameters['cursor']) {
        null => FakeReply(200, {'tenants': [t('aa')], 'next_cursor': 'c2'}),
        'c2' => FakeReply(200, {'tenants': [t('bb')], 'next_cursor': 'c3'}),
        _ => FakeReply(200, {'tenants': [t('cc')], 'next_cursor': null}),
      };
    });
    final tenants = (await repo.listTenants()).getOrElse((f) => throw StateError(f.message)).tenants;
    expect(tenants.map((x) => x.slug), ['aa', 'bb', 'cc']);

    // A server that never stops (or repeats a cursor) is cut off.
    h.adapter.requests.clear();
    h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, {'tenants': [t('aa')], 'next_cursor': 'same'}));
    expect((await repo.listTenants()).isRight(), isTrue);
    expect(h.adapter.requestsTo('GET', '/v1/tenants').length, lessThanOrEqualTo(2));
  });

  test('loads app-config for the chosen tenant', () async {
    h.adapter.on('GET', '/v1/app-config', (_) => FakeReply(200, fixture('app_config.json')));
    final config = (await repo.getAppConfig('acme-wifi')).getOrElse((f) => throw StateError(f.message));
    expect(h.adapter.requests.single.uri.queryParameters, {'tenant': 'acme-wifi'});
    expect(config.tenant.name, 'Acme Wi-Fi');
    expect(config.featureFlags, const FeatureFlags(hotspotPasses: true, rica: false, cpe: false, vouchers: true));
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

  group('slug validation', () {
    Map<String, Object?> tenantJson(Object? slug) => {'slug': slug, 'name': 'X', 'type': 'operator'};

    test('well-formed slugs are accepted', () {
      for (final slug in ['sentech', 'acme-wifi', 'a1', 'a' * 40]) {
        expect(Tenant.fromJson(tenantJson(slug)).slug, slug);
      }
    });

    test('malformed, missing or wrong-typed slugs throw FormatException', () {
      for (final slug in ['A', 'a', 'a' * 41, 'a b', 'a_b', '../x', 'ACME', 'a/b', '', 'é-é', null, 7, true, ['a']]) {
        expect(() => Tenant.fromJson(tenantJson(slug)), throwsFormatException, reason: '$slug');
      }
      expect(() => Tenant.fromJson({'name': 'X', 'type': 'operator'}), throwsFormatException);
    });

    test('app-config validates the nested tenant slug', () {
      final json = fixtureMap('app_config.json');
      final tenant = Map<String, Object?>.from(json['tenant']! as Map);
      for (final slug in ['Bad Slug', null, 42]) {
        expect(() => AppConfig.fromJson({...json, 'tenant': {...tenant, 'slug': slug}}), throwsFormatException);
      }
    });

    test('a response for a different tenant than requested is rejected', () async {
      h.adapter.on('GET', '/v1/app-config', (_) => FakeReply(200, fixture('app_config.json')));
      final result = await repo.getAppConfig('sentech'); // the fixture describes acme-wifi
      expect(result.match((f) => f, (_) => null), isA<ServerFailure>());
    });

    test('a response with a malformed slug is a ServerFailure', () async {
      final body = fixtureMap('app_config.json');
      body['tenant'] = {...(body['tenant']! as Map), 'slug': '../etc'};
      h.adapter.on('GET', '/v1/app-config', (_) => FakeReply(200, body));
      expect((await repo.getAppConfig('../etc')).match((f) => f, (_) => null), isA<ServerFailure>());
    });
  });

  group('tenant field limits', () {
    test('empty or over-long name/type are rejected', () {
      Map<String, Object?> json({String name = 'X', String type = 'operator'}) =>
          {'slug': 'sentech', 'name': name, 'type': type};
      expect(() => Tenant.fromJson(json(name: '')), throwsFormatException);
      expect(() => Tenant.fromJson(json(type: '')), throwsFormatException);
      expect(() => Tenant.fromJson(json(name: 'n' * 81)), throwsFormatException);
      expect(() => Tenant.fromJson(json(type: 't' * 81)), throwsFormatException);
      expect(Tenant.fromJson(json(name: 'n' * 80, type: 't' * 80)).name.length, 80);
    });

    test('wrong-typed name or type is rejected', () {
      expect(() => Tenant.fromJson({'slug': 'sentech', 'name': 5, 'type': 'operator'}), throwsFormatException);
      expect(() => Tenant.fromJson({'slug': 'sentech', 'name': 'X', 'type': null}), throwsFormatException);
    });
  });

  group('directory is fail-closed per entry, not per list', () {
    test('a malformed entry is skipped and the rest are listed', () async {
      final good = (fixtureMap('tenants.json')['tenants']! as List).cast<Map<String, Object?>>();
      h.adapter.on(
        'GET',
        '/v1/tenants',
        (_) => FakeReply(200, {
          'tenants': [
            good[0],
            {'slug': 'Bad Slug', 'name': 'Evil', 'type': 'operator'},
            {'name': 'No slug', 'type': 'operator'},
            'not-an-object',
            good[1],
          ],
        }),
      );
      final directory = (await repo.listTenants()).getOrElse((f) => throw StateError(f.message));
      expect(directory.tenants.map((t) => t.slug), ['sentech', 'acme-wifi']);
      expect(directory.skipped, 3);
      expect(directory.isIncomplete, isTrue);
      // A count only: never the skipped entries themselves.
      expect(logLines, ['tenant directory: skipped 3 malformed entries']);
    });

    Future<void> listWithOneBadEntry(HttpTenantRepository repo) async {
      final good = (fixtureMap('tenants.json')['tenants']! as List).cast<Map<String, Object?>>();
      h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, {'tenants': [good[0], {'slug': 'Secret Bad Slug', 'name': 'Evil', 'type': 'x'}]}));
      await repo.listTenants();
    }

    test('in release the skipped count is reported as a NON-fatal crash report (count only)', () async {
      await listWithOneBadEntry(repo);
      expect(reporter.reports, hasLength(1));
      final report = reporter.reports.single;
      expect(report.fatal, isFalse);
      expect(report.message, contains('skipped 1'));
      expect('${report.message} ${report.reason}', isNot(contains('Secret')));
    });

    test('outside release nothing is sent to the crash reporter', () async {
      await listWithOneBadEntry(HttpTenantRepository(h.api, log: logLines.add, crashReporter: reporter, isRelease: false));
      expect(reporter.reports, isEmpty);
    });

    test('a clean directory is not reported and is complete', () async {
      h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, fixture('tenants.json')));
      final directory = (await repo.listTenants()).getOrElse((f) => throw StateError(f.message));
      expect(directory.skipped, 0);
      expect(directory.isIncomplete, isFalse);
      expect(reporter.reports, isEmpty);
    });

    test('a directory where nothing is usable is a ServerFailure', () async {
      h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, {'tenants': [{'slug': 'X'}, 5]}));
      expect((await repo.listTenants()).match((f) => f, (_) => null), isA<ServerFailure>());
    });

    test('an empty directory is an empty list, not an error', () async {
      h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, {'tenants': <Object?>[]}));
      expect((await repo.listTenants()).getOrElse((f) => throw StateError(f.message)).tenants, isEmpty);
    });

    test('a wrong-shaped directory body is a ServerFailure', () async {
      for (final body in <Object?>[<Object?>[], {'tenants': 'x'}, {'other': 1}]) {
        h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, body));
        expect((await repo.listTenants()).match((f) => f, (_) => null), isA<ServerFailure>(), reason: '$body');
      }
    });
  });

  group('feature flags fail off', () {
    test('missing or wrong-typed flags are off, never on', () {
      final json = fixtureMap('app_config.json');
      for (final flags in <Map<String, Object?>>[
        {},
        {'hotspot_passes': 'true', 'rica': 1, 'cpe': 'yes'},
        {'hotspot_passes': null, 'rica': [], 'cpe': {}},
        {'hotspot_passes': true},
      ]) {
        final config = AppConfig.fromJson({...json, 'feature_flags': flags});
        expect(config.featureFlags.rica, isFalse, reason: '$flags');
        expect(config.featureFlags.cpe, isFalse, reason: '$flags');
        expect(config.featureFlags.hotspotPasses, flags['hotspot_passes'] == true, reason: '$flags');
      }
    });

    test('a flags object of the wrong type rejects the config', () {
      final json = fixtureMap('app_config.json');
      expect(() => AppConfig.fromJson({...json, 'feature_flags': 'all'}), throwsFormatException);
    });
  });

  group('app-config garbage is a ServerFailure through the repository', () {
    test('bodies that are not a valid config', () async {
      final good = fixtureMap('app_config.json');
      final bodies = <Object?>[
        <Object?>[],
        'text',
        {...good, 'tenant': 'acme-wifi'},
        {...good, 'min_app_version': 1},
        {...good, 'legal': {'terms': 1}},
        {...good}..remove('feature_flags'),
      ];
      for (final body in bodies) {
        h.adapter.on('GET', '/v1/app-config', (_) => FakeReply(200, body));
        expect((await repo.getAppConfig('acme-wifi')).match((f) => f, (_) => null), isA<ServerFailure>(), reason: '$body');
      }
    });
  });

  group('branding logo_url', () {
    Uri? logo(String url) => TenantBranding.fromJson({'logo_url': url}).logoUrl;

    test('only plain https URLs with a host are accepted', () {
      expect(logo('https://cdn.example.test/a.png'), Uri.parse('https://cdn.example.test/a.png'));
      for (final bad in [
        'https:///x',
        'https://u:p@host.test/logo.png',
        'https://user@host.test/logo.png',
        'javascript:alert(1)',
        'data:image/png;base64,AAAA',
        'http://host.test/logo.png',
        'ftp://host.test/logo.png',
        '//host.test/logo.png',
        '/logo.png',
        '',
        'https://host.test/${'a' * 2048}',
      ]) {
        expect(logo(bad), isNull, reason: bad);
      }
    });

    test('a URL of exactly 2048 characters is accepted, one more is not', () {
      const prefix = 'https://host.test/';
      expect(logo(prefix + 'a' * (2048 - prefix.length)), isNotNull);
      expect(logo(prefix + 'a' * (2049 - prefix.length)), isNull);
    });

    test('a wrong-typed logo or colour is ignored', () {
      final b = TenantBranding.fromJson({'logo_url': 5, 'primary_color': 7});
      expect(b.logoUrl, isNull);
      expect(b.primaryColor, isNull);
    });
  });
}
