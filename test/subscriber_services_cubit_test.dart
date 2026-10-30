import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/services_cubit.dart';

import 'helpers/subscriber_service_fixtures.dart';

class FakeSubscriberRepository implements SubscriberRepository {
  FakeSubscriberRepository({this.services = const [], this.failure});

  List<SubscriberService> services;
  Failure? failure;

  /// When set, listServices waits for it (to observe the loading state).
  Completer<void>? gate;

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async => const Right(null);

  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async {
    await gate?.future;
    return failure != null ? Left(failure!) : Right(services);
  }

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async {
    if (failure != null) return Left(failure!);
    final match = services.where((s) => s.id == id);
    return match.isEmpty ? const Left(NotFoundFailure()) : Right(match.first);
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
    return cancelResult ?? Right(testService(id: serviceId, cancelEffectiveOn: DateTime.utc(2026, 11, 30)));
  }
  @override
  Future<Either<Failure, SubscriberSignup>> signup({
    required String planId,
    required String termsVersion,
    required String idempotencyKey,
    String? installAddress,
  }) async => throw UnimplementedError('signup');
}

void main() {
  test('no account / no services: loaded and empty', () async {
    final cubit = ServicesCubit(FakeSubscriberRepository());
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, ServicesStatus.loaded);
    expect(cubit.state.services, isEmpty);
  });

  test('two services keep API order; cancelled ones move to past', () async {
    final repo = FakeSubscriberRepository(
      services: [
        testService(id: 'a', status: ServiceStatus.pending),
        testService(id: 'b', status: ServiceStatus.cancelled),
        testService(id: 'c'),
      ],
    );
    final cubit = ServicesCubit(repo);
    await Future<void>.delayed(Duration.zero);
    expect([for (final s in cubit.state.current) s.id], ['a', 'c']);
    expect([for (final s in cubit.state.past) s.id], ['b']);
  });

  test('failure, then retry succeeds', () async {
    final repo = FakeSubscriberRepository(failure: const NetworkFailure());
    final cubit = ServicesCubit(repo);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, ServicesStatus.failure);
    expect(cubit.state.failure, isA<NetworkFailure>());
    repo
      ..failure = null
      ..services = [testService()];
    await cubit.load();
    expect(cubit.state.status, ServicesStatus.loaded);
    expect(cubit.state.services, hasLength(1));
  });

  test('a failed pull-to-refresh keeps the list on screen', () async {
    final repo = FakeSubscriberRepository(services: [testService()]);
    final cubit = ServicesCubit(repo);
    await Future<void>.delayed(Duration.zero);
    repo.failure = const NetworkFailure();
    await cubit.load(keepVisible: true);
    expect(cubit.state.status, ServicesStatus.loaded);
    expect(cubit.state.services, hasLength(1));
  });

  test('detail: found, failed refresh keeps it, unknown id is not found', () async {
    final repo = FakeSubscriberRepository(services: [testService(id: 'a')]);
    final found = ServiceDetailCubit(repo, 'a');
    await Future<void>.delayed(Duration.zero);
    expect(found.state.service?.id, 'a');
    repo.failure = const NetworkFailure();
    await found.load(keepVisible: true);
    expect(found.state.status, ServiceDetailStatus.loaded);

    repo.failure = null;
    final missing = ServiceDetailCubit(repo, 'zzz');
    await Future<void>.delayed(Duration.zero);
    expect(missing.state.status, ServiceDetailStatus.failure);
    expect(missing.state.failure, isA<NotFoundFailure>());
  });
}
