import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';

/// Demo flavor only: one hotspot plan and one fixed-wireless plan.
class MockSubscriberPlansRepository implements SubscriberPlansRepository {
  static const mockPlans = [
    SubscriberPlan(
      id: '3c0d5f7a-0000-4000-8000-000000000001',
      code: 'HOME-HOTSPOT-10',
      name: 'Home Hotspot 10',
      description: 'Monthly Wi-Fi allowance for your household.',
      kind: SubscriberPlanKind.recurringHotspot,
      kycRequired: false,
      priceCents: 19900,
      setupFeeCents: 0,
      downKbps: 10000,
      upKbps: 5000,
      maxDevices: 5,
      fupAction: 'throttle',
    ),
    SubscriberPlan(
      id: '3c0d5f7a-0000-4000-8000-000000000002',
      code: 'AIR-50',
      name: 'Home Air 50',
      description: 'Fixed wireless internet installed at your address.',
      kind: SubscriberPlanKind.fixedWireless,
      kycRequired: true,
      priceCents: 59900,
      setupFeeCents: 99900,
      downKbps: 50000,
      upKbps: 20000,
      maxDevices: 20,
      fupAction: 'none',
    ),
  ];

  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const Right(mockPlans);
  }
}
