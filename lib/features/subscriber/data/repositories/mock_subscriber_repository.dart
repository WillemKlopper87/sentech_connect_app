import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';

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

  /// Services created by [signup] in this session (newest first).
  final _signedUp = <SubscriberService>[];
  final _idempotent = <String, SubscriberSignup>{};

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const Right(mockAccount);
  }

  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Right([..._signedUp, _current]);
  }

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final s in [..._signedUp, _current]) {
      if (s.id == id) return Right(s);
    }
    return const Left(NotFoundFailure());
  }

  // Demo state for S6/S7: the mock service changes in memory so the screens
  // can be tried; every other mock read answers the same fixed data.
  SubscriberService? _override;
  SubscriberService get _current => _override ?? mockService;

  static SubscriberService _copy(
    SubscriberService s, {
    String? planId,
    String? planName,
    SubscriberPlanKind? kind,
    int? priceCents,
    int? downKbps,
    int? upKbps,
    DateTime? cancelEffectiveOn,
    String? pendingPlanId,
    String? pendingPlanName,
    DateTime? planChangeOn,
  }) => SubscriberService(
    id: s.id,
    accountId: s.accountId,
    serviceNo: s.serviceNo,
    status: s.status,
    planId: planId ?? s.planId,
    planName: planName ?? s.planName,
    kind: kind ?? s.kind,
    priceCents: priceCents ?? s.priceCents,
    downKbps: downKbps ?? s.downKbps,
    upKbps: upKbps ?? s.upKbps,
    billedThrough: s.billedThrough,
    paidThrough: s.paidThrough,
    createdAt: s.createdAt,
    activatedAt: s.activatedAt,
    cancelEffectiveOn: cancelEffectiveOn ?? s.cancelEffectiveOn,
    pendingPlanId: pendingPlanId,
    pendingPlanName: pendingPlanName,
    planChangeOn: planChangeOn,
  );

  @override
  Future<Either<Failure, PlanChange>> changePlan(String serviceId, String newPlanId, {required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final target = MockSubscriberPlansRepository.mockPlans.where((p) => p.id == newPlanId);
    if (serviceId != mockService.id || target.isEmpty) return const Left(PlanUnavailableFailure('subscriber_plan_not_found'));
    final current = _current;
    if (current.isCancellationScheduled) return const Left(CancellationScheduledFailure());
    final plan = target.first;
    if (plan.kind != current.kind) return const Left(PlanUnavailableFailure('plan_kind_mismatch'));
    final now = DateTime.now().toUtc();
    final applied = plan.priceCents > current.priceCents;
    final effective = applied ? DateTime.utc(now.year, now.month, now.day) : firstOfNextMonth(now);
    _override = applied
        ? _copy(
            current,
            planId: plan.id,
            planName: plan.name,
            priceCents: plan.priceCents,
            downKbps: plan.downKbps,
            upKbps: plan.upKbps,
          )
        : _copy(current, pendingPlanId: plan.id, pendingPlanName: plan.name, planChangeOn: effective);
    return Right(PlanChange(applied: applied, effectiveOn: effective));
  }

  @override
  Future<Either<Failure, SubscriberService>> cancel(String serviceId, String reason, {required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (serviceId != mockService.id) return const Left(NotFoundFailure());
    final current = _current;
    if (current.isCancellationScheduled) return Right(current);
    final end = cancellationEndDate(current, DateTime.now().toUtc());
    return Right(
      _override = _copy(
        current,
        cancelEffectiveOn: end,
        pendingPlanId: current.pendingPlanId,
        pendingPlanName: current.pendingPlanName,
        planChangeOn: current.planChangeOn,
      ),
    );
  }

  /// Demo signup: a `pending` service, and the demo's open invoice as the
  /// first invoice so "Pay now" lands on a payable demo invoice. The same
  /// [idempotencyKey] answers the same pair, like the platform.
  @override
  Future<Either<Failure, SubscriberSignup>> signup({
    required String planId,
    required String termsVersion,
    required String idempotencyKey,
    String? installAddress,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final replay = _idempotent[idempotencyKey];
    if (replay != null) return Right(replay);
    final plans = MockSubscriberPlansRepository.mockPlans;
    final plan = [for (final p in plans) if (p.id == planId) p];
    if (plan.isEmpty) return const Left(PlanUnavailableFailure('subscriber_plan_not_found'));
    final p = plan.single;
    final fixed = p.kind == SubscriberPlanKind.fixedWireless;
    final service = SubscriberService(
      id: '9a1b2c3d-0000-4000-8000-0000000000b${2 + _signedUp.length}',
      accountId: _accountId,
      serviceNo: 'SV-0001${2 + _signedUp.length}',
      status: ServiceStatus.pending,
      activationBlocker: ActivationBlocker.firstInvoiceUnpaid,
      planId: p.id,
      planName: p.name,
      kind: p.kind,
      priceCents: p.priceCents,
      downKbps: p.downKbps,
      upKbps: p.upKbps,
      createdAt: DateTime.now().toUtc(),
    );
    final total = p.priceCents + p.setupFeeCents;
    final invoice = SubscriberInvoice(
      id: '9a1b2c3d-0000-4000-8000-0000000000c2',
      serviceId: service.id,
      invoiceNo: 'INV-000102',
      kind: 'initial',
      status: InvoiceStatus.open,
      periodStart: DateTime.utc(2026, 12),
      periodEnd: DateTime.utc(2026, 12, 31),
      issueDate: DateTime.utc(2026, 11, 25),
      dueDate: DateTime.utc(2026, 12, 1),
      amountCents: total,
      vatCents: 0,
      amountPaidCents: 0,
      lines: [
        InvoiceLine(
          position: 1,
          kind: 'plan',
          description: fixed ? '${p.name}, first month' : '${p.name}, December 2026',
          quantity: 1,
          unitPriceCents: p.priceCents,
          lineTotalCents: p.priceCents,
          vatRateBp: 1500,
          vatCents: 0,
        ),
      ],
    );
    _signedUp.insert(0, service);
    return Right(_idempotent[idempotencyKey] = SubscriberSignup(service: service, invoice: invoice));
  }
}
