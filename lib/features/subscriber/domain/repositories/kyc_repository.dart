import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';

abstract class KycRepository {
  /// The customer's latest ID check, or `Right(null)` when there is none (the
  /// API's `none`, or a record erased after retention). A customer without a
  /// subscriber account gets [SubscriberNotFoundFailure].
  Future<Either<Failure, KycRecord?>> getStatus();

  /// Sends one ID check. [idempotencyKey]: one per logical submission, reused
  /// when the same draft is retried (a changed draft needs a new key).
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey});
}
