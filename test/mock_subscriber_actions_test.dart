import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';

void main() {
  const lower = '3c0d5f7a-0000-4000-8000-000000000003';
  const air = '3c0d5f7a-0000-4000-8000-000000000002';
  final id = MockSubscriberRepository.mockService.id;

  test('demo: a cheaper plan is scheduled, with no invoice, and shows on the service', () async {
    final repo = MockSubscriberRepository();
    final change = (await repo.changePlan(id, lower, idempotencyKey: 'k1')).getOrElse((_) => throw StateError('failed'));
    expect(change.applied, isFalse);
    expect(change.prorationInvoiceId, isNull);
    final service = (await repo.getService(id)).getOrElse((_) => throw StateError('failed'));
    expect(service.hasPlanChangePending, isTrue);
    expect(service.pendingPlanName, 'Home Hotspot 5');
  });

  test('demo: a plan of another kind is refused like the platform does', () async {
    final result = await MockSubscriberRepository().changePlan(id, air, idempotencyKey: 'k1');
    expect(result.match((f) => f, (_) => null), isA<PlanUnavailableFailure>());
  });

  test('demo: cancel schedules the end, a repeat keeps the first date, and change plan is then refused', () async {
    final repo = MockSubscriberRepository();
    final first = (await repo.cancel(id, 'Moving', idempotencyKey: 'k1')).getOrElse((_) => throw StateError('failed'));
    expect(first.cancelEffectiveOn, MockSubscriberRepository.mockService.paidThrough);
    final again = (await repo.cancel(id, 'Other', idempotencyKey: 'k2')).getOrElse((_) => throw StateError('failed'));
    expect(again.cancelEffectiveOn, first.cancelEffectiveOn);
    final change = await repo.changePlan(id, lower, idempotencyKey: 'k3');
    expect(change.match((f) => f, (_) => null), isA<CancellationScheduledFailure>());
  });

  test('demo: an unknown service is not found', () async {
    final result = await MockSubscriberRepository().cancel('nope', 'Moving', idempotencyKey: 'k1');
    expect(result.match((f) => f, (_) => null), isA<NotFoundFailure>());
  });
}
