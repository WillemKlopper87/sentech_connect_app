import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

/// Demo flavor only: an account with one active home hotspot service.
class MockSubscriberRepository implements SubscriberRepository {
  static const _accountId = '9a1b2c3d-0000-4000-8000-0000000000a1';

  static final mockService = SubscriberService(
    id: '9a1b2c3d-0000-4000-8000-0000000000b1',
    accountId: _accountId,
    serviceNo: 'SV-000101',
    status: ServiceStatus.active,
    planId: MockSubscriberPlansRepository.mockPlans.first.id,
    planName: 'Home Hotspot 10',
    kind: SubscriberPlanKind.recurringHotspot,
    priceCents: 19900,
    downKbps: 10000,
    upKbps: 5000,
    billedThrough: DateTime.utc(2026, 11, 30),
    paidThrough: DateTime.utc(2026, 11, 30),
    createdAt: DateTime.utc(2026, 9, 1, 8),
    activatedAt: DateTime.utc(2026, 9, 1, 9),
  );

  static const mockAccount = SubscriberAccount(
    id: _accountId,
    accountNo: 'AC-000101',
    kind: SubscriberAccountKind.individual,
    status: SubscriberAccountStatus.active,
    serviceCounts: ServiceCounts(active: 1),
    profile: SubscriberProfile(displayName: 'Demo Customer', language: 'en'),
  );

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const Right(mockAccount);
  }

  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Right([mockService]);
  }

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return id == mockService.id ? Right(mockService) : const Left(NotFoundFailure());
  }
}
