import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/cancel_service_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/change_plan_cubit.dart';

import 'helpers/fake_subscriber_repository.dart';
import 'helpers/subscriber_service_fixtures.dart';

class _Plans implements SubscriberPlansRepository {
  _Plans(this.result);
  Either<Failure, List<SubscriberPlan>> result;
  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async => result;
}

SubscriberPlan _plan(String id, int cents, {SubscriberPlanKind kind = SubscriberPlanKind.recurringHotspot}) => SubscriberPlan(
  id: id,
  code: id,
  name: 'Plan $id',
  description: '',
  kind: kind,
  kycRequired: false,
  priceCents: cents,
  setupFeeCents: 0,
  downKbps: 5000,
  upKbps: 2500,
  maxDevices: 3,
  fupAction: 'none',
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // The service in testService() is on 'plan-1' at R199.00, a hotspot plan.
  final plans = [
    _plan('plan-1', 19900), // the current plan: not offered
    _plan('plan-hi', 29900),
    _plan('plan-lo', 12900),
    _plan('plan-air', 59900, kind: SubscriberPlanKind.fixedWireless), // other kind: not offered
  ];

  group('ChangePlanCubit', () {
    test('offers the same kind except the current plan, cheapest first', () async {
      final cubit = ChangePlanCubit(FakeSubscriberRepository(), _Plans(Right(plans)), testService());
      await _settle();
      expect(cubit.state.status, ChangePlanStatus.choosing);
      expect([for (final p in cubit.state.candidates) p.id], ['plan-lo', 'plan-hi']);
    });

    test('with the demo plans, the demo hotspot service can move to the cheaper hotspot plan only', () async {
      final repo = FakeSubscriberRepository();
      final cubit = ChangePlanCubit(
        repo,
        _Plans(const Right(MockSubscriberPlansRepository.mockPlans)),
        repo.service,
      );
      await _settle();
      expect([for (final p in cubit.state.candidates) p.code], ['HOME-HOTSPOT-5']);
    });

    test('plans failing to load shows the failure and retry reloads', () async {
      final source = _Plans(const Left(NetworkFailure()));
      final cubit = ChangePlanCubit(FakeSubscriberRepository(), source, testService());
      await _settle();
      expect(cubit.state.status, ChangePlanStatus.plansFailed);
      expect(cubit.state.failure, isA<NetworkFailure>());
      source.result = Right(plans);
      await cubit.loadPlans();
      expect(cubit.state.status, ChangePlanStatus.choosing);
    });

    test('timing follows the price comparison against the service price', () async {
      final cubit = ChangePlanCubit(FakeSubscriberRepository(), _Plans(Right(plans)), testService());
      await _settle();
      expect(cubit.timingFor(plans[1]), PlanChangeTiming.immediate);
      expect(cubit.timingFor(plans[2]), PlanChangeTiming.scheduled);
    });

    test('an applied change with an invoice', () async {
      final repo = FakeSubscriberRepository()
        ..changeResult = Right(PlanChange(applied: true, effectiveOn: DateTime.utc(2026, 11, 3), prorationInvoiceId: 'inv-1'));
      final cubit = ChangePlanCubit(repo, _Plans(Right(plans)), testService(), newKey: () => 'key-a');
      await _settle();
      cubit.select(plans[1]);
      await cubit.confirm();
      expect(cubit.state.status, ChangePlanStatus.done);
      expect(cubit.state.result!.applied, isTrue);
      expect(cubit.state.result!.prorationInvoiceId, 'inv-1');
      expect(cubit.state.newPlan!.id, 'plan-hi');
      expect(repo.changeCalls.single, (serviceId: 'svc-1', planId: 'plan-hi', key: 'key-a'));
    });

    test('a scheduled change and a no-op answer both finish', () async {
      final repo = FakeSubscriberRepository()
        ..changeResult = Right(PlanChange(applied: false, effectiveOn: DateTime.utc(2026, 12, 1)));
      final cubit = ChangePlanCubit(repo, _Plans(Right(plans)), testService());
      await _settle();
      cubit.select(plans[2]);
      await cubit.confirm();
      expect(cubit.state.result!.applied, isFalse);
      expect(cubit.state.result!.prorationInvoiceId, isNull);

      repo.changeResult = Right(PlanChange(applied: true, effectiveOn: DateTime.utc(2026, 11, 3)));
      final noop = ChangePlanCubit(repo, _Plans(Right(plans)), testService());
      await _settle();
      noop.select(plans[1]);
      await noop.confirm();
      expect(noop.state.status, ChangePlanStatus.done);
      expect(noop.state.result!.prorationInvoiceId, isNull);
    });

    final refusals = <Failure>[
      const CancellationScheduledFailure(),
      const PlanChangeBilledFailure(),
      const KycRequiredFailure(),
      const ServiceStateFailure(),
      const PlanUnavailableFailure('plan_kind_mismatch'),
      const NetworkFailure(),
    ];
    for (final failure in refusals) {
      test('${failure.runtimeType} keeps the confirmation open with the failure', () async {
        final repo = FakeSubscriberRepository()..changeResult = Left(failure);
        final cubit = ChangePlanCubit(repo, _Plans(Right(plans)), testService());
        await _settle();
        cubit.select(plans[1]);
        await cubit.confirm();
        expect(cubit.state.status, ChangePlanStatus.choosing);
        expect(cubit.state.selected?.id, 'plan-hi');
        expect(cubit.state.failure, failure);
        expect(cubit.state.result, isNull);
      });
    }

    test('a retry of the same plan reuses the key; another plan gets a new one', () async {
      var n = 0;
      final repo = FakeSubscriberRepository()..changeResult = const Left(NetworkFailure());
      final cubit = ChangePlanCubit(repo, _Plans(Right(plans)), testService(), newKey: () => 'key-${++n}');
      await _settle();
      cubit.select(plans[1]);
      await cubit.confirm();
      await cubit.confirm();
      expect(repo.changeCalls.map((c) => c.key), ['key-1', 'key-1']);
      cubit.clearSelection();
      cubit.select(plans[2]);
      await cubit.confirm();
      expect(repo.changeCalls.last.key, 'key-2');
      expect(repo.changeCalls.last.planId, 'plan-lo');
    });

    test('confirming with nothing chosen does nothing', () async {
      final repo = FakeSubscriberRepository();
      final cubit = ChangePlanCubit(repo, _Plans(Right(plans)), testService());
      await _settle();
      await cubit.confirm();
      expect(repo.changeCalls, isEmpty);
    });
  });

  group('CancelServiceCubit', () {
    test('success returns the service with its end date; the reason is sent as "<choice>: <text>"', () async {
      final repo = FakeSubscriberRepository();
      final cubit = CancelServiceCubit(repo, testService(), newKey: () => 'key-1');
      await cubit.submit(CancelReason.tooExpensive, 'Found a cheaper plan');
      expect(cubit.state.status, CancelServiceStatus.done);
      expect(cubit.state.service!.cancelEffectiveOn, DateTime.utc(2026, 11, 30));
      expect(repo.cancelCalls.single, (serviceId: 'svc-1', reason: 'Too expensive: Found a cheaper plan', key: 'key-1'));
    });

    test('no reason chosen asks for one and sends nothing', () async {
      final repo = FakeSubscriberRepository();
      final cubit = CancelServiceCubit(repo, testService());
      await cubit.submit(null);
      expect(cubit.state.reasonMissing, isTrue);
      expect(cubit.state.status, CancelServiceStatus.idle);
      expect(repo.cancelCalls, isEmpty);
    });

    test('a replay answer (the first agreed date) is accepted as it is', () async {
      final repo = FakeSubscriberRepository()
        ..cancelResult = Right(testService(cancelEffectiveOn: DateTime.utc(2026, 11, 14)));
      final cubit = CancelServiceCubit(repo, testService());
      await cubit.submit(CancelReason.moving);
      expect(cubit.state.service!.cancelEffectiveOn, DateTime.utc(2026, 11, 14));
    });

    final refusals = <Failure>[
      const PendingCancelFailure(),
      const ServiceStateFailure(),
      const NotFoundFailure(),
      const NetworkFailure(),
    ];
    for (final failure in refusals) {
      test('${failure.runtimeType} leaves the dialog open with the failure', () async {
        final repo = FakeSubscriberRepository()..cancelResult = Left(failure);
        final cubit = CancelServiceCubit(repo, testService());
        await cubit.submit(CancelReason.moving);
        expect(cubit.state.status, CancelServiceStatus.idle);
        expect(cubit.state.failure, failure);
        expect(cubit.state.service, isNull);
      });
    }

    test('offline then retry with the same reason reuses the key; a changed reason gets a new one', () async {
      var n = 0;
      final repo = FakeSubscriberRepository()..cancelResult = const Left(NetworkFailure());
      final cubit = CancelServiceCubit(repo, testService(), newKey: () => 'key-${++n}');
      await cubit.submit(CancelReason.moving);
      await cubit.submit(CancelReason.moving);
      await cubit.submit(CancelReason.other, 'x');
      expect(repo.cancelCalls.map((c) => c.key), ['key-1', 'key-1', 'key-2']);
    });
  });
}
