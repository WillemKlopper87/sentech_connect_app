import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

import 'helpers/test_setup.dart';

const _sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');

class _SlowRepository implements TenantRepository {
  _SlowRepository({this.failure});

  final Failure? failure;
  final gate = Completer<void>();

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async {
    await gate.future;
    final failure = this.failure;
    return failure == null ? const Right(TenantDirectory([_sentech])) : Left(failure);
  }

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(AppConfig(
        tenant: _sentech,
        minAppVersion: '1.0.0',
        featureFlags: FeatureFlags.demo,
        legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'),
      ));
}

void main() {
  setUpAppTests();

  testWidgets('the splash waits for the tenant to settle, then continues to login', (tester) async {
    final repo = _SlowRepository();
    locator.registerLazySingleton<TenantRepository>(() => repo);
    await tester.pumpWidget(const SentechConnectApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500)); // past the splash delay
    expect(find.text('Hello!'), findsNothing, reason: 'tenant still loading');

    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Hello!'), findsOneWidget);
  });

  testWidgets('a tenant directory failure settles on the picker with a retry, not a hang', (tester) async {
    final repo = _SlowRepository(failure: const NetworkFailure());
    locator.registerLazySingleton<TenantRepository>(() => repo);
    await tester.pumpWidget(const SentechConnectApp());
    await tester.pump();
    repo.gate.complete();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Choose your internet provider'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
