import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart' show subscriberSignupFromJson;
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/plans_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/signup_cubit.dart';

import 'helpers/fixtures.dart';

class FakePlans implements SubscriberPlansRepository {
  FakePlans(this.plans, {this.failure});
  List<SubscriberPlan> plans;
  Failure? failure;
  int calls = 0;

  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async {
    calls++;
    return failure != null ? Left(failure!) : Right(plans);
  }
}

class SignupCall {
  SignupCall(this.planId, this.termsVersion, this.key, this.address);
  final String planId;
  final String termsVersion;
  final String key;
  final String? address;
}

class SignupRepo implements SubscriberRepository {
  final calls = <SignupCall>[];
  final replies = <Either<Failure, SubscriberSignup>>[];
  Completer<void>? gate;

  @override
  Future<Either<Failure, SubscriberSignup>> signup({
    required String planId,
    required String termsVersion,
    required String idempotencyKey,
    String? installAddress,
  }) async {
    calls.add(SignupCall(planId, termsVersion, idempotencyKey, installAddress));
    await gate?.future;
    return replies.isEmpty ? Right(await _ok()) : replies.removeAt(0);
  }

  Future<SubscriberSignup> _ok() async => subscriberSignupFromJson(fixtureMap('subscriber_signup.json'));

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async => const Right(null);

  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async => const Right([]);

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async => const Left(NotFoundFailure());

  @override
  Future<Either<Failure, PlanChange>> changePlan(String serviceId, String newPlanId, {required String idempotencyKey}) async =>
      throw UnimplementedError('changePlan');

  @override
  Future<Either<Failure, SubscriberService>> cancel(String serviceId, String reason, {required String idempotencyKey}) async =>
      throw UnimplementedError('cancel');
}

const hotspot = SubscriberPlan(
  id: 'p-hot',
  code: 'H',
  name: 'Hotspot',
  description: '',
  kind: SubscriberPlanKind.recurringHotspot,
  kycRequired: false,
  priceCents: 19900,
  setupFeeCents: 0,
  downKbps: 10000,
  upKbps: 5000,
  maxDevices: 5,
  fupAction: 'none',
);

SubscriberPlan wireless({String id = 'p-air', int price = 59900}) => SubscriberPlan(
  id: id,
  code: 'A',
  name: 'Air',
  description: '',
  kind: SubscriberPlanKind.fixedWireless,
  kycRequired: true,
  priceCents: price,
  setupFeeCents: 99900,
  downKbps: 50000,
  upKbps: 20000,
  maxDevices: 20,
  fupAction: 'none',
);

void main() {
  group('PlansCubit', () {
    test('groups by kind (hotspot first) and sorts by price inside a group', () async {
      final repo = FakePlans([wireless(id: 'a2', price: 90000), wireless(id: 'a1', price: 59900), hotspot]);
      final cubit = PlansCubit(repo);
      await cubit.stream.firstWhere((s) => s.status == PlansStatus.loaded);
      expect(cubit.state.plans.map((p) => p.id), ['p-hot', 'a1', 'a2']);
      expect(cubit.state.ofKind(SubscriberPlanKind.fixedWireless), hasLength(2));
      expect(cubit.state.byId('a1'), isNotNull);
      expect(cubit.state.byId('zzz'), isNull);
      await cubit.close();
    });

    test('an empty list is loaded and empty; a failure keeps the failure; refresh keeps the list on a failed reload', () async {
      final repo = FakePlans(const []);
      final cubit = PlansCubit(repo);
      await cubit.stream.firstWhere((s) => s.status == PlansStatus.loaded);
      expect(cubit.state.plans, isEmpty);
      repo
        ..plans = [hotspot]
        ..failure = const NetworkFailure();
      await cubit.load();
      expect(cubit.state.status, PlansStatus.failure);
      repo.failure = null;
      await cubit.load();
      expect(cubit.state.plans, hasLength(1));
      repo.failure = const NetworkFailure();
      await cubit.load(keepVisible: true);
      expect(cubit.state.status, PlansStatus.loaded);
      await cubit.close();
    });
  });

  group('SignupCubit', () {
    late SignupRepo repo;
    var keyCount = 0;

    SignupCubit make({List<SubscriberPlan>? plans, String? terms = '2026-09-30', String planId = 'p-air'}) {
      keyCount = 0;
      return SignupCubit(
        FakePlans(plans ?? [hotspot, wireless()]),
        repo,
        planId,
        termsVersion: () => terms,
        newKey: () => 'key-${++keyCount}',
      );
    }

    Future<SignupCubit> ready({String planId = 'p-air', String? terms = '2026-09-30'}) async {
      final c = make(planId: planId, terms: terms);
      await c.stream.firstWhere((s) => s.phase == SignupPhase.ready);
      return c;
    }

    setUp(() => repo = SignupRepo());

    test('a plan missing from the list is planMissing', () async {
      final c = make(planId: 'gone');
      await c.stream.firstWhere((s) => s.phase == SignupPhase.planMissing);
      await c.close();
    });

    test('a failed plan list is loadFailed and can be retried', () async {
      final plans = FakePlans(const [], failure: const NetworkFailure());
      final c = SignupCubit(plans, repo, 'p-air', termsVersion: () => '2026-09-30');
      await c.stream.firstWhere((s) => s.phase == SignupPhase.loadFailed);
      plans
        ..failure = null
        ..plans = [wireless()];
      await c.load();
      expect(c.state.phase, SignupPhase.ready);
      await c.close();
    });

    test('terms are required, and a fixed wireless plan needs an address', () async {
      final c = await ready();
      await c.submit();
      expect(c.state.showErrors, isTrue);
      expect(repo.calls, isEmpty);
      c.setAcceptTerms(true);
      await c.submit();
      expect(repo.calls, isEmpty, reason: 'address missing');
      c.setAddress('   ');
      await c.submit();
      expect(repo.calls, isEmpty, reason: 'blank address');
      c.setAddress('1 Main Road\n');
      await c.submit();
      expect(repo.calls.single.address, '1 Main Road');
      expect(c.state.phase, SignupPhase.done);
      await c.close();
    });

    test('a hotspot plan sends no address even if one was typed', () async {
      final c = await ready(planId: 'p-hot');
      c.setAddress('ignored');
      c.setAcceptTerms(true);
      await c.submit();
      expect(repo.calls.single.address, isNull);
      expect(repo.calls.single.termsVersion, '2026-09-30');
      expect(c.state.result!.service.status, ServiceStatus.pending);
      await c.close();
    });

    test('a retry of the same draft reuses the key; any edit rotates it', () async {
      final c = await ready();
      c.setAcceptTerms(true);
      c.setAddress('1 Main Road');
      repo.replies
        ..add(const Left(NetworkFailure()))
        ..add(const Left(NetworkFailure()));
      await c.submit();
      expect(c.state.phase, SignupPhase.ready);
      expect(c.state.failure, isA<NetworkFailure>());
      await c.submit();
      expect(repo.calls.map((x) => x.key), ['key-1', 'key-1']);
      c.setAddress('2 Other Road');
      await c.submit();
      expect(repo.calls.last.key, 'key-2');
      await c.close();
    });

    test('a double tap while submitting sends one request', () async {
      final c = await ready(planId: 'p-hot');
      c.setAcceptTerms(true);
      repo.gate = Completer<void>();
      final first = c.submit();
      await c.submit();
      repo.gate!.complete();
      await first;
      expect(repo.calls, hasLength(1));
      await c.close();
    });

    test('no loaded config refuses with a consent failure and sends nothing', () async {
      final c = await ready(planId: 'p-hot', terms: null);
      c.setAcceptTerms(true);
      await c.submit();
      expect(c.state.failure, isA<ConsentVersionOutdatedFailure>());
      expect(repo.calls, isEmpty);
      await c.close();
    });

    test('consent_version_outdated rotates the key (the body changes with the new version)', () async {
      final c = await ready(planId: 'p-hot');
      c.setAcceptTerms(true);
      repo.replies.add(const Left(ConsentVersionOutdatedFailure()));
      await c.submit();
      expect(c.state.failure, isA<ConsentVersionOutdatedFailure>());
      await c.submit();
      expect(repo.calls.map((x) => x.key), ['key-1', 'key-2']);
      await c.close();
    });

    test('each other refusal keeps the form with the failure for a retry', () async {
      for (final failure in <Failure>[
        const SubscriberProfileInvalidFailure(),
        const CustomerLinkRequiredFailure(),
        const ServiceStateFailure('account_closed'),
        const ServerFailure('Something went wrong on our end.'),
        const ModuleDisabledFailure(),
      ]) {
        final c = await ready(planId: 'p-hot');
        c.setAcceptTerms(true);
        repo.replies.add(Left(failure));
        await c.submit();
        expect(c.state.phase, SignupPhase.ready, reason: '$failure');
        expect(c.state.failure, failure);
        expect(c.state.acceptTerms, isTrue);
        await c.close();
      }
    });

    test('a plan that became unavailable ends in planMissing', () async {
      final c = await ready(planId: 'p-hot');
      c.setAcceptTerms(true);
      repo.replies.add(const Left(PlanUnavailableFailure('subscriber_plan_inactive')));
      await c.submit();
      expect(c.state.phase, SignupPhase.planMissing);
      expect(c.state.failure, isA<PlanUnavailableFailure>());
      await c.close();
    });

    test('state never prints the address', () async {
      final c = await ready();
      c.setAddress('12 Secret Lane');
      expect(c.state.toString(), isNot(contains('Secret')));
      await c.close();
    });
  });

  test('the demo plans carry both kinds (sanity for the widget tests)', () {
    expect(MockSubscriberPlansRepository.mockPlans.map((p) => p.kind).toSet(), SubscriberPlanKind.values.toSet());
  });
}
