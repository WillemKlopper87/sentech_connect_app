import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

import 'subscriber_service_fixtures.dart';

/// A [SubscriberRepository] for tests that only need `getService`.
class FakeSubscriberRepository implements SubscriberRepository {
  FakeSubscriberRepository({SubscriberService? service, this.failure}) : service = service ?? MockSubscriberRepository.mockService;

  SubscriberService service;
  final Failure? failure;
  final getServiceCalls = <String>[];

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async => const Right(MockSubscriberRepository.mockAccount);

  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async => Right([service]);

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async {
    getServiceCalls.add(id);
    return failure != null ? Left(failure!) : Right(service);
  }

  /// What `changePlan` and `cancel` answer; every call is recorded.
  Either<Failure, PlanChange> changeResult = Right(PlanChange(applied: true, effectiveOn: DateTime.utc(2026, 11, 2)));
  Either<Failure, SubscriberService>? cancelResult;
  final changeCalls = <({String serviceId, String planId, String key})>[];
  final cancelCalls = <({String serviceId, String reason, String key})>[];

  @override
  Future<Either<Failure, PlanChange>> changePlan(String serviceId, String newPlanId, {required String idempotencyKey}) async {
    changeCalls.add((serviceId: serviceId, planId: newPlanId, key: idempotencyKey));
    return changeResult;
  }

  @override
  Future<Either<Failure, SubscriberService>> cancel(String serviceId, String reason, {required String idempotencyKey}) async {
    cancelCalls.add((serviceId: serviceId, reason: reason, key: idempotencyKey));
    final result = cancelResult ?? Right(testService(id: serviceId, cancelEffectiveOn: DateTime.utc(2026, 11, 30)));
    // The platform keeps what it agreed: later reads see the scheduled end.
    result.map((updated) => service = updated);
    return result;
  }
}
