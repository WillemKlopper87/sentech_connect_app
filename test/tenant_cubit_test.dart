import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
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
  int skipped = 0;
  Failure? listFailure;
  final configs = <String, Either<Failure, AppConfig>>{
    'sentech': Right(configFor(_sentech)),
    'acme-wifi': Right(configFor(_acme)),
  };
  final calls = <String>[];

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async {
    calls.add('list');
    final failure = listFailure;
    return failure == null ? Right(TenantDirectory(tenants, skipped: skipped)) : Left(failure);
  }

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    calls.add('config:$slug');
    return configs[slug] ?? const Left(NotFoundFailure());
  }
}

class _ThrowingPrefs extends InMemoryTenantPreferences {
  _ThrowingPrefs({this.throwOnLoad = false, this.throwOnSave = false});

  final bool throwOnLoad;
  final bool throwOnSave;

  @override
  Future<String?> loadSlug() async => throwOnLoad ? throw StateError('prefs unavailable') : super.loadSlug();

  @override
  Future<void> saveSlug(String value) async =>
      throwOnSave ? throw StateError('prefs unavailable') : super.saveSlug(value);
}

/// Answers `getAppConfig` only when told to, to test closing mid-flight.
class _GatedRepository implements TenantRepository {
  final gate = Completer<void>();

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => const Right(TenantDirectory([_sentech]));

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    await gate.future;
    return Right(configFor(_sentech));
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

  TenantCubit build({
    String version = '1.0.0',
    Future<void> Function()? onChanging,
    Future<void> Function(String slug)? onApplied,
  }) =>
      TenantCubit(
        repository: repo,
        context: context,
        preferences: prefs,
        currentAppVersion: version,
        onTenantChanging: onChanging,
        onTenantApplied: onApplied,
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

  test('a single usable tenant is NOT auto-selected when other directory entries were skipped', () async {
    repo.skipped = 1; // the skipped entry might be the one the customer wants
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.needsSelection);
    expect(cubit.state.tenants, [_sentech]);
    expect(repo.calls, ['list'], reason: 'no app-config was loaded for a guessed tenant');
    expect(prefs.slug, isNull);
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

  group('the stored session is checked against EVERY activated tenant (R-m8)', () {
    test('the very first activation reports its slug, before the app is ready', () async {
      final applied = <String>[];
      TenantStatus? statusWhenApplied;
      late final TenantCubit cubit;
      cubit = build(onApplied: (slug) async {
        applied.add(slug);
        statusWhenApplied = cubit.state.status;
      });
      await cubit.bootstrap();
      expect(applied, ['sentech']);
      expect(statusWhenApplied, TenantStatus.loading);
      expect(cubit.state.status, TenantStatus.ready);
      await cubit.close();
    });

    test('a saved tenant, a cached offline config and a cancelled picker all report too', () async {
      prefs
        ..slug = 'sentech'
        ..configJson = jsonEncode(configFor(_sentech).toJson());
      repo.configs['sentech'] = const Left(NetworkFailure());
      repo.tenants = [_sentech, _acme];
      final applied = <String>[];
      final cubit = build(onApplied: (slug) async => applied.add(slug));
      await cubit.bootstrap(); // offline: cached
      repo.configs['sentech'] = Right(configFor(_sentech));
      await cubit.openPicker();
      await cubit.cancelPicker();
      expect(applied, ['sentech', 'sentech']);
      await cubit.close();
    });

    test('a failing check keeps the app out of ready (retryable) instead of showing a mismatched session', () async {
      var fail = true;
      final cubit = build(onApplied: (_) async {
        if (fail) throw StateError('storage');
      });
      await cubit.bootstrap();
      expect(cubit.state.status, TenantStatus.failure);
      fail = false;
      await cubit.retry();
      expect(cubit.state.status, TenantStatus.ready);
      await cubit.close();
    });
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
    await cubit.cancelPicker();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    await cubit.close();
  });

  group('every tenant change signs out first (R-m5)', () {
    test('a saved tenant that disappears signs out before the replacement is auto-selected', () async {
      prefs.slug = 'gone-isp';
      final cubit = build(onChanging: () async => repo.calls.add('sign-out'));
      await cubit.bootstrap();
      expect(repo.calls, ['config:gone-isp', 'sign-out', 'list', 'config:sentech']);
      expect(cubit.state.config!.tenant, _sentech);
      await cubit.close();
    });

    test('retry() from the update gate signs out when the tenant has since disappeared', () async {
      repo.tenants = [_acme];
      prefs.slug = 'sentech';
      repo.configs['sentech'] = Right(configFor(_sentech, min: '2.0.0'));
      final cubit = build(onChanging: () async => repo.calls.add('sign-out'));
      await cubit.bootstrap();
      expect(cubit.state.status, TenantStatus.updateRequired);
      repo.calls.clear();

      repo.configs['sentech'] = const Left(NotFoundFailure());
      await cubit.retry();
      expect(repo.calls, ['config:sentech', 'sign-out', 'list', 'config:acme-wifi']);
      expect(cubit.state.config!.tenant, _acme);
      await cubit.close();
    });

    test('retry() of the same tenant does not sign out', () async {
      var signOuts = 0;
      prefs.slug = 'sentech';
      repo.configs['sentech'] = Right(configFor(_sentech, min: '2.0.0'));
      final cubit = build(onChanging: () async => signOuts++);
      await cubit.bootstrap();
      repo.configs['sentech'] = Right(configFor(_sentech));
      await cubit.retry();
      expect(cubit.state.status, TenantStatus.ready);
      expect(signOuts, 0);
      await cubit.close();
    });

    test('retrying a failed switch signs out once, not again', () async {
      var signOuts = 0;
      final cubit = build(onChanging: () async => signOuts++);
      await cubit.bootstrap();
      repo.configs['acme-wifi'] = const Left(NetworkFailure());
      await cubit.select(_acme);
      expect(cubit.state.status, TenantStatus.failure);
      repo.configs['acme-wifi'] = Right(configFor(_acme));
      await cubit.retry();
      expect(cubit.state.config!.tenant, _acme);
      expect(signOuts, 1);
      await cubit.close();
    });

    test('a failed switch keeps slug, config and legal versions consistent', () async {
      final cubit = build(onChanging: () async {});
      await cubit.bootstrap();
      repo.configs['acme-wifi'] = const Left(NetworkFailure());
      await cubit.select(_acme);
      expect(cubit.state.status, TenantStatus.failure);
      expect(cubit.state.config!.tenant, _sentech);
      expect(context.slug, 'sentech');
      expect(context.termsVersion, '2026-09-30');
      await cubit.close();
    });

    test('a failing sign-out blocks the switch and shows a failure instead of throwing', () async {
      final cubit = build(onChanging: () async => throw StateError('keystore'));
      await cubit.bootstrap();
      repo.calls.clear();
      await cubit.select(_acme);
      expect(cubit.state.status, TenantStatus.failure);
      expect(cubit.state.config!.tenant, _sentech);
      expect(context.slug, 'sentech');
      expect(repo.calls, isEmpty, reason: 'the new tenant must not be loaded');
      await cubit.close();
    });

    test('a second tap while switching is ignored', () async {
      var signOuts = 0;
      final cubit = build(onChanging: () async => signOuts++);
      await cubit.bootstrap();
      repo.calls.clear();
      await Future.wait([cubit.select(_acme), cubit.select(_acme)]);
      expect(signOuts, 1);
      expect(repo.calls, ['config:acme-wifi']);
      await cubit.close();
    });
  });

  group('untrusted and failing storage (R-m5)', () {
    test('a tampered saved slug is dropped, the customer is signed out and the directory is used', () async {
      var signOuts = 0;
      prefs.slug = 'Bad Slug/../';
      final cubit = build(onChanging: () async => signOuts++);
      await cubit.bootstrap();
      expect(cubit.state.status, TenantStatus.ready);
      expect(cubit.state.config!.tenant, _sentech);
      expect(signOuts, 1);
      expect(prefs.slug, 'sentech');
      await cubit.close();
    });

    test('preferences that throw on read end in a failure, never a hang', () async {
      final cubit = TenantCubit(repository: repo, context: context, preferences: _ThrowingPrefs(throwOnLoad: true));
      await cubit.bootstrap();
      expect(cubit.state.status, TenantStatus.failure);
      expect(cubit.state.isSettled, isTrue);
      await cubit.close();
    });

    test('preferences that throw on write do not stop a loaded config', () async {
      final cubit = TenantCubit(repository: repo, context: context, preferences: _ThrowingPrefs(throwOnSave: true));
      await cubit.bootstrap();
      expect(cubit.state.status, TenantStatus.ready);
      await cubit.close();
    });

    test('a cached config for a different tenant is rejected', () async {
      prefs
        ..slug = 'acme-wifi'
        ..configJson = jsonEncode(configFor(_sentech).toJson());
      repo.configs['acme-wifi'] = const Left(NetworkFailure());
      final cubit = build();
      await cubit.bootstrap();
      expect(cubit.state.status, TenantStatus.failure);
      expect(cubit.state.config, isNull);
      await cubit.close();
    });

    test('malformed cached config is ignored', () async {
      for (final raw in ['not json', '[1,2]', '{"a":1}', '{"tenant":{"slug":5}}']) {
        prefs
          ..slug = 'sentech'
          ..configJson = raw;
        repo.configs['sentech'] = const Left(NetworkFailure());
        final cubit = build();
        await cubit.bootstrap();
        expect(cubit.state.status, TenantStatus.failure, reason: raw);
        await cubit.close();
      }
    });

    test('nothing is applied or saved once the cubit is closed mid-load', () async {
      final gated = _GatedRepository();
      prefs.slug = 'sentech';
      final cubit = TenantCubit(repository: gated, context: context, preferences: prefs);
      final pending = cubit.bootstrap();
      await cubit.close();
      gated.gate.complete();
      await pending;
      expect(prefs.configJson, isNull);
      expect(context.termsVersion, isNull);
    });

    test('Retry after a failed directory reload reloads the directory, not the current tenant', () async {
      repo.tenants = [_sentech, _acme];
      prefs.slug = 'sentech';
      final cubit = build();
      await cubit.bootstrap();
      repo.listFailure = const NetworkFailure();
      await cubit.openPicker();
      expect(cubit.state.status, TenantStatus.failure);

      repo.listFailure = null;
      await cubit.retry();
      expect(cubit.state.status, TenantStatus.needsSelection);
      expect(cubit.state.tenants, [_sentech, _acme]);
      await cubit.close();
    });
  });
}
