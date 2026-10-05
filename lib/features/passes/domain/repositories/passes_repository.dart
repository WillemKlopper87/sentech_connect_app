import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

abstract class PassesRepository {
  /// Current (active + scheduled) passes, or all of them with [includeExpired].
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false});

  /// The timestamp belongs to this particular result, never shared mutable state.
  Future<Either<Failure, PassLoad>> getPassLoad({
    bool includeExpired = false,
  }) async => (await getPasses(includeExpired: includeExpired)).map(
    (passes) => PassLoad(passes: passes, loadedAt: DateTime.now().toUtc()),
  );
}

class PassLoad {
  PassLoad({
    required List<Pass> passes,
    required this.loadedAt,
    this.fromCache = false,
  }) : passes = List.unmodifiable(passes);
  final List<Pass> passes;
  final DateTime loadedAt;
  final bool fromCache;
}
