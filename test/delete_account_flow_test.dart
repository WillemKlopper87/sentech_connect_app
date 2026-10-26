import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/features/account/presentation/widgets/delete_account_dialog.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'contract/openapi_schema.dart';
import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _challengeId = '9d1c5e2a-7b3f-4c8d-a6e1-0f2b4c6d8e1a';

class _FixedHumanCheck implements HumanCheckProvider {
  @override
  Future<String?> token() async => 'human-token-for-this-request';
}

Stream<int> _instantTicker(int seconds) => Stream.fromIterable([for (var i = seconds - 1; i >= 0; i--) i]);

void main() {
  late ApiHarness h;
  late HttpPrivacyRepository repo;
  late int wiped;
  late PrivacyActionsCubit cubit;
  late StreamController<int> ticks;
  late List<void> expiries;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpPrivacyRepository(h.api, now: () => h.now);
    wiped = 0;
    ticks = StreamController<int>.broadcast();
    expiries = [];
    h.events.expired.listen(expiries.add);
    cubit = PrivacyActionsCubit(repo, onAccountDeleted: () async => wiped++, ticker: (_) => ticks.stream);
    addTearDown(() async {
      await cubit.close();
      await ticks.close();
    });
    h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply(202, fixture('delete_challenge.json')));
  });

  group('HttpPrivacyRepository', () {
    test('requestDeleteChallenge posts without a body and reads challenge, wait and reference', () async {
      final challenge = (await repo.requestDeleteChallenge()).getOrElse((f) => throw StateError(f.message));
      expect(challenge.challengeId, _challengeId);
      expect(challenge.expiresIn, const Duration(minutes: 5));
      expect(challenge.reference, 'K7QM');
      final sent = h.adapter.requestsTo('POST', '/v1/me/delete-challenge').single;
      expect(sent.headers['Authorization'], 'Bearer access-1');
      expect(sent.data, isNull, reason: 'the human-check token is not sent yet (M2)');
    });

    test('the human-check seam: a provider that has a token adds turnstile_token, schema-valid', () async {
      final withCheck = HttpPrivacyRepository(h.api, humanCheck: _FixedHumanCheck());
      await withCheck.requestDeleteChallenge();
      final body = h.adapter.requestsTo('POST', '/v1/me/delete-challenge').single.data;
      expect(body, {'turnstile_token': 'human-token-for-this-request'});
      final api = OpenApiSnapshot.load();
      expect(api.validate(body, api.schema('DeleteChallengeIn')), isEmpty);
    });

    test('the DELETE body matches DeleteAccountIn and the call is not repeated for a malformed code', () async {
      h.adapter.on('DELETE', '/v1/me', (_) => const FakeReply(204));
      await repo.deleteAccount(challengeId: _challengeId, code: '123456');
      final api = OpenApiSnapshot.load();
      final sent = h.adapter.requestsTo('DELETE', '/v1/me').single;
      expect(api.validate(sent.data, api.schema('DeleteAccountIn')), isEmpty);
      expect(sent.headers['Content-Type'].toString(), contains('application/json'));

      final bad = await repo.deleteAccount(challengeId: _challengeId, code: '12ab');
      expect((bad.getLeft().toNullable()! as ValidationFailure).code, 'invalid_code');
      expect(h.adapter.requestsTo('DELETE', '/v1/me'), hasLength(1));
    });

    test('a 401 from delete-challenge (no phone on the account) does not sign the customer out', () async {
      h.adapter
        ..on('POST', '/v1/me/delete-challenge', (_) => FakeReply.problem(401, 'invalid_token'))
        ..on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
      final failure = (await repo.requestDeleteChallenge()).getLeft().toNullable();
      expect(failure, isA<DeleteCodeUnavailableFailure>());
      expect(expiries, isEmpty);
      expect(await h.tokens.read(), isNotNull, reason: 'the session is still there');
    });

    test('whereas a 401 on another call with a fresh token ends the session', () async {
      h.adapter
        ..on('GET', '/v1/me/export', (_) => FakeReply.problem(401, 'invalid_token'))
        ..on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
      await repo.requestDataExport();
      await Future<void>.delayed(Duration.zero);
      expect(expiries, hasLength(1));
    });

    test('a dead session (refresh rejected) is still signed out on delete-challenge', () async {
      h.adapter
        ..on('POST', '/v1/me/delete-challenge', (_) => FakeReply.problem(401, 'invalid_token'))
        ..on('POST', '/v1/auth/token/refresh', (_) => FakeReply.problem(401, 'invalid_refresh_token'));
      await repo.requestDeleteChallenge();
      await Future<void>.delayed(Duration.zero);
      expect(expiries, hasLength(1));
      expect(await h.tokens.read(), isNull);
    });
  });

  group('PrivacyActionsCubit: delete in two steps', () {
    test('success: the code is sent, then the account is deleted and only then wiped', () async {
      h.adapter.on('DELETE', '/v1/me', (_) => const FakeReply(204));
      await cubit.requestDeleteCode();
      expect(cubit.state.status, PrivacyActionStatus.deleteCodeSent);
      expect(cubit.state.deleteChallenge!.reference, 'K7QM');
      expect(wiped, 0);
      expect(await cubit.deleteAccount('123456'), isTrue);
      expect(cubit.state.status, PrivacyActionStatus.deleted);
      expect(wiped, 1);
      expect(h.adapter.requestsTo('DELETE', '/v1/me').single.data, {'challenge_id': _challengeId, 'code': '123456'});
    });

    test('403 reauth_required: nothing wiped, the code step stays open for another try', () async {
      var attempts = 0;
      h.adapter.on('DELETE', '/v1/me', (_) => ++attempts == 1 ? FakeReply.problem(403, 'reauth_required') : const FakeReply(204));
      await cubit.requestDeleteCode();
      expect(await cubit.deleteAccount('111111'), isFalse);
      expect(cubit.state.failure, isA<ReauthRequiredFailure>());
      expect(cubit.state.deleteChallenge, isNotNull);
      expect(wiped, 0);
      expect(await cubit.deleteAccount('222222'), isTrue);
      expect(wiped, 1);
    });

    test('409 active_service_exists: explained, nothing wiped, no retry offered', () async {
      h.adapter.on('DELETE', '/v1/me', (_) => FakeReply.problem(409, 'active_service_exists', detail: 'You have a live service.'));
      await cubit.requestDeleteCode();
      expect(await cubit.deleteAccount('123456'), isFalse);
      expect(cubit.state.failure, isA<ActiveServiceExistsFailure>());
      expect(cubit.state.deleteBlocked, isTrue);
      expect(wiped, 0);
    });

    test('401 from delete-challenge: contact support, still signed in, nothing wiped', () async {
      h.adapter
        ..on('POST', '/v1/me/delete-challenge', (_) => FakeReply.problem(401, 'invalid_token'))
        ..on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
      await cubit.requestDeleteCode();
      expect(cubit.state.status, PrivacyActionStatus.failed);
      expect(cubit.state.failure, isA<DeleteCodeUnavailableFailure>());
      expect(cubit.state.deleteBlocked, isTrue);
      expect(expiries, isEmpty);
      expect(wiped, 0);
    });

    test('429 on the code request locks resend for the server wait, then unlocks', () async {
      h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply.problem(429, 'rate_limited', headers: {
            'retry-after': ['120'],
          }));
      await cubit.requestDeleteCode();
      expect(cubit.state.failure, isA<RateLimitedFailure>());
      expect(cubit.state.rateLimited, isTrue);
      expect(cubit.state.resendIn, 120);
      expect(cubit.state.locked, isTrue);
      final calls = h.adapter.requestsTo('POST', '/v1/me/delete-challenge').length;
      await cubit.requestDeleteCode(); // ignored while locked
      expect(h.adapter.requestsTo('POST', '/v1/me/delete-challenge'), hasLength(calls));
      ticks.add(60);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendIn, 60);
      expect(cubit.state.locked, isTrue);
      ticks.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.locked, isFalse);
      h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply(202, fixture('delete_challenge.json')));
      await cubit.requestDeleteCode();
      expect(cubit.state.status, PrivacyActionStatus.deleteCodeSent);
    });

    test('429 while deleting also locks, and nothing is wiped', () async {
      h.adapter.on('DELETE', '/v1/me', (_) => FakeReply.problem(429, 'rate_limited', headers: {
            'retry-after': ['10'],
          }));
      await cubit.requestDeleteCode();
      expect(await cubit.deleteAccount('123456'), isFalse);
      expect(cubit.state.resendIn, 30, reason: 'never less than the resend cooldown');
      expect(cubit.state.locked, isTrue);
      expect(await cubit.deleteAccount('123456'), isFalse);
      expect(h.adapter.requestsTo('DELETE', '/v1/me'), hasLength(1), reason: 'locked: no second call');
      expect(wiped, 0);
    });

    test('resend waits for the cooldown, then asks for a new code', () async {
      await cubit.requestDeleteCode();
      expect(cubit.state.resendIn, 30);
      ticks.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendIn, 0);
      await cubit.requestDeleteCode();
      expect(h.adapter.requestsTo('POST', '/v1/me/delete-challenge'), hasLength(2));
    });

    test('503 sms_unavailable is a typed failure and keeps nothing half-done', () async {
      h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply.problem(503, 'sms_unavailable'));
      await cubit.requestDeleteCode();
      expect(cubit.state.failure, isA<SmsUnavailableFailure>());
      expect(cubit.state.deleteChallenge, isNull);
    });

    test('a malformed code is rejected locally without a request', () async {
      await cubit.requestDeleteCode();
      expect(await cubit.deleteAccount('12 34'), isFalse);
      expect((cubit.state.failure! as ValidationFailure).code, 'invalid_code');
      expect(h.adapter.requestsTo('DELETE', '/v1/me'), isEmpty);
    });

    test('offline delete keeps the account and the device data', () async {
      h.adapter.on('DELETE', '/v1/me', (_) => const FakeReply.error(DioExceptionType.connectionTimeout));
      await cubit.requestDeleteCode();
      expect(await cubit.deleteAccount('123456'), isFalse);
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(wiped, 0);
    });

    test('cancelDelete forgets the challenge', () async {
      await cubit.requestDeleteCode();
      cubit.cancelDelete();
      expect(cubit.state, const PrivacyActionsState());
    });
  });

  group('delete dialog', () {
    Future<void> pump(WidgetTester tester, PrivacyRepository repository, {Future<void> Function()? onDeleted}) async {
      final c = PrivacyActionsCubit(repository, onAccountDeleted: onDeleted ?? () async => wiped++, ticker: _instantTicker);
      addTearDown(c.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: c,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(onPressed: () => showDeleteAccountDialog(context), child: const Text('open')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('no phone on the account: explains, offers only Close, deletes nothing', (tester) async {
      await pump(tester, _ScriptedPrivacy(challenge: const Left(DeleteCodeUnavailableFailure())));
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Contact support to delete your account'), findsOneWidget);
      expect(find.text('Send me a code'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(wiped, 0);
    });

    testWidgets('an active service is explained inside the dialog', (tester) async {
      await pump(
        tester,
        _ScriptedPrivacy(
          challenge: const Right(DeleteChallenge(challengeId: 'c1', expiresIn: Duration(minutes: 5), reference: 'AB12')),
          delete: const Left(ActiveServiceExistsFailure()),
        ),
      );
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cancel it first, or contact your provider'), findsOneWidget);
      expect(wiped, 0);
    });

    testWidgets('success closes the dialog after the wipe', (tester) async {
      await pump(
        tester,
        _ScriptedPrivacy(
          challenge: const Right(DeleteChallenge(challengeId: 'c1', expiresIn: Duration(minutes: 5), reference: 'AB12')),
          delete: Right(PrivacyRequestReceipt(reference: 'DEL-1', requestedAt: DateTime.utc(2026))),
        ),
      );
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();
      expect(find.text('Use the SMS that shows reference AB12.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      expect(wiped, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

class _ScriptedPrivacy implements PrivacyRepository {
  _ScriptedPrivacy({required this.challenge, this.delete});

  final Either<Failure, DeleteChallenge> challenge;
  final Either<Failure, PrivacyRequestReceipt>? delete;

  @override
  Future<Either<Failure, DeleteChallenge>> requestDeleteChallenge() async => challenge;

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> deleteAccount({required String challengeId, required String code}) async =>
      delete ?? const Left(ReauthRequiredFailure());

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport() async => const Left(NetworkFailure());
}
