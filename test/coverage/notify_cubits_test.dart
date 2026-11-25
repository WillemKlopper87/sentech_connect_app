import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/data/pending_lead_keys.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/notify_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/withdrawal_cubit.dart';

import 'fake_coverage_repository.dart';

NotifyRequest _request({String contact = '0821234567', bool arrival = false, double lat = -26.514}) => NotifyRequest(
  contactType: ContactKind.phone,
  contactValue: contact,
  addressText: '12 Lifalethu Avenue, eMbalenhle',
  lat: lat,
  lon: 29.103,
  technologyInterest: TechnologyInterest.any,
  waitlistConsentVersion: '2026-10-01',
  arrivalConsentGranted: arrival,
  arrivalConsentVersion: '2026-11-18',
);

const _scope = 'sentech|-26.51400,29.10300|any';

void main() {
  late FakeCoverageRepository repo;
  late PendingLeadKeys pending;
  var counter = 0;
  var clock = DateTime.utc(2026, 11, 26, 10);

  setUp(() {
    repo = FakeCoverageRepository();
    pending = PendingLeadKeys();
    counter = 0;
    clock = DateTime.utc(2026, 11, 26, 10);
  });

  NotifyCubit make({String scope = _scope}) =>
      NotifyCubit(repo, newKey: () => 'key-${++counter}', pending: pending, scope: scope, now: () => clock);

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
      await cubit.submit(_request());
      expect(repo.leadCalls.last.key, 'key-2', reason: 'after a final answer the next attempt starts a new key');
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

    test('a final refusal drops the key, an unknown outcome keeps it, and it is remembered across a reopen', () async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(InvalidContactFailure()), const Left(ServerFailure()), const Right(unit)]);
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.outcomeUnknown, isFalse);
      expect(pending.pendingFor(_scope), isNull);
      await cubit.submit(_request());
      expect(cubit.state.outcomeUnknown, isTrue);
      expect(pending.pendingFor(_scope)?.key, 'key-2');
      await cubit.close();
      final reopened = make();
      expect(reopened.state.outcomeUnknown, isTrue, reason: 'tells the sheet a last attempt may have gone through');
      await reopened.submit(_request());
      expect(repo.leadCalls.last.key, 'key-2');
      expect(pending.pendingFor(_scope), isNull);
      await reopened.close();
    });

    test('the key is stored BEFORE the request, so closing mid-request and reopening reuses it', () async {
      repo.leadGate = Completer<void>();
      repo.leadResults
        ..clear()
        ..addAll([const Left(NetworkFailure()), const Right(unit)]);
      final cubit = make();
      final inFlight = cubit.submit(_request());
      expect(pending.pendingFor(_scope)?.key, 'key-1', reason: 'kept from the moment the request is sent');
      await cubit.close();
      // Reopened while the first request is still in flight: it is unresolved, and its key is the one to reuse.
      expect(make().state.outcomeUnknown, isTrue);
      repo.leadGate!.complete();
      await inFlight;
      // The answer was a lost response (a network failure): the key stays even though the cubit was closed.
      repo.leadGate = null;
      expect(pending.pendingFor(_scope)?.key, 'key-1');
      final reopened = make();
      expect(reopened.state.outcomeUnknown, isTrue);
      await reopened.submit(_request());
      expect(repo.leadCalls.last.key, 'key-1');
      expect(pending.pendingFor(_scope), isNull);
      await reopened.close();
    });

    test('a success or a final refusal that arrives after the cubit was closed still removes the key', () async {
      for (final answer in <Either<Failure, Unit>>[const Right(unit), const Left(InvalidContactFailure())]) {
        pending.clear();
        repo.leadGate = Completer<void>();
        repo.leadResults
          ..clear()
          ..add(answer);
        final cubit = make();
        final inFlight = cubit.submit(_request());
        await cubit.close();
        repo.leadGate!.complete();
        await inFlight;
        expect(pending.pendingFor(_scope), isNull, reason: '$answer');
        repo.leadCalls.clear();
      }
    });

    test('unknown outcome, retry, then backing out of the security check keeps the earlier key and changes nothing', () async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(NetworkFailure()), const Left(HumanCheckCancelledFailure()), const Right(unit)]);
      final cubit = make();
      await cubit.submit(_request());
      expect(pending.pendingFor(_scope)?.key, 'key-1');
      await cubit.submit(_request());
      expect(cubit.state.failure, isA<HumanCheckCancelledFailure>());
      expect(cubit.state.outcomeUnknown, isTrue, reason: 'the earlier attempt is still unresolved');
      expect(pending.pendingFor(_scope)?.key, 'key-1');
      await cubit.submit(_request());
      expect(repo.leadCalls.map((c) => c.key), ['key-1', 'key-1', 'key-1']);
      await cubit.close();
    });

    test('backing out of the security check with no earlier attempt leaves no key', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(HumanCheckCancelledFailure()));
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.outcomeUnknown, isFalse);
      expect(pending.pendingFor(_scope), isNull);
      await cubit.close();
    });

    test('network, server and still-processing are unknown outcomes; a security check outage or a rate limit were not sent', () async {
      for (final failure in <Failure>[const NetworkFailure(), const ServerFailure(), const IdempotencyInProgressFailure()]) {
        repo.leadResults
          ..clear()
          ..add(Left(failure));
        pending.clear();
        final cubit = make();
        await cubit.submit(_request());
        expect(cubit.state.outcomeUnknown, isTrue, reason: '$failure');
        expect(cubit.state.notSent, isFalse, reason: '$failure');
        expect(pending.pendingFor(_scope)?.unknown, isTrue);
        await cubit.close();
      }
      for (final failure in <Failure>[const HumanVerificationUnavailableFailure(), const RateLimitedFailure()]) {
        repo.leadResults
          ..clear()
          ..add(Left(failure));
        pending.clear();
        final cubit = make();
        await cubit.submit(_request());
        expect(cubit.state.outcomeUnknown, isFalse, reason: '$failure');
        expect(cubit.state.notSent, isTrue, reason: '$failure');
        expect(pending.pendingFor(_scope), isNotNull, reason: 'the key is kept, but it is not "may have gone through"');
        expect(pending.pendingFor(_scope)?.unknown, isFalse);
        await cubit.close();
        // Reopened, the sheet does not claim the sign-up may have finished.
        expect(make().state.outcomeUnknown, isFalse);
      }
    });

    test('another place does not see the pending sign-up of this one', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(NetworkFailure()));
      final here = make();
      await here.submit(_request());
      await here.close();
      final elsewhere = make(scope: PendingLeadKeys.scopeFor('sentech', -25.7, 28.35, TechnologyInterest.any));
      expect(elsewhere.state.outcomeUnknown, isFalse);
      final otherProvider = make(scope: PendingLeadKeys.scopeFor('acme-isp', -26.514, 29.103, TechnologyInterest.any));
      expect(otherProvider.state.outcomeUnknown, isFalse);
      expect(make(scope: PendingLeadKeys.scopeFor('sentech', -26.514001, 29.103002, TechnologyInterest.any)).state.outcomeUnknown, isTrue,
          reason: 'the same rounded place is the same place');
    });

    test('a key refused as used for another request is replaced once, automatically', () async {
      repo.leadResults
        ..clear()
        ..addAll([
          const Left(ValidationFailure('x', 'idempotency_key_reused', false)),
          const Right(unit),
        ]);
      final cubit = make();
      await cubit.submit(_request());
      expect(repo.leadCalls.map((c) => c.key), ['key-1', 'key-2']);
      expect(cubit.state.status, NotifyStatus.done);
      await cubit.close();
    });

    test('a rate limit holds further sign-ups until Retry-After has passed', () async {
      repo.leadResults
        ..clear()
        ..addAll([const Left(RateLimitedFailure('Too many', Duration(seconds: 40))), const Right(unit)]);
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.retryAt, clock.add(const Duration(seconds: 40)));
      await cubit.submit(_request());
      expect(repo.leadCalls, hasLength(1), reason: 'held: nothing is sent before the wait is over');
      expect(cubit.state.failure, isA<RateLimitedFailure>());
      expect(cubit.state.retryAt, clock.add(const Duration(seconds: 40)));
      clock = clock.add(const Duration(seconds: 41));
      await cubit.submit(_request());
      expect(repo.leadCalls, hasLength(2));
      expect(repo.leadCalls.last.key, 'key-1', reason: 'the same request after a hold is the same attempt');
      expect(cubit.state.status, NotifyStatus.done);
      await cubit.close();
    });

    test('the cubit state and the pending keys hold nothing the customer typed', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(NetworkFailure()));
      final cubit = make();
      await cubit.submit(_request(contact: '0821234567'));
      final seen = '${cubit.state} ${cubit.state.props} ${pending.pendingFor(_scope)} $pending';
      expect(seen, isNot(contains('0821234567')));
      expect(seen, isNot(contains('Lifalethu')));
      await cubit.close();
    });

    test('a stale consent text is its own failure', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(ConsentVersionOutdatedFailure()));
      final cubit = make();
      await cubit.submit(_request());
      expect(cubit.state.failure, isA<ConsentVersionOutdatedFailure>());
      expect(cubit.state.consentOutdated, isTrue);
      await cubit.close();
    });

    test('dismiss goes back to the form after a refusal', () async {
      repo.leadResults
        ..clear()
        ..add(const Left(InvalidContactFailure()));
      final cubit = make();
      await cubit.submit(_request());
      cubit.dismiss();
      expect(cubit.state.status, NotifyStatus.idle);
      await cubit.close();
    });
  });

  group('WithdrawalCubit', () {
    test('withdrawal_never_claims_removal_before_the_link', () async {
      final cubit = WithdrawalCubit(repo);
      await cubit.request(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567'));
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

  test('the pending keys hold a key and a flag, derived from nothing the customer typed', () {
    final scope = PendingLeadKeys.scopeFor('sentech', -26.514231234, 29.103119876, TechnologyInterest.fiveG);
    expect(scope, 'sentech|-26.51423,29.10312|5g', reason: 'tenant, the rounded place and the technology only');
    final keys = PendingLeadKeys()..put(scope, 'key-x', unknown: true);
    expect(keys.pendingFor(scope), (key: 'key-x', unknown: true));
    expect(keys.toString(), isNot(contains('key-x')));
    keys.clear();
    expect(keys.pendingFor(scope), isNull);
  });
}
