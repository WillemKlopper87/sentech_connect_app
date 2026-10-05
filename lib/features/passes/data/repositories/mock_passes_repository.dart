import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

/// Demo flavor: one active Day Pass and, when asked, one expired pass.
class MockPassesRepository implements PassesRepository {
  MockPassesRepository({DateTime Function()? now, SimulatedNetwork? network})
    : _now = now ?? DateTime.now,
      _network = network ?? SimulatedNetwork();

  final DateTime Function() _now;
  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, PassLoad>> getPassLoad({
    bool includeExpired = false,
  }) async => (await getPasses(
    includeExpired: includeExpired,
  )).map((passes) => PassLoad(passes: passes, loadedAt: _now().toUtc()));

  @override
  Future<Either<Failure, List<Pass>>> getPasses({
    bool includeExpired = false,
  }) async {
    if (_network.failure case final failure?) return Left(failure);
    final now = _now().toUtc();
    final active = Pass(
      id: 'pass_demo_1',
      orderId: 'ord_demo_1',
      productName: 'Day Pass',
      status: PassStatus.active,
      startsAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.add(const Duration(hours: 22)),
      durationMinutes: 1440,
      dataMb: 5120,
      speedKbps: 10240,
      maxDevices: 2,
      usedBytes: 1288490188,
    );
    final expired = Pass(
      id: 'pass_demo_0',
      orderId: 'ord_demo_0',
      productName: '1 Hour Pass',
      status: PassStatus.expired,
      startsAt: now.subtract(const Duration(days: 3)),
      expiresAt: now
          .subtract(const Duration(days: 3))
          .add(const Duration(hours: 1)),
      durationMinutes: 60,
      dataMb: 1024,
      speedKbps: 10240,
      maxDevices: 1,
    );
    return Right(includeExpired ? [active, expired] : [active]);
  }
}
