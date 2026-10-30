import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

abstract class SubscriberRepository {
  /// The customer's account, or `Right(null)` when they never signed up
  /// (404 `subscriber_not_found` is the normal first state, not an error).
  Future<Either<Failure, SubscriberAccount?>> getAccount();

  /// All services, newest first (all pages, as the API orders them). No
  /// account is an empty list.
  Future<Either<Failure, List<SubscriberService>>> listServices();

  /// One service. [NotFoundFailure] for another account's service.
  Future<Either<Failure, SubscriberService>> getService(String id);
}
