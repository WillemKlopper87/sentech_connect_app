import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

const _sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');
const _acme = Tenant(slug: 'acme-wifi', name: 'Acme Wi-Fi', type: 'reseller');

AppConfig configFor(Tenant tenant, {String min = '1.0.0'}) => AppConfig(
      tenant: tenant,
      minAppVersion: min,
      featureFlags: const FeatureFlags(hotspotPasses: true, rica: false, cpe: false),
      legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-29'),
    );

class _FakeTenantRepository implements TenantRepository {
  List<Tenant> tenants = const [_sentech];
  Failure? listFailure;
  final configs = <String, Either<Failure, AppConfig>>{
    'sentech': Right(configFor(_sentech)),
    'acme-wifi': Right(configFor(_acme)),
  };
  final calls = <String>[];

  @override
  Future<Either<Failure, List<Tenant>>> listTenants() async {
    calls.add('list');
    final failure = listFailure;
    return failure == null ? Right(tenants) : Left(failure);
  }

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    calls.add('config:$slug');
    return configs[slug] ?? const Left(NotFoundFailure());
  }
}

void main() {
  late _FakeTenantRepository repo;
  late TenantContext context;
  late InMemoryTenantPreferences prefs;

  setUp(() {
    repo = _FakeTenantRepository();
    context = TenantContext();
    prefs = InMemoryTenantPreferences();
  });

  TenantCubit build({String version = '1.0.0', Future<void> Function()? onChanging}) => TenantCubit(
        repository: repo,
        context: context,
        preferences: prefs,
        currentAppVersion: version,
        onTenantChanging: onChanging,
      );

  test('a single listed tenant is selected automatically and applied', () async {
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    expect(context.slug, 'sentech');
    expect(context.termsVersion, '2026-09-30');
    expect(context.privacyVersion, '2026-09-29');
    expect(prefs.slug, 'sentech');
    expect(prefs.configJson, isNotNull);
    await cubit.close();
  });

  test('several tenants and no saved choice ask the customer to pick', () async {
    repo.tenants = [_sentech, _acme];
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.needsSelection);
    expect(cubit.state.tenants, [_sentech, _acme]);
    await cubit.close();
  });

  test('a saved choice skips the directory', () async {
    prefs.slug = 'acme-wifi';
    final cubit = build();
    await cubit.bootstrap();
    expect(repo.calls, ['config:acme-wifi']);
    expect(cubit.state.config!.tenant, _acme);
    expect(context.slug, 'acme-wifi');
    await cubit.close();
  });

  test('an app older than min_app_version is gated', () async {
    repo.configs['sentech'] = Right(configFor(_sentech, min: '2.0.0'));
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.updateRequired);
    await cubit.close();
  });

  test('offline at launch falls back to the cached config of the saved tenant', () async {
    prefs
      ..slug = 'sentech'
      ..configJson = jsonEncode(configFor(_sentech).toJson());
    repo.configs['sentech'] = const Left(NetworkFailure());
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    await cubit.close();
  });

  test('offline with nothing cached shows a retryable failure', () async {
    repo.listFailure = const NetworkFailure();
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.failure);
    expect(cubit.state.failure, isA<NetworkFailure>());

    repo.listFailure = null;
    await cubit.retry();
    expect(cubit.state.status, TenantStatus.ready);
    await cubit.close();
  });

  test('a saved tenant that no longer exists sends the customer back to the directory', () async {
    prefs.slug = 'gone-isp';
    final cubit = build();
    await cubit.bootstrap();
    expect(repo.calls, ['config:gone-isp', 'list', 'config:sentech']);
    expect(cubit.state.config!.tenant, _sentech);
    expect(prefs.slug, 'sentech');
    await cubit.close();
  });

  test('switching tenant signs out FIRST, then loads the new tenant', () async {
    final events = <String>[];
    final cubit = build(onChanging: () async => events.add('sign-out'));
    await cubit.bootstrap();
    repo.calls.clear();

    await cubit.select(_acme);
    events.addAll(repo.calls);
    expect(events, ['sign-out', 'config:acme-wifi']);
    expect(cubit.state.config!.tenant, _acme);
    expect(context.slug, 'acme-wifi');
    expect(prefs.slug, 'acme-wifi');
    await cubit.close();
  });

  test('choosing the current tenant again does not sign out', () async {
    var signOuts = 0;
    final cubit = build(onChanging: () async => signOuts++);
    await cubit.bootstrap();
    await cubit.select(_sentech);
    expect(signOuts, 0);
    expect(cubit.state.status, TenantStatus.ready);
    await cubit.close();
  });

  test('the picker can be opened from Account and cancelled without changes', () async {
    repo.tenants = [_sentech, _acme];
    prefs.slug = 'sentech';
    final cubit = build();
    await cubit.bootstrap();
    await cubit.openPicker();
    expect(cubit.state.status, TenantStatus.needsSelection);
    cubit.cancelPicker();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    await cubit.close();
  });
}
