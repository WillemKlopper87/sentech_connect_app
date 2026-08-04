import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';

class MockLivenessRepository implements LivenessRepository {
  @override
  Future<Either<Failure, bool>> verifyLiveness() async {
    await Future.delayed(const Duration(seconds: 2));
    return const Right(true);
  }
}
