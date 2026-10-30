import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/security/human_check_config.dart';
import 'package:sentech_connect_app/core/security/human_check_gate.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_check_controller.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_provider.dart' show HumanCheckPresenter;

import 'contract/openapi_schema.dart';
import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

final _build = TurnstileConfig.resolve(siteKey: '0xBUILDKEYAAAA', baseUrl: 'https://build.example.co.za', isDebug: false);

class _Repo implements HumanCheckConfigRepository {
  _Repo(this.answer);
  Either<Failure, HumanCheckConfig> Function(String slug) answer;
  final calls = <String>[];

  @override
  Future<Either<Failure, HumanCheckConfig>> fetch(String tenantSlug) async {
    calls.add(tenantSlug);
    return answer(tenantSlug);
  }
}

HumanCheckConfig _cfg({String? key = '0xAPIKEYAAAAAA', String? base = 'https://www.example.co.za', bool otp = true, bool del = true, bool support = true}) =>
    HumanCheckConfig(siteKey: key, baseUrl: base, otpRequestRequired: otp, deleteChallengeRequired: del, supportMessageRequired: support, leadRequired: true);

class _Provider implements HumanCheckProvider {
  _Provider(this.config);
  final TurnstileConfig config;
  @override
  Future<String?> token() async => 'tok-${config.siteKey}-${config.action}';
}

class _Throwing implements HumanCheckConfigRepository {
  @override
  Future<Either<Failure, HumanCheckConfig>> fetch(String tenantSlug) => throw StateError('boom');
}

class _NoPresenter implements HumanCheckPresenter {
  @override
  Future<void> present(TurnstileCheckController check) async {}
}

void main() {
  late _Repo repo;
  late TenantContext tenant;
  late DateTime now;

  HumanCheckGate gate({TurnstileConfig? build}) => HumanCheckGate(
    repository: repo,
    tenant: tenant,
    presenter: _NoPresenter(),
    buildConfig: build,
    now: () => now,
    isDebug: false,
    providerFactory: _Provider.new,
  );

  setUp(() {
    repo = _Repo((_) => Right(_cfg()));
    tenant = TenantContext(slug: 'sentech');
    now = DateTime.utc(2026, 10, 30, 12);
  });

  test('the API wins over the build defines, with the action of the request', () async {
    final g = gate(build: _build);
    expect(await g.forAction(HumanCheckAction.otpRequest).token(), 'tok-0xAPIKEYAAAAAA-signin');
    expect(await g.forAction(HumanCheckAction.supportMessage).token(), 'tok-0xAPIKEYAAAAAA-support');
  });

  test('the config is cached per tenant for the TTL, then asked again', () async {
    final g = gate();
    await g.forAction(HumanCheckAction.otpRequest).token();
    await g.forAction(HumanCheckAction.deleteChallenge).token();
    expect(repo.calls, ['sentech']);
    tenant.slug = 'acme';
    await g.forAction(HumanCheckAction.otpRequest).token();
    expect(repo.calls, ['sentech', 'acme']);
    tenant.slug = 'sentech';
    await g.forAction(HumanCheckAction.otpRequest).token();
    expect(repo.calls, ['sentech', 'acme'], reason: 'still cached');
    now = now.add(const Duration(seconds: 61));
    await g.forAction(HumanCheckAction.otpRequest).token();
    expect(repo.calls, ['sentech', 'acme', 'sentech']);
  });

  test('concurrent first checks share one request', () async {
    final g = gate();
    await Future.wait([g.forAction(HumanCheckAction.otpRequest).token(), g.forAction(HumanCheckAction.supportMessage).token()]);
    expect(repo.calls, hasLength(1));
  });

  test('required=false skips the check for that action only', () async {
    repo.answer = (_) => Right(_cfg(otp: false, del: false));
    final g = gate();
    expect(await g.forAction(HumanCheckAction.otpRequest).token(), isNull);
    expect(await g.forAction(HumanCheckAction.deleteChallenge).token(), isNull);
    expect(await g.forAction(HumanCheckAction.supportMessage).token(), isNotNull);
  });

  test('site_key null (fake verifier): no token, even with build defines', () async {
    repo.answer = (_) => Right(_cfg(key: null, base: null));
    final g = gate(build: _build);
    expect(await g.forAction(HumanCheckAction.otpRequest).token(), isNull);
    expect(await g.forAction(HumanCheckAction.supportMessage).token(), isNull);
  });

  test('route failed: the build defines apply; without them no token', () async {
    repo.answer = (_) => const Left(NetworkFailure());
    expect(await gate(build: _build).forAction(HumanCheckAction.otpRequest).token(), 'tok-0xBUILDKEYAAAA-signin');
    expect(await gate().forAction(HumanCheckAction.otpRequest).token(), isNull);
  });

  test('a failed answer is remembered briefly (no request per check), then retried', () async {
    repo.answer = (_) => const Left(NetworkFailure());
    final g = gate(build: _build);
    await g.forAction(HumanCheckAction.otpRequest).token();
    await g.forAction(HumanCheckAction.otpRequest).token();
    expect(repo.calls, hasLength(1));
    now = now.add(const Duration(seconds: 16));
    repo.answer = (_) => Right(_cfg());
    expect(await g.forAction(HumanCheckAction.otpRequest).token(), 'tok-0xAPIKEYAAAAAA-signin');
  });

  test('values from the API the app cannot use fall back to the build', () async {
    repo.answer = (_) => Right(_cfg(base: 'http://insecure.example.co.za'));
    expect(await gate(build: _build).forAction(HumanCheckAction.otpRequest).token(), 'tok-0xBUILDKEYAAAA-signin');
  });

  test('a repository that throws counts as a failed route', () async {
    final g = HumanCheckGate(
      repository: _Throwing(),
      tenant: tenant,
      presenter: _NoPresenter(),
      buildConfig: _build,
      isDebug: false,
      providerFactory: _Provider.new,
    );
    expect(await g.forAction(HumanCheckAction.otpRequest).token(), 'tok-0xBUILDKEYAAAA-signin');
  });

  group('HttpHumanCheckConfigRepository', () {
    late ApiHarness h;
    setUp(() => h = ApiHarness());

    test('GET with the tenant query, no Authorization, decodes the contract fixture', () async {
      h.adapter.on('GET', '/v1/auth/human-check/config', (_) => FakeReply(200, fixture('human_check_config.json')));
      await h.signIn(); // even signed in, the public route is called without the token
      final result = await HttpHumanCheckConfigRepository(h.api).fetch('acme');
      final c = result.getOrElse((f) => throw StateError(f.message));
      expect(c.siteKey, '0x4AAAAAAAbcdEFGH');
      expect(c.baseUrl, 'https://www.example.co.za');
      expect(c.requires(HumanCheckAction.supportMessage), isTrue);
      final sent = h.adapter.requests.single;
      expect(sent.uri.queryParameters, {'tenant': 'acme'});
      expect(sent.headers.containsKey('Authorization'), isFalse);
      final api = OpenApiSnapshot.load();
      expect(api.validate(fixture('human_check_config.json'), api.schema('HumanCheckConfig')), isEmpty);
    });

    test('the no-widget fixture decodes to nulls and per-action flags', () async {
      h.adapter.on('GET', '/v1/auth/human-check/config', (_) => FakeReply(200, fixture('human_check_config_no_widget.json')));
      final c = (await HttpHumanCheckConfigRepository(h.api).fetch('sentech')).getOrElse((f) => throw StateError(f.message));
      expect(c.siteKey, isNull);
      expect(c.baseUrl, isNull);
      expect(c.requires(HumanCheckAction.otpRequest), isFalse);
      expect(c.requires(HumanCheckAction.deleteChallenge), isFalse);
      expect(c.requires(HumanCheckAction.supportMessage), isTrue);
    });

    test('404 tenant_not_found is a Left, not a throw', () async {
      h.adapter.on('GET', '/v1/auth/human-check/config', (_) => FakeReply.problem(404, 'tenant_not_found'));
      expect((await HttpHumanCheckConfigRepository(h.api).fetch('nope')).isLeft(), isTrue);
    });
  });
}
