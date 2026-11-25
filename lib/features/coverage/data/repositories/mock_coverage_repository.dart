import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

class MockCoverageRepository implements CoverageRepository {
  MockCoverageRepository([SimulatedNetwork? network]) : _network = network ?? SimulatedNetwork();

  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, CoverageResult>> checkAddress(String address) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (_network.failure case final failure?) return Left(failure);
    return Right(CoverageResult(
      address: address,
      isCovered: true,
      estimatedSpeedMbps: 100,
    ));
  }

  // Rewritten on the v2 entities with the screens (until then the demo answers "unavailable").
  @override
  Future<Either<Failure, CoverageCheck>> check({required double lat, required double lon}) async => const Left(CoverageUnavailableFailure());

  @override
  Future<Either<Failure, CoverageMeta>> meta({bool refresh = false}) async => const Left(CoverageUnavailableFailure());

  @override
  Future<Either<Failure, AddressSearchResult>> search(String query) async => const Left(CoverageUnavailableFailure());

  @override
  Future<Either<Failure, bool>> addressLookupAvailable() async => const Right(false);

  @override
  Future<Either<Failure, Unit>> submitLead(NotifyRequest request, {required String idempotencyKey}) async => const Left(CoverageUnavailableFailure());

  @override
  Future<Either<Failure, Unit>> requestWithdrawal(WithdrawalRequest request) async => const Left(CoverageUnavailableFailure());
}
