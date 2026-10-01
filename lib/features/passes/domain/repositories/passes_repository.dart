import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

abstract class PassesRepository {
  /// Current (active + scheduled) passes, or all of them with [includeExpired].
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false});
}
