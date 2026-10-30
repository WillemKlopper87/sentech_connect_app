import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/signup_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/signup_page.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

import 'helpers/pump_themed.dart';
import 'signup_cubit_test.dart' show FakePlans, SignupRepo, hotspot;

const _acme = Tenant(slug: 'acme-wifi', name: 'Acme Wi-Fi', type: 'reseller');

AppConfig _config(String terms) => AppConfig(
  tenant: _acme,
  minAppVersion: '1.0.0',
  featureFlags: const FeatureFlags(hotspotPasses: true, rica: false, cpe: false),
  legal: LegalVersions(terms: terms, privacy: '2026-09-29'),
);

class _Repo implements TenantRepository {
  Either<Failure, AppConfig> reply = Right(_config('2026-09-30'));
  var calls = 0;

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    calls++;
    return reply;
  }

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => const Right(TenantDirectory([_acme]));
}

void main() {
  group('TenantCubit.refreshConfig', () {
    late _Repo repo;
    late InMemoryTenantPreferences prefs;
    late TenantContext context;
    late TenantCubit cubit;

    setUp(() async {
      repo = _Repo();
      prefs = InMemoryTenantPreferences(slug: 'acme-wifi');
      context = TenantContext();
      cubit = TenantCubit(repository: repo, context: context, preferences: prefs);
      addTearDown(cubit.close);
      await cubit.bootstrap();
    });

    test('applies the new terms version without a loading state', () async {
      repo.reply = Right(_config('2026-10-30'));
      final statuses = <TenantStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));
      expect(await cubit.refreshConfig(), isTrue);
      await sub.cancel();
      expect(cubit.state.config!.legal.terms, '2026-10-30');
      expect(context.termsVersion, '2026-10-30');
      expect(statuses, everyElement(TenantStatus.ready));
      expect(repo.calls, 2);
    });

    test('a failed reload keeps the current config and answers false', () async {
      repo.reply = const Left(NetworkFailure());
      expect(await cubit.refreshConfig(), isFalse);
      expect(cubit.state.config!.legal.terms, '2026-09-30');
      expect(cubit.state.status, TenantStatus.ready);
    });

    test('without a ready tenant it does not call the platform', () async {
      final idle = TenantCubit(repository: repo, context: TenantContext(), preferences: InMemoryTenantPreferences());
      addTearDown(idle.close);
      final before = repo.calls;
      expect(await idle.refreshConfig(), isFalse);
      expect(repo.calls, before);
    });
  });

  group('SignupCubit on consent_version_outdated', () {
    late SignupRepo repo;
    var terms = '2026-09-30';
    var refreshes = 0;
    var keyCount = 0;

    Future<SignupCubit> ready({bool reloadChanges = true, bool reloadFails = false}) async {
      keyCount = 0;
      refreshes = 0;
      terms = '2026-09-30';
      final c = SignupCubit(
        FakePlans([hotspot]),
        repo,
        'p-hot',
        termsVersion: () => terms,
        newKey: () => 'key-${++keyCount}',
        refreshTerms: () async {
          refreshes++;
          if (reloadFails) return false;
          if (reloadChanges) terms = '2026-10-30';
          return true;
        },
      );
      await c.stream.firstWhere((s) => s.phase == SignupPhase.ready);
      return c;
    }

    setUp(() => repo = SignupRepo());

    test('reloads once, clears the acceptance, and the next submit sends the new version with a new key', () async {
      final c = await ready();
      c.setAcceptTerms(true);
      repo.replies.add(const Left(ConsentVersionOutdatedFailure()));
      await c.submit();
      expect(refreshes, 1);
      expect(c.state.phase, SignupPhase.ready);
      expect(c.state.failure, isA<ConsentVersionOutdatedFailure>());
      expect(c.state.acceptTerms, isFalse, reason: 'the new terms have not been seen');
      await c.submit();
      expect(repo.calls, hasLength(1), reason: 'no automatic retry, no loop');
      c.setAcceptTerms(true);
      await c.submit();
      expect(repo.calls.map((x) => x.termsVersion), ['2026-09-30', '2026-10-30']);
      expect(repo.calls.map((x) => x.key), ['key-1', 'key-2']);
      expect(c.state.phase, SignupPhase.done);
      expect(refreshes, 1);
      await c.close();
    });

    test('the platform still refusing reloads once per attempt and never loops', () async {
      final c = await ready(reloadChanges: false);
      c.setAcceptTerms(true);
      repo.replies.addAll([const Left(ConsentVersionOutdatedFailure()), const Left(ConsentVersionOutdatedFailure())]);
      await c.submit();
      expect(refreshes, 1);
      expect(c.state.acceptTerms, isTrue, reason: 'the version did not change, nothing new to read');
      await c.submit();
      expect(refreshes, 2);
      expect(repo.calls, hasLength(2));
      await c.close();
    });

    test('a failed reload still shows the refusal and keeps the form', () async {
      final c = await ready(reloadFails: true);
      c.setAcceptTerms(true);
      repo.replies.add(const Left(ConsentVersionOutdatedFailure()));
      await c.submit();
      expect(c.state.failure, isA<ConsentVersionOutdatedFailure>());
      expect(c.state.phase, SignupPhase.ready);
      await c.close();
    });

    test('other refusals do not reload the config', () async {
      final c = await ready();
      c.setAcceptTerms(true);
      repo.replies.add(const Left(NetworkFailure()));
      await c.submit();
      expect(refreshes, 0);
      await c.close();
    });

    testWidgets('the page shows the refusal and the unticked box', (tester) async {
      final c = await ready();
      addTearDown(c.close);
      repo.replies.add(const Left(ConsentVersionOutdatedFailure()));
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: c,
          child: SignupPage(onPayNow: (_) {}, onPayLater: (_) {}, onStartIdCheck: null, onBackToPlans: () {}),
        ),
        size: const Size(390, 1800),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.text('The terms were updated. Please review and accept the latest version.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('signup-terms'))).value, isFalse);
    });
  });
}
