import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

/// A [SubscriberRepository] for tests that only need `getService`.
class FakeSubscriberRepository implements SubscriberRepository {
  FakeSubscriberRepository({SubscriberService? service, this.failure}) : service = service ?? MockSubscriberRepository.mockService;

  final SubscriberService service;
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
}
