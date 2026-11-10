import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/sast.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';

/// Named demo states for the 5G data screens. The demo flavor uses
/// [normal]; tests choose the others.
enum FiveGScenario {
  /// 20% used, full speed, rollover shown.
  normal,

  /// 55% used: the first warning band.
  warn50,

  /// 82% used.
  warn80,

  /// 100% used and cut off (the platform enabled the cut-off).
  warn100,

  /// 85% used and in the slow lane (5/2 Mbit/s).
  slowLane,

  /// A paid unlock was applied and the service is being restored.
  unlockedRestoring,

  /// Allowance used up, no cut-off: the customer is out of bundle.
  outOfBundle,

  /// Fair-use plan, throttled for the rest of the month.
  fupThrottled,

  /// The feature is off for this service (404 on every route).
  notAvailable,

  /// The usage read fails with a server error.
  failure,

  /// Every unlock purchase is refused because the monthly limit is reached.
  limitReached,
}

/// Demo and test stand-in for the 5G data routes. Dates follow the real
/// calendar: the month containing [now] (SAST). Unlock orders are written to
/// the same demo order store the shared checkout pays from, so an unlock can
/// be paid in the demo and the payment screen is the real one.
class MockFiveGRepository implements FiveGRepository {
  MockFiveGRepository({
    required this.store,
    this.scenario = FiveGScenario.normal,
    DateTime Function()? now,
    this.latency = const Duration(milliseconds: 300),
  }) : _now = now ?? DateTime.now;

  /// 100 GB allowance, in megabytes (decimal units).
  static const capMb = 100000;

  /// The demo order store the unlock orders are written to and paid from.
  final SecureStore store;
  final FiveGScenario scenario;
  final DateTime Function() _now;
  final Duration latency;
  final _byKey = <String, Order>{};

  static List<UnlockOffer> _offersFor(DateTime cycleEnd) => [
    UnlockOffer(
      code: 'data_unlock_50gb',
      name: '50 GB data unlock',
      addedMb: 50000,
      priceCents: 19900,
      vatCents: 2596,
      validUntil: cycleEnd,
    ),
    UnlockOffer(
      code: 'data_unlock_100gb',
      name: '100 GB data unlock',
      addedMb: 100000,
      priceCents: 34900,
      vatCents: 4552,
      validUntil: cycleEnd,
    ),
  ];

  Future<void> _pause() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<Either<Failure, FiveGUsage>> getUsage(String serviceId) async {
    await _pause();
    return switch (scenario) {
      FiveGScenario.notAvailable => const Left(FiveGNotAvailableFailure()),
      FiveGScenario.failure => const Left(ServerFailure('Something went wrong on our end.')),
      _ => Right(await _usage()),
    };
  }

  Future<FiveGUsage> _usage() async {
    final today = sastDay(_now());
    final periodStart = DateTime.utc(today.year, today.month, 1);
    final cycleEnd = lastDayOfMonth(today);
    final pending = await _openUnlock();
    if (scenario == FiveGScenario.fupThrottled) {
      return FiveGUsage(
        planKind: FiveGPlanKind.fup,
        state: UsageState.fup,
        periodStart: periodStart,
        cycleEnd: cycleEnd,
        restoring: false,
      );
    }
    final (int percent, UsageState state, bool restoring, int? rollover) = switch (scenario) {
      FiveGScenario.normal => (20, UsageState.normal, false, 5000),
      FiveGScenario.warn50 => (55, UsageState.normal, false, null),
      FiveGScenario.warn80 => (82, UsageState.normal, false, null),
      FiveGScenario.warn100 => (100, UsageState.cutOff, false, null),
      FiveGScenario.slowLane => (85, UsageState.slowLane, false, null),
      FiveGScenario.unlockedRestoring => (60, UsageState.normal, true, null),
      FiveGScenario.outOfBundle => (100, UsageState.outOfBundle, false, null),
      FiveGScenario.limitReached => (85, UsageState.normal, false, null),
      _ => (20, UsageState.normal, false, null),
    };
    return FiveGUsage(
      planKind: FiveGPlanKind.capped,
      state: state,
      periodStart: periodStart,
      cycleEnd: cycleEnd,
      effectiveCapMb: capMb,
      countedUsageMb: capMb * percent ~/ 100,
      usedPercent: percent,
      rolloverMb: rollover,
      warnLevels: [
        if (percent >= 50) 50,
        if (percent >= 80) 80,
        if (percent >= 100) 100,
      ],
      nextWarnLevel: switch (percent) {
        < 50 => 50,
        < 80 => 80,
        < 100 => 100,
        _ => null,
      },
      offers: _offersFor(cycleEnd),
      pendingUnlock: pending,
      restoring: restoring,
    );
  }

  /// The open (unpaid) unlock order, if one is waiting in the demo store.
  Future<PendingUnlock?> _openUnlock() async {
    for (final order in await loadMockOrders(store)) {
      if (order.kind == OrderKind.dataUnlock && order.isOpen) {
        return PendingUnlock(orderId: order.id, status: 'awaiting_payment');
      }
    }
    return null;
  }

  @override
  Future<Either<Failure, Order>> createUnlockOrder(
    String serviceId, {
    required String productCode,
    required String idempotencyKey,
  }) async {
    await _pause();
    final cached = _byKey[idempotencyKey];
    if (cached != null) return Right(cached);
    switch (scenario) {
      case FiveGScenario.notAvailable:
        return const Left(FiveGNotAvailableFailure());
      case FiveGScenario.failure:
        return const Left(ServerFailure('Something went wrong on our end.'));
      case FiveGScenario.limitReached:
        return const Left(UnlockLimitReachedFailure());
      default:
        break;
    }
    if (await _openUnlock() != null) return const Left(UnlockOrderOpenFailure());
    final today = sastDay(_now());
    final offer = _offersFor(lastDayOfMonth(today)).where((o) => o.code == productCode).firstOrNull;
    if (offer == null) return const Left(UnlockNotAvailableFailure());
    final order = Order(
      id: 'fiveg_ord_${_now().microsecondsSinceEpoch}',
      orderNumber: 'SEN-UNL-${offer.addedMb ~/ 1000}',
      planName: offer.name,
      totalCents: offer.priceCents,
      status: OrderStatus.awaitingPayment,
      kind: OrderKind.dataUnlock,
    );
    await recordMockOrder(store, order);
    _byKey[idempotencyKey] = order;
    return Right(order);
  }
}
