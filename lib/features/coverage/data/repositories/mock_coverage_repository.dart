import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';
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
}
