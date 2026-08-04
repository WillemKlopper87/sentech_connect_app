import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

class MockCoverageRepository implements CoverageRepository {
  @override
  Future<Either<Failure, CoverageResult>> checkAddress(String address) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return Right(CoverageResult(
      address: address,
      isCovered: true,
      estimatedSpeedMbps: 100,
    ));
  }
}
