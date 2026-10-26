import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/diagnostics/pii_scrubber.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_check_controller.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_provider.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/otp_login_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';

import 'contract/openapi_schema.dart';
import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fake_turnstile_surface.dart';
import 'helpers/fixtures.dart';

const _binding = 'Zm9vYmFyYmF6cXV4MTIzNDU2Nzg5MEFCQ0RFRkc';
final _config = TurnstileConfig.resolve(siteKey: '0x4AAAAAAAbcdEFGH', baseUrl: 'https://www.example.co.za', isDebug: false)!;

/// Acts as the customer and the page: either solves with the next token, or cancels.
class _AutoPresenter implements HumanCheckPresenter {
  _AutoPresenter();

  bool cancel = false;
  Object? error;
  var tokens = 0;
  String Function() nextToken = () => testTurnstileToken;

  @override
  Future<void> present(TurnstileCheckController check) async {
    if (error != null) throw error!;
    await Future<void>.delayed(Duration.zero);
    if (cancel) check.cancel();
    await check.result;
  }
}

void main() {
  late ApiHarness h;
  late _AutoPresenter presenter;
  late TurnstileWebViewProvider provider;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    presenter = _AutoPresenter();
    provider = TurnstileWebViewProvider(
      config: _config,
      presenter: presenter,
      surfaceFactory: () => FakeTurnstileSurface()
        ..onLoad = (s) {
          if (!presenter.cancel) {
            presenter.tokens++;
            s.sendRaw('{"t":"token","v":"${presenter.nextToken()}"}');
          }
        },
    );
  });

  HttpAuthRepository authRepo() => HttpAuthRepository(h.api, tokens: h.tokens, tenant: h.tenantContext, humanCheck: provider);

  group('otp/request', () {
    test('sends the Turnstile token exactly as OtpRequestIn wants it', () async {
      h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply(202, fixture('otp_request.json')));
      final result = await authRepo().requestOtp(phoneNumber: '0821234567', binding: _binding);
      expect(result.isRight(), isTrue);
      final body = h.adapter.requests.single.data;
      expect((body as Map)['turnstile_token'], testTurnstileToken);
      final api = OpenApiSnapshot.load();
      expect(api.validate(body, api.schema('OtpRequestIn')), isEmpty);
    });

    test('a resend asks for a NEW token: one check per request, no token reuse', () async {
      h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply(202, fixture('otp_request.json')));
      var n = 0;
      presenter.nextToken = () => 'token-${++n}';
      final repo = authRepo();
      await repo.requestOtp(phoneNumber: '0821234567', binding: _binding);
      await repo.requestOtp(phoneNumber: '0821234567', binding: _binding);
      final sent = h.adapter.requests.map((r) => (r.data as Map)['turnstile_token']).toList();
      expect(sent, ['token-1', 'token-2']);
    });

    test('the customer cancels the check: no request is sent, the typed cancel comes back', () async {
      presenter.cancel = true;
      final result = await authRepo().requestOtp(phoneNumber: '0821234567', binding: _binding);
      expect(result.getLeft().toNullable(), isA<HumanCheckCancelledFailure>());
      expect(h.adapter.requests, isEmpty);
    });

    test('the check cannot run: no request is sent, the existing unavailable failure comes back', () async {
      presenter.error = const HumanCheckUnavailable();
      final result = await authRepo().requestOtp(phoneNumber: '0821234567', binding: _binding);
      expect(result.getLeft().toNullable(), isA<HumanVerificationUnavailableFailure>());
      expect(h.adapter.requests, isEmpty);
    });

    test('the server refusing the token (403) and the verifier being down (503 + Retry-After) stay typed', () async {
      h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply.problem(403, 'human_verification_failed'));
      expect((await authRepo().requestOtp(phoneNumber: '0821234567', binding: _binding)).getLeft().toNullable(), isA<HumanVerificationFailedFailure>());
      h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply.problem(503, 'human_verification_unavailable', headers: {'retry-after': ['45']}));
      expect((await authRepo().requestOtp(phoneNumber: '0821234567', binding: _binding)).getLeft().toNullable(), const HumanVerificationUnavailableFailure(Duration(seconds: 45)));
    });

    test('a bad phone number is refused before any check is shown', () async {
      final result = await authRepo().requestOtp(phoneNumber: '123', binding: _binding);
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(presenter.tokens, 0);
    });
  });

  group('delete-challenge', () {
    test('sends the token as DeleteChallengeIn wants it', () async {
      h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply(200, {'challenge_id': '9d1c5e2a-7b3f-4c8d-a6e1-0f2b4c6d8e1a', 'expires_in_seconds': 300}));
      final repo = HttpPrivacyRepository(h.api, humanCheck: provider);
      await repo.requestDeleteChallenge();
      final body = h.adapter.requestsTo('POST', '/v1/me/delete-challenge').single.data;
      expect(body, {'turnstile_token': testTurnstileToken});
      final api = OpenApiSnapshot.load();
      expect(api.validate(body, api.schema('DeleteChallengeIn')), isEmpty);
    });

    test('cancel sends nothing', () async {
      presenter.cancel = true;
      final result = await HttpPrivacyRepository(h.api, humanCheck: provider).requestDeleteChallenge();
      expect(result.getLeft().toNullable(), isA<HumanCheckCancelledFailure>());
      expect(h.adapter.requests, isEmpty);
    });
  });

  group('the screens', () {
    test('sign-in: cancelling the check goes back to where the customer was, with no error', () async {
      presenter.cancel = true;
      final cubit = OtpLoginCubit(authRepo(), verifier: (c, code) async => throw UnimplementedError());
      addTearDown(cubit.close);
      await cubit.submitPhone('0821234567');
      expect(cubit.state.status, OtpLoginStatus.idle);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.step, OtpStep.phone);
      expect(cubit.state.busy, isFalse);
    });

    test('sign-in: an unavailable check is shown as the typed failure and can be tried again', () async {
      presenter.error = const HumanCheckUnavailable();
      final cubit = OtpLoginCubit(authRepo(), verifier: (c, code) async => throw UnimplementedError());
      addTearDown(cubit.close);
      await cubit.submitPhone('0821234567');
      expect(cubit.state.status, OtpLoginStatus.failure);
      expect(cubit.state.failure, isA<HumanVerificationUnavailableFailure>());
      presenter.error = null;
      h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply(202, fixture('otp_request.json')));
      await cubit.submitPhone('0821234567');
      expect(cubit.state.step, OtpStep.code);
    });

    test('delete account: cancelling the check leaves the dialog as it was, with no error', () async {
      presenter.cancel = true;
      final cubit = PrivacyActionsCubit(HttpPrivacyRepository(h.api, humanCheck: provider), onAccountDeleted: () async {});
      addTearDown(cubit.close);
      await cubit.requestDeleteCode();
      expect(cubit.state.status, PrivacyActionStatus.idle);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.deleteChallenge, isNull);
    });
  });

  group('the token never reaches a log', () {
    test('not in the API client log, not in debugPrint or print, and the scrubber removes it from text', () async {
      final printed = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = oldDebugPrint);
      h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply(202, fixture('otp_request.json')));
      await runZoned(
        () => authRepo().requestOtp(phoneNumber: '0821234567', binding: _binding),
        zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => printed.add(line)),
      );
      expect([...h.logLines, ...printed].join('\n'), isNot(contains('SECRETTOKEN')));

      // And if some message did carry it, the scrubber removes it in the usual shapes.
      for (final text in [
        '{"turnstile_token":"$testTurnstileToken"}',
        'token=$testTurnstileToken',
        '{"token": "$testTurnstileToken"}',
        'channel said $testTurnstileToken',
      ]) {
        expect(PiiScrubber.scrub(text), isNot(contains('SECRETTOKEN')), reason: text);
      }
    });
  });
}
