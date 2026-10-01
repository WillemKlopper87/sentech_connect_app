import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/pages/dashboard_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart'
    show orderFromJson;
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';

class _Passes implements PassesRepository {
  _Passes(this.results);

  final List<Either<Failure, List<Pass>>> results;
  var calls = 0;

  @override
  Future<Either<Failure, List<Pass>>> getPasses({
    bool includeExpired = false,
  }) async {
    final i = calls < results.length ? calls : results.length - 1;
    calls++;
    return results[i];
  }
}

/// Fixed instant: the card and the pass fixtures share it, so no test depends
/// on the wall clock.
final _now = DateTime.utc(2026, 10, 1, 12);

Pass _pass({
  int? dataMb = 1024,
  int used = 0,
  Duration left = const Duration(hours: 2),
}) => Pass(
  id: 'p',
  orderId: 'o',
  productName: 'Day Pass',
  status: PassStatus.active,
  startsAt: _now.subtract(const Duration(hours: 1)),
  expiresAt: _now.add(left),
  durationMinutes: 180,
  dataMb: dataMb,
  maxDevices: 1,
  usedBytes: used,
);

/// Dashboard WITHOUT an AccountCubit above it: the hotspot-only dashboard must
/// not need (or load) fixed-plan account data.
Future<PassesCubit> _pump(
  WidgetTester tester,
  PassesRepository repo, {
  VoidCallback? onBuy,
}) async {
  final passes = PassesCubit(repo);
  final open = OpenOrderCubit(
    MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero),
  );
  addTearDown(() {
    passes.close();
    open.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: passes),
          BlocProvider.value(value: open),
        ],
        child: DashboardPage(
          onTopUp: () {},
          onUpgrade: () {},
          onBuyPass: onBuy ?? () {},
          onOpenPasses: () {},
          onReportIssue: () {},
          onOpenPromotions: () {},
          onResumeOrder: (_) {},
          showRouterCard: false,
          now: () => _now,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return passes;
}

void main() {
  testWidgets(
    'a failed passes load shows an error and Retry, never "No active pass"; Retry recovers',
    (tester) async {
      final repo = _Passes([
        const Left(NetworkFailure()),
        Right([_pass()]),
      ]);
      await _pump(tester, repo);
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('No active pass'), findsNothing);
      expect(
        find.text('My passes'),
        findsNothing,
      ); // the card offers no purchase actions while errored
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'a genuinely empty result shows No active pass with a Buy a pass action',
    (tester) async {
      var bought = 0;
      await _pump(
        tester,
        _Passes([const Right(<Pass>[])]),
        onBuy: () => bought++,
      );
      expect(find.text('No active pass'), findsOneWidget);
      await tester.tap(find.text('Buy a pass').first);
      expect(bought, 1);
    },
  );

  testWidgets(
    'time-only pass shows Uncapped data; capped pass shows data left and a bar',
    (tester) async {
      await _pump(
        tester,
        _Passes([
          Right([_pass(dataMb: null)]),
        ]),
      );
      expect(find.text('Uncapped data'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('left'), findsOneWidget); // time left only
    },
  );

  testWidgets(
    'capped pass: data left text and bar; over-cap usage clamps at zero; zero cap has no bar',
    (tester) async {
      await _pump(
        tester,
        _Passes([
          Right([_pass(dataMb: 1024, used: 256 * 1024 * 1024)]),
        ]),
      );
      expect(find.text('768 MB of 1 GB left'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('over-cap usage never shows negative data', (tester) async {
    await _pump(
      tester,
      _Passes([
        Right([_pass(dataMb: 1024, used: 3 * 1024 * 1024 * 1024)]),
      ]),
    );
    expect(find.text('0 MB of 1 GB left'), findsOneWidget);
  });

  testWidgets('zero-cap pass shows text only, no progress bar', (tester) async {
    await _pump(
      tester,
      _Passes([
        Right([_pass(dataMb: 0)]),
      ]),
    );
    expect(find.text('0 MB of 0 MB left'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('an already-expired time shows 0m, never negative', (
    tester,
  ) async {
    await _pump(
      tester,
      _Passes([
        Right([_pass(left: const Duration(minutes: -10))]),
      ]),
    );
    expect(find.text('0m left'), findsOneWidget);
  });

  testWidgets('pull-to-refresh on the dashboard reloads the passes', (
    tester,
  ) async {
    final repo = _Passes([
      Right([_pass()]),
    ]);
    await _pump(tester, repo);
    expect(repo.calls, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('the minute ticker is cancelled when the dashboard goes away', (
    tester,
  ) async {
    await _pump(
      tester,
      _Passes([
        Right([_pass()]),
      ]),
    );
    await tester.pumpWidget(const SizedBox());
    // A leaked periodic timer would fail the test's pending-timer check.
  });

  testWidgets(
    'View my passes pushes the passes screen, and back returns to the confirmation',
    (tester) async {
      final order = orderFromJson(
        fixtureMap('order_draft.json')..['status'] = 'paid',
      );
      final store = InMemorySecureStore();
      await store.write('orders', '[${jsonEncode(order.toJson())}]');
      final cubit = OrderCubit(
        MockCheckoutRepository(store, latency: Duration.zero),
        order.id,
      );
      addTearDown(cubit.close);
      late final GoRouter router;
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => BlocProvider.value(
              value: cubit,
              child: ConfirmationPage(
                onDone: () {},
                onResume: (_) {},
                onViewPasses: () => router.push('/passes'),
              ),
            ),
          ),
          GoRoute(
            path: '/passes',
            builder: (context, state) => BlocProvider(
              create: (_) => PassesCubit(
                _Passes([
                  Right([_pass()]),
                ]),
              ),
              child: const MyPassesPage(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View my passes'));
      await tester.pumpAndSettle();
      expect(find.text('Day Pass'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('View my passes'), findsOneWidget);
    },
  );
}
