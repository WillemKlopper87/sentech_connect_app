import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';

/// Real implementation, per the reconciled spec, resolves this against
/// Sentech's coverage API (endpoint TBD — see docs/reconciled-spec.md §6).
abstract class CoverageRepository {
  Future<Either<Failure, CoverageResult>> checkAddress(String address);
}
