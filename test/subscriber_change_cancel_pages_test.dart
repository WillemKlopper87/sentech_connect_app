import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/change_plan_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/change_plan_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/service_detail_page.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

import 'helpers/fake_subscriber_repository.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';
import 'helpers/subscriber_service_fixtures.dart';

class _TenantRepo implements TenantRepository {
  _TenantRepo(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> _tenant({required bool billing}) async {
  final config = AppConfig.fromJson({
    ...fixtureMap('app_config.json'),
    'modules': {'subscriber_billing': billing},
  });
  final cubit = TenantCubit(
    repository: _TenantRepo(config),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  addTearDown(cubit.close);
  await cubit.bootstrap();
  return cubit;
}

class _Plans implements SubscriberPlansRepository {
  _Plans(this.plans);
  final List<SubscriberPlan> plans;
  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async => Right(plans);
}

SubscriberPlan _plan(String id, String name, int cents, {bool kyc = false}) => SubscriberPlan(
  id: id,
  code: id,
  name: name,
  description: '',
  kind: SubscriberPlanKind.recurringHotspot,
  kycRequired: kyc,
  priceCents: cents,
  setupFeeCents: 0,
  downKbps: 5000,
  upKbps: 2500,
  maxDevices: 3,
  fupAction: 'none',
);

final _plans = [
  _plan('plan-1', 'Home Hotspot 10', 19900),
  _plan('plan-lo', 'Home Hotspot 5', 12900),
  _plan('plan-hi', 'Home Hotspot 20', 29900, kyc: true),
];

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<void> pumpDetail(
    WidgetTester tester,
    FakeSubscriberRepository repo, {
    TenantCubit? tenant,
    bool withPlans = true,
  }) async {
    final detail = ServiceDetailCubit(repo, repo.service.id);
    addTearDown(detail.close);
    Widget child = BlocProvider.value(
      value: detail,
      child: ServiceDetailPage(plansRepository: withPlans ? _Plans(_plans) : null),
    );
    if (tenant != null) child = BlocProvider.value(value: tenant, child: child);
    await pumpThemed(tester, child, size: const Size(390, 1600));
    await tester.pumpAndSettle();
  }

  group('service detail: which actions are offered', () {
    testWidgets('active: Change plan and Cancel service', (tester) async {
      await pumpDetail(tester, FakeSubscriberRepository(service: testService(paidThrough: DateTime.utc(2026, 11, 30))));
      expect(find.byKey(const Key('service-change-plan')), findsOneWidget);
      expect(find.byKey(const Key('service-cancel')), findsOneWidget);
      expect(find.byKey(const Key('cancel-no-undo')), findsNothing);
    });

    testWidgets('suspended: both are still offered', (tester) async {
      await pumpDetail(
        tester,
        FakeSubscriberRepository(service: testService(status: ServiceStatus.suspended, suspendReason: SuspendReason.nonPayment)),
      );
      expect(find.byKey(const Key('service-change-plan')), findsOneWidget);
      expect(find.byKey(const Key('service-cancel')), findsOneWidget);
    });

    testWidgets('pending: no buttons, an explanation for each', (tester) async {
      await pumpDetail(
        tester,
        FakeSubscriberRepository(
          service: testService(status: ServiceStatus.pending, activationBlocker: ActivationBlocker.firstInvoiceUnpaid),
        ),
      );
      expect(find.byKey(const Key('service-change-plan')), findsNothing);
      expect(find.byKey(const Key('service-cancel')), findsNothing);
      expect(find.text('Available once your service is active.'), findsOneWidget);
      expect(find.text('Contact support to cancel a service that has not started.'), findsOneWidget);
    });

    testWidgets('cancellation scheduled: no buttons, the reason, and the honest no-undo note', (tester) async {
      await pumpDetail(
        tester,
        FakeSubscriberRepository(service: testService(paidThrough: DateTime.utc(2026, 11, 30), cancelEffectiveOn: DateTime.utc(2026, 11, 30))),
      );
      expect(find.byKey(const Key('service-change-plan')), findsNothing);
      expect(find.byKey(const Key('service-cancel')), findsNothing);
      expect(find.text('Not available while cancellation is scheduled.'), findsOneWidget);
      expect(find.text('Ends on Nov 30, 2026'), findsOneWidget);
      expect(
        find.text('A scheduled cancellation cannot be undone in the app. Contact your provider if you changed your mind.'),
        findsOneWidget,
      );
      expect(find.textContaining('Undo'), findsNothing);
    });

    testWidgets('cancelled: nothing at all', (tester) async {
      await pumpDetail(
        tester,
        FakeSubscriberRepository(service: testService(status: ServiceStatus.cancelled, cancelledAt: DateTime.utc(2026, 10, 1))),
      );
      expect(find.byKey(const Key('service-change-plan')), findsNothing);
      expect(find.byKey(const Key('service-cancel')), findsNothing);
      expect(find.byKey(const Key('change-blocked')), findsNothing);
      expect(find.byKey(const Key('cancel-contact-support')), findsNothing);
      expect(find.byKey(const Key('cancel-no-undo')), findsNothing);
    });

    testWidgets('module off: actions hidden even on an active service', (tester) async {
      final tenant = await _tenant(billing: false);
      await pumpDetail(tester, FakeSubscriberRepository(service: testService()), tenant: tenant);
      expect(find.byKey(const Key('service-change-plan')), findsNothing);
      expect(find.byKey(const Key('service-cancel')), findsNothing);
    });

    testWidgets('module on: actions offered', (tester) async {
      final tenant = await _tenant(billing: true);
      await pumpDetail(tester, FakeSubscriberRepository(service: testService()), tenant: tenant);
      expect(find.byKey(const Key('service-change-plan')), findsOneWidget);
      expect(find.byKey(const Key('service-cancel')), findsOneWidget);
    });

    testWidgets('without a plans source the Change plan action is not offered', (tester) async {
      await pumpDetail(tester, FakeSubscriberRepository(service: testService()), withPlans: false);
      expect(find.byKey(const Key('service-change-plan')), findsNothing);
      expect(find.byKey(const Key('service-cancel')), findsOneWidget);
    });
  });

  group('change plan flow from the service detail', () {
    testWidgets('pick a higher plan, see the "switches now" sentence, confirm, see the result, and the service refreshes', (tester) async {
      final repo = FakeSubscriberRepository(service: testService())
        ..changeResult = Right(PlanChange(applied: true, effectiveOn: DateTime.utc(2026, 11, 3), prorationInvoiceId: 'inv-9'));
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-change-plan')));
      await tester.pumpAndSettle();
      // The current plan and other kinds are not offered; the cheaper one is listed first.
      expect(find.text('Your plan: Home Hotspot 10'), findsOneWidget);
      expect(find.byKey(const Key('plan-plan-1')), findsNothing);
      expect(find.byKey(const Key('plan-plan-lo')), findsOneWidget);
      expect(find.text('ID check needed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-plan-hi')));
      await tester.pumpAndSettle();
      expect(find.text('Change to Home Hotspot 20?'), findsOneWidget);
      expect(
        find.text('Switches now. You will be invoiced the difference for the rest of this month.'),
        findsOneWidget,
      );
      final readsBefore = repo.getServiceCalls.length;
      await tester.tap(find.byKey(const Key('change-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Plan changed'), findsOneWidget);
      expect(find.text('You are now on Home Hotspot 20.'), findsOneWidget);
      expect(find.byKey(const Key('change-view-invoice')), findsOneWidget);
      expect(repo.changeCalls.single.planId, 'plan-hi');
      await tester.tap(find.byKey(const Key('change-done')));
      await tester.pumpAndSettle();
      expect(find.text('Service details'), findsOneWidget);
      expect(repo.getServiceCalls.length, greaterThan(readsBefore));
    });

    testWidgets('pick a lower plan: scheduled sentence with the first of next month, no invoice button', (tester) async {
      final repo = FakeSubscriberRepository(service: testService())
        ..changeResult = Right(PlanChange(applied: false, effectiveOn: DateTime.utc(2026, 12, 1)));
      final cubit = ChangePlanCubit(repo, _Plans(_plans), repo.service);
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(value: cubit, child: ChangePlanPage(clock: () => DateTime.utc(2026, 11, 14, 10))),
        size: const Size(390, 1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-plan-lo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('change-sentence')), findsOneWidget);
      expect(
        find.text('Takes effect on Dec 1, 2026. Until then you keep your current plan.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('change-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Plan change scheduled'), findsOneWidget);
      expect(find.text('Scheduled for Dec 1, 2026. Until then you keep your current plan.'), findsOneWidget);
      expect(find.byKey(const Key('change-view-invoice')), findsNothing);
    });

    testWidgets('the picker can go back to choose again', (tester) async {
      final repo = FakeSubscriberRepository(service: testService());
      final cubit = ChangePlanCubit(repo, _Plans(_plans), repo.service);
      addTearDown(cubit.close);
      await pumpThemed(tester, BlocProvider.value(value: cubit, child: const ChangePlanPage()), size: const Size(390, 1200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-plan-lo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-plan-hi')), findsOneWidget);
    });

    testWidgets('no other plan of this kind: the empty state', (tester) async {
      final repo = FakeSubscriberRepository(service: testService());
      final cubit = ChangePlanCubit(repo, _Plans([_plans.first]), repo.service);
      addTearDown(cubit.close);
      await pumpThemed(tester, BlocProvider.value(value: cubit, child: const ChangePlanPage()));
      await tester.pumpAndSettle();
      expect(find.text('There are no other plans you can switch to right now.'), findsOneWidget);
    });

    testWidgets('plans failing to load: failure view and retry', (tester) async {
      final repo = FakeSubscriberRepository(service: testService());
      final failing = _FailingPlans();
      final cubit = ChangePlanCubit(repo, failing, repo.service);
      addTearDown(cubit.close);
      await pumpThemed(tester, BlocProvider.value(value: cubit, child: const ChangePlanPage()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      failing.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-plan-lo')), findsOneWidget);
    });

    testWidgets('a billed-next-period refusal is shown on the confirmation, which stays open', (tester) async {
      final repo = FakeSubscriberRepository(service: testService())..changeResult = const Left(PlanChangeBilledFailure());
      final cubit = ChangePlanCubit(repo, _Plans(_plans), repo.service);
      addTearDown(cubit.close);
      await pumpThemed(tester, BlocProvider.value(value: cubit, child: const ChangePlanPage()), size: const Size(390, 1200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-plan-lo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Your next period is already billed. Try again after it starts.'), findsOneWidget);
      expect(find.byKey(const Key('change-confirm')), findsOneWidget);
      expect(find.byKey(const Key('change-id-check')), findsNothing);
    });

    testWidgets('an ID check refusal offers the ID check, and leaving carries its route', (tester) async {
      final repo = FakeSubscriberRepository(service: testService())..changeResult = const Left(KycRequiredFailure());
      ChangePlanExit? exit;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                exit = await Navigator.of(context).push<ChangePlanExit>(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => ChangePlanCubit(repo, _Plans(_plans), repo.service),
                      child: const ChangePlanPage(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
        size: const Size(390, 1200),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-plan-hi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('You need an ID check first.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('change-id-check')));
      await tester.pumpAndSettle();
      expect(exit?.route, AppRoutes.kyc);
      expect(exit?.changed, isFalse);
    });

    testWidgets('the invoice button leaves with the invoice route', (tester) async {
      final repo = FakeSubscriberRepository(service: testService())
        ..changeResult = Right(PlanChange(applied: true, effectiveOn: DateTime.utc(2026, 11, 3), prorationInvoiceId: 'inv-9'));
      ChangePlanExit? exit;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                exit = await Navigator.of(context).push<ChangePlanExit>(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => ChangePlanCubit(repo, _Plans(_plans), repo.service),
                      child: const ChangePlanPage(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
        size: const Size(390, 1200),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-plan-hi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-view-invoice')));
      await tester.pumpAndSettle();
      expect(exit?.route, AppRoutes.invoiceFor('inv-9'));
      expect(exit?.changed, isTrue);
    });
  });

  group('cancel flow from the service detail', () {
    FakeSubscriberRepository active() => FakeSubscriberRepository(service: testService(paidThrough: DateTime.utc(2026, 11, 30)));

    testWidgets('the dialog states the end date from paid_through and that it cannot be undone in the app', (tester) async {
      await pumpDetail(tester, active());
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      expect(
        find.text('Your service stays active until Nov 30, 2026. After that it stops and you will not be billed again.'),
        findsOneWidget,
      );
      expect(find.text('This cannot be undone in the app.'), findsOneWidget);
      for (final label in ['I am moving', 'Too expensive', 'Not reliable enough', 'Other']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('without paid_through the end date is the last day of the month', (tester) async {
      final repo = FakeSubscriberRepository(service: testService());
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      final now = DateTime.now().toUtc().add(const Duration(hours: 2));
      final last = DateTime.utc(now.year, now.month + 1, 0);
      final shown = tester.widget<Text>(find.byKey(const Key('cancel-body'))).data!;
      expect(shown, contains('${last.day}, ${last.year}'));
    });

    testWidgets('confirm without a reason asks for one and sends nothing', (tester) async {
      final repo = active();
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a reason.'), findsOneWidget);
      expect(repo.cancelCalls, isEmpty);
    });

    testWidgets('a reason with text is sent in English, the dialog closes, the service shows "Ends on", and it is re-read', (tester) async {
      final repo = active();
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-reason-tooExpensive')));
      await tester.enterText(find.byKey(const Key('cancel-detail')), 'Found a cheaper plan');
      await tester.pump();
      final readsBefore = repo.getServiceCalls.length;
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls.single.reason, 'Too expensive: Found a cheaper plan');
      expect(find.byKey(const Key('cancel-confirm')), findsNothing);
      expect(find.text('Cancellation scheduled for Nov 30, 2026'), findsOneWidget);
      expect(find.text('Ends on Nov 30, 2026'), findsOneWidget);
      expect(find.byKey(const Key('service-cancel')), findsNothing);
      expect(find.byKey(const Key('cancel-no-undo')), findsOneWidget);
      expect(repo.getServiceCalls.length, greaterThan(readsBefore));
    });

    testWidgets('Keep service closes the dialog and sends nothing', (tester) async {
      final repo = active();
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-keep')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cancel-confirm')), findsNothing);
      expect(repo.cancelCalls, isEmpty);
      expect(find.byKey(const Key('service-cancel')), findsOneWidget);
    });

    testWidgets('offline keeps the dialog open with the offline wording; a retry then succeeds with the same key', (tester) async {
      final repo = active()..cancelResult = const Left(NetworkFailure());
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-reason-moving')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cancel-failure')), findsOneWidget);
      expect(find.byKey(const Key('cancel-confirm')), findsOneWidget);
      repo.cancelResult = Right(testService(paidThrough: DateTime.utc(2026, 11, 30), cancelEffectiveOn: DateTime.utc(2026, 11, 30)));
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls.map((c) => c.key).toSet(), hasLength(1));
      expect(repo.cancelCalls.map((c) => c.reason), ['Moving', 'Moving']);
      expect(find.byKey(const Key('cancel-confirm')), findsNothing);
      expect(find.text('Ends on Nov 30, 2026'), findsOneWidget);
    });

    testWidgets('a pending-service refusal shows the typed message in the dialog', (tester) async {
      final repo = active()..cancelResult = const Left(PendingCancelFailure());
      await pumpDetail(tester, repo);
      await tester.tap(find.byKey(const Key('service-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-reason-moving')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cancel-failure')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('cancel-failure'))).data, 'Contact support to cancel a service that has not started.');
    });
  });
}

class _FailingPlans implements SubscriberPlansRepository {
  bool fail = true;
  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async => fail ? const Left(NetworkFailure()) : Right(_plans);
}
