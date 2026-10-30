import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

void main() {
  test('the demo offers one plan of each kind', () async {
    final list = (await MockSubscriberPlansRepository().list()).getOrElse((_) => throw StateError('failed'));
    expect(list.map((p) => p.kind).toSet(), SubscriberPlanKind.values.toSet());
  });

  test('the demo account has one active service that matches its counts and plan', () async {
    final repo = MockSubscriberRepository();
    final account = (await repo.getAccount()).getOrElse((_) => throw StateError('failed'))!;
    final services = (await repo.listServices()).getOrElse((_) => throw StateError('failed'));
    expect(services.single.status, ServiceStatus.active);
    expect(account.serviceCounts.active, services.length);
    final plans = (await MockSubscriberPlansRepository().list()).getOrElse((_) => throw StateError('failed'));
    expect(plans.map((p) => p.id), contains(services.single.planId));
    expect((await repo.getService(services.single.id)).isRight(), isTrue);
    expect((await repo.getService('nope')).match((f) => f, (_) => null), isA<NotFoundFailure>());
  });
}
