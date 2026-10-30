import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
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

  // --- S6 / S7 (change plan, cancel at period end) ---

  /// Moves an active or suspended service to [newPlanId] (same kind). One
  /// [idempotencyKey] per attempt; a retry with the same key gets the same
  /// answer. The API has no preview, so no amount is known before this call.
  Future<Either<Failure, PlanChange>> changePlan(String serviceId, String newPlanId, {required String idempotencyKey});

  /// Schedules the end of a service at `cancel_effective_on`; never immediate.
  /// Returns the service as the platform now has it. There is no undo route.
  Future<Either<Failure, SubscriberService>> cancel(String serviceId, String reason, {required String idempotencyKey});
}
