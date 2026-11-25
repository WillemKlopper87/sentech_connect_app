import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/data/pending_lead_keys.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/notify_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/withdrawal_cubit.dart';

import 'fake_coverage_repository.dart';

NotifyRequest _request({String contact = '0821234567', bool arrival = false}) => NotifyRequest(
  contactType: ContactKind.phone,
  contactValue: contact,
  addressText: '12 Lifalethu Avenue, eMbalenhle',
  lat: -26.514,
  lon: 29.103,
  technologyInterest: TechnologyInterest.any,
  waitlistConsentVersion: '2026-10-01',
  arrivalConsentGranted: arrival,
  arrivalConsentVersion: '2026-11-18',
);

void main() {
  late FakeCoverageRepository repo;
  late PendingLeadKeys pending;
  var counter = 0;

  setUp(() {
    repo = FakeCoverageRepository();
    pending = PendingLeadKeys();
    counter = 0;
  });

  NotifyCubit make() => NotifyCubit(repo, newKey: () => 'key-${++counter}', pending: pending, scope: 'sentech');

  group('NotifyCubit', () {
    test('a_double_tap_sends_one_request', () async {
      repo.leadGate = Completer<void>();
      final cubit = make();
      final first = cubit.submit(_request());
      final second = cubit.submit(_request());
      expect(cubit.state.status, NotifyStatus.submitting);
      repo.leadGate!.complete();
      await Future.wait([first, second]);
      expect(repo.leadCalls, hasLength(1));
      expect(cubit.state.status, NotifyStatus.done);
      await cubit.close();
    });

    test('a_retry_after_an_unknown_outcome_reuses_the_key', () async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(NetworkFailure()), const Right(unit)]);
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.status, NotifyStatus.failed);
      expect(cubit.state.outcomeUnknown, isTrue);
      await cubit.submit(_request());
      expect(repo.leadCalls.map((c) => c.key), ['key-1', 'key-1']);
      expect(cubit.state.status, NotifyStatus.done);
      // After a final answer the next attempt starts a new key.
      await cubit.submit(_request());
      expect(repo.leadCalls.last.key, 'key-2');
      await cubit.close();
    });

    test('a retry with a different request (the contact was edited) is a new request with a new key', () async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(NetworkFailure()), const Right(unit)]);
      final cubit = make();
      await cubit.submit(_request(contact: '0821234567'));
      await cubit.submit(_request(contact: '0831112222'));
      expect(repo.leadCalls.map((c) => c.key), ['key-1', 'key-2'], reason: 'the server refuses one key for two different requests');
      await cubit.close();
    });

    test('a final refusal drops the key, an unknown outcome keeps it, and each is remembered across a reopen', () async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(InvalidContactFailure()), const Left(ServerFailure()), const Right(unit)]);
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.outcomeUnknown, isFalse);
      expect(pending.pendingFor('sentech'), isNull);
      await cubit.submit(_request());
      expect(cubit.state.outcomeUnknown, isTrue);
      expect(pending.pendingFor('sentech')?.key, 'key-2');
      await cubit.close();
      // The sheet is opened again after the response was lost: the same request reuses the same key.
      final reopened = make();
      expect(reopened.state.outcomeUnknown, isTrue, reason: 'tells the sheet a last attempt may have gone through');
      await reopened.submit(_request());
      expect(repo.leadCalls.last.key, 'key-2');
      expect(pending.pendingFor('sentech'), isNull);
      await reopened.close();
    });

    test('every outcome the app cannot know keeps the key: network, server, still processing, rate limit, security check down', () async {
      for (final failure in <Failure>[
        const NetworkFailure(),
        const ServerFailure(),
        const IdempotencyInProgressFailure(),
        const RateLimitedFailure(),
        const HumanVerificationUnavailableFailure(),
      ]) {
        repo.leadResults
          ..clear()
          ..add(Left(failure));
        pending.clear();
        final cubit = make();
        await cubit.submit(_request());
        expect(cubit.state.outcomeUnknown, isTrue, reason: '$failure');
        await cubit.close();
      }
    });

    test('a customer who backs out of the security check sent nothing: no key is kept', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(HumanCheckCancelledFailure()));
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.outcomeUnknown, isFalse);
      expect(pending.pendingFor('sentech'), isNull);
      await cubit.close();
    });

    test('the_contact_is_cleared_after_success', () async {
      final cubit = make();
      await cubit.submit(_request(contact: '0821234567'));
      expect(cubit.state.status, NotifyStatus.done);
      expect(cubit.state.toString(), isNot(contains('0821234567')));
      expect(cubit.state.props.map((p) => '$p').join(' '), isNot(contains('0821234567')));
      expect(pending.pendingFor('sentech'), isNull);
      // Nothing of the request is kept by the cubit: submitting again needs the whole request again.
      await cubit.close();
    });

    test('a stale consent text is its own failure and asks the screen to read the meta again', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(ConsentVersionOutdatedFailure()));
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.failure, isA<ConsentVersionOutdatedFailure>());
      expect(cubit.state.consentOutdated, isTrue);
      await cubit.close();
    });

    test('dismiss goes back to the form after a refusal, and nothing is emitted after close', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(InvalidContactFailure()));
      repo.leadGate = Completer<void>();
      final cubit = make();
      final pendingSubmit = cubit.submit(_request());
      await cubit.close();
      repo.leadGate!.complete();
      await pendingSubmit;
      final other = make();
      repo.leadGate = null;
      await other.submit(_request());
      other.dismiss();
      expect(other.state.status, NotifyStatus.idle);
      await other.close();
    });
  });

  group('WithdrawalCubit', () {
    test('withdrawal_never_claims_removal_before_the_link', () async {
      final cubit = WithdrawalCubit(repo);
      await cubit.request(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567'));
      // The only success state is "a link was requested": there is no removed state.
      expect(cubit.state.status, WithdrawalStatus.requested);
      expect(WithdrawalStatus.values.map((s) => s.name), isNot(contains('removed')));
      expect(WithdrawalStatus.values.map((s) => s.name), isNot(contains('withdrawn')));
      expect(cubit.state.toString(), isNot(contains('0821234567')));
      expect(repo.withdrawalCalls, hasLength(1));
      await cubit.close();
    });

    test('a double tap sends one request, a failure can be retried, and nothing is emitted after close', () async {
      repo.withdrawalGate = Completer<void>();
      final cubit = WithdrawalCubit(repo);
      const request = WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567');
      final a = cubit.request(request);
      final b = cubit.request(request);
      repo.withdrawalGate!.complete();
      await Future.wait([a, b]);
      expect(repo.withdrawalCalls, hasLength(1));
      repo.withdrawalResult = const Left(NetworkFailure());
      repo.withdrawalGate = null;
      cubit.dismiss();
      await cubit.request(request);
      expect(cubit.state.status, WithdrawalStatus.failed);
      expect(cubit.state.failure, isA<NetworkFailure>());
      repo.withdrawalGate = Completer<void>();
      final late = cubit.request(request);
      await cubit.close();
      repo.withdrawalGate!.complete();
      await late;
    });
  });

  test('the pending keys hold a key and a fingerprint, never the request, and clear on demand', () {
    final keys = PendingLeadKeys()..put('sentech', 12345, 'key-x');
    expect(keys.pendingFor('sentech'), (fingerprint: 12345, key: 'key-x'));
    expect(keys.toString(), isNot(contains('key-x')));
    keys.clear();
    expect(keys.pendingFor('sentech'), isNull);
  });
}
