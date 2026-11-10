import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/fiveg_service/data/mock_fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/bloc/fiveg_usage_cubit.dart';
import 'package:sentech_connect_app/features/fiveg_service/presentation/bloc/unlock_cubit.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';

const _service = 'svc-1';

FiveGUsage _usage({bool restoring = false, PendingUnlock? pending}) => FiveGUsage(
  planKind: FiveGPlanKind.capped,
  state: UsageState.normal,
  periodStart: DateTime.utc(2026, 11, 1),
  cycleEnd: DateTime.utc(2026, 11, 30),
  effectiveCapMb: 100000,
  countedUsageMb: 20000,
  usedPercent: 20,
  restoring: restoring,
  pendingUnlock: pending,
);

final _offer = UnlockOffer(
  code: 'data_unlock_50gb',
  name: '50 GB data unlock',
  addedMb: 50000,
  priceCents: 19900,
  vatCents: 2596,
  validUntil: DateTime.utc(2026, 11, 30),
);

/// Replies come from a script: one entry per call, the last one repeats.
class _ScriptedFiveG implements FiveGRepository {
  _ScriptedFiveG({this.usages = const [], this.creates = const []});

  final List<Either<Failure, FiveGUsage>> usages;
  final List<Either<Failure, Order>> creates;
  int usageCalls = 0;
  final createKeys = <String>[];
  final createCodes = <String>[];

  @override
  Future<Either<Failure, FiveGUsage>> getUsage(String serviceId) async {
    final index = usageCalls < usages.length ? usageCalls : usages.length - 1;
    usageCalls++;
    return usages[index];
  }

  @override
  Future<Either<Failure, Order>> createUnlockOrder(
    String serviceId, {
    required String productCode,
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    createCodes.add(productCode);
    final index = createKeys.length - 1 < creates.length ? createKeys.length - 1 : creates.length - 1;
    return creates[index];
  }
}

Order _order(String id) => Order(
  id: id,
  orderNumber: 'SEN-$id',
  planName: '50 GB data unlock',
  totalCents: 19900,
  status: OrderStatus.awaitingPayment,
  kind: OrderKind.dataUnlock,
);

void main() {
  group('FiveGUsageCubit', () {
    test('loads the allowance', () async {
      final cubit = FiveGUsageCubit(_ScriptedFiveG(usages: [Right(_usage())]), _service);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, FiveGUsageStatus.loaded);
      expect(cubit.state.usage?.usedPercent, 20);
      await cubit.close();
    });

    test('a 404 is "not available", not an error', () async {
      final cubit = FiveGUsageCubit(
        _ScriptedFiveG(usages: [const Left(FiveGNotAvailableFailure())]),
        _service,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, FiveGUsageStatus.unavailable);
      await cubit.close();
    });

    test('another failure is shown as a failure', () async {
      final cubit = FiveGUsageCubit(
        _ScriptedFiveG(usages: [const Left(NetworkFailure())]),
        _service,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, FiveGUsageStatus.failure);
      expect(cubit.state.failure, isA<NetworkFailure>());
      await cubit.close();
    });

    test('while restoring it polls with the injected delays until the service is back', () async {
      final waits = <Duration>[];
      final repo = _ScriptedFiveG(usages: [
        Right(_usage(restoring: true)),
        Right(_usage(restoring: true)),
        Right(_usage()),
      ]);
      final cubit = FiveGUsageCubit(
        repo,
        _service,
        restoringPollDelays: List.filled(18, const Duration(seconds: 10)),
        wait: (d) async => waits.add(d),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.usage?.restoring, isFalse);
      expect(cubit.state.restoringTimedOut, isFalse);
      expect(waits, everyElement(const Duration(seconds: 10)));
      expect(waits, hasLength(2));
      expect(repo.usageCalls, 3);
      await cubit.close();
    });

    test('stops after the polling window with the timed-out flag (no endless polling)', () async {
      final waits = <Duration>[];
      final repo = _ScriptedFiveG(usages: [Right(_usage(restoring: true))]);
      final cubit = FiveGUsageCubit(
        repo,
        _service,
        restoringPollDelays: List.filled(18, const Duration(seconds: 10)),
        wait: (d) async => waits.add(d),
      );
      await Future<void>.delayed(Duration.zero);
      expect(waits, hasLength(18));
      expect(cubit.state.restoringTimedOut, isTrue);
      expect(cubit.state.usage?.restoring, isTrue);
      expect(repo.usageCalls, 19);
      await cubit.close();
    });

    test('a failed poll keeps the last answer and tries again', () async {
      final repo = _ScriptedFiveG(usages: [
        Right(_usage(restoring: true)),
        const Left(NetworkFailure()),
        Right(_usage()),
      ]);
      final cubit = FiveGUsageCubit(
        repo,
        _service,
        restoringPollDelays: List.filled(3, Duration.zero),
        wait: (_) async {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.usage?.restoring, isFalse);
      expect(cubit.state.status, FiveGUsageStatus.loaded);
      await cubit.close();
    });

    test('a refresh keeps the screen visible and a stale poll loop stops', () async {
      final gate = Completer<void>();
      final repo = _ScriptedFiveG(usages: [Right(_usage(restoring: true)), Right(_usage())]);
      final cubit = FiveGUsageCubit(
        repo,
        _service,
        restoringPollDelays: List.filled(18, const Duration(seconds: 10)),
        wait: (_) => gate.future,
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.refresh();
      expect(cubit.state.usage?.restoring, isFalse);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.restoringTimedOut, isFalse);
      await cubit.close();
    });
  });

  group('UnlockCubit', () {
    test('choosing then confirming creates the order and is ready to pay it', () async {
      final repo = _ScriptedFiveG(creates: [Right(_order('o-1'))]);
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-00000001');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.status, UnlockStatus.ready);
      expect(cubit.state.orderId, 'o-1');
      expect(repo.createCodes, ['data_unlock_50gb']);
      await cubit.close();
    });

    test('confirming without an offer does nothing', () async {
      final repo = _ScriptedFiveG(creates: [Right(_order('o-1'))]);
      final cubit = UnlockCubit(repo, _service);
      await cubit.confirm();
      expect(repo.createKeys, isEmpty);
      await cubit.close();
    });

    test('a retry of the same offer reuses the idempotency key; another offer gets a new one', () async {
      var n = 0;
      final repo = _ScriptedFiveG(creates: [
        const Left(NetworkFailure()),
        Right(_order('o-2')),
      ]);
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-${++n}');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.status, UnlockStatus.failure);
      await cubit.confirm();
      expect(repo.createKeys, ['key-1', 'key-1']);
      expect(cubit.state.orderId, 'o-2');
      await cubit.close();
    });

    test('a 409 unlock_order_open resumes the order already waiting for payment', () async {
      final repo = _ScriptedFiveG(
        usages: [Right(_usage(pending: const PendingUnlock(orderId: 'o-open', status: 'awaiting_payment')))],
        creates: [const Left(UnlockOrderOpenFailure())],
      );
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-00000001');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.status, UnlockStatus.ready);
      expect(cubit.state.orderId, 'o-open');
      expect(repo.createKeys, hasLength(1));
      await cubit.close();
    });

    test('a failed pending order is resumed too (the payment screen offers retry or cancel)', () async {
      final repo = _ScriptedFiveG(
        usages: [Right(_usage(pending: const PendingUnlock(orderId: 'o-failed', status: 'failed')))],
        creates: [const Left(UnlockOrderOpenFailure())],
      );
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-00000001');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.status, UnlockStatus.ready);
      expect(cubit.state.orderId, 'o-failed');
      await cubit.close();
    });

    test('idempotency_in_progress keeps the key so the next tap retries the same request', () async {
      final repo = _ScriptedFiveG(creates: [const Left(IdempotencyInProgressFailure())]);
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-00000001');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.failure, isA<IdempotencyInProgressFailure>());
      repo.creates.add(Right(_order('o-new')));
      await cubit.confirm();
      expect(repo.createKeys, ['key-00000001', 'key-00000001']);
      await cubit.close();
    });

    test('a 409 unlock_order_open with nothing pending is a failure, not a second order', () async {
      final repo = _ScriptedFiveG(
        usages: [Right(_usage())],
        creates: [const Left(UnlockOrderOpenFailure())],
      );
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-00000001');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.status, UnlockStatus.failure);
      // The platform omits pending_unlock while the payment is held or settled.
      expect(cubit.state.failure, isA<UnlockPaymentHeldFailure>());
      expect(cubit.state.orderId, isNull);
      await cubit.close();
    });

    test('the monthly limit is refused with its own failure', () async {
      final repo = _ScriptedFiveG(creates: [const Left(UnlockLimitReachedFailure())]);
      final cubit = UnlockCubit(repo, _service, newKey: () => 'key-00000001');
      cubit.choose(_offer);
      await cubit.confirm();
      expect(cubit.state.status, UnlockStatus.failure);
      expect(cubit.state.failure, isA<UnlockLimitReachedFailure>());
      await cubit.close();
    });

    test('the demo repository creates one order per key and refuses a second open unlock', () async {
      final store = InMemorySecureStore();
      final repo = MockFiveGRepository(store: store, latency: Duration.zero, now: () => DateTime.utc(2026, 11, 10, 9));
      final first = await repo.createUnlockOrder(_service, productCode: 'data_unlock_50gb', idempotencyKey: 'k-1');
      final again = await repo.createUnlockOrder(_service, productCode: 'data_unlock_50gb', idempotencyKey: 'k-1');
      expect(first.getOrElse((_) => throw StateError('no order')).id, again.getOrElse((_) => throw StateError('no order')).id);
      final second = await repo.createUnlockOrder(_service, productCode: 'data_unlock_50gb', idempotencyKey: 'k-2');
      expect(second.match((f) => f, (_) => null), isA<UnlockOrderOpenFailure>());
    });
  });
}
