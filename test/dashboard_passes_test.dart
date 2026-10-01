import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/account_dashboard/data/repositories/mock_account_repository.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/bloc/account_cubit.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/pages/dashboard_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart'
    show orderFromJson;
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required bool showRouterCard,
  VoidCallback? onBuyPass,
  VoidCallback? onOpenPasses,
}) async {
  final account = AccountCubit(MockAccountRepository());
  final passes = PassesCubit(MockPassesRepository());
  final open = OpenOrderCubit(
    MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero),
  );
  addTearDown(() {
    account.close();
    passes.close();
    open.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: account),
          BlocProvider.value(value: passes),
          BlocProvider.value(value: open),
        ],
        child: DashboardPage(
          onTopUp: () {},
          onUpgrade: () {},
          onBuyPass: onBuyPass ?? () {},
          onOpenPasses: onOpenPasses ?? () {},
          onReportIssue: () {},
          onOpenPromotions: () {},
          onResumeOrder: (_) {},
          showRouterCard: showRouterCard,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('dashboard leads with hotspot passes', () {
    testWidgets(
      'cpe off: the current pass, time and data left, Buy a pass; no router or fixed-plan content',
      (tester) async {
        var bought = 0;
        await _pumpDashboard(
          tester,
          showRouterCard: false,
          onBuyPass: () => bought++,
        );
        expect(find.text('Day Pass'), findsOneWidget);
        expect(
          find.textContaining('left'),
          findsWidgets,
        ); // time left and data left
        expect(find.text('3.8 GB of 5 GB left'), findsOneWidget);
        expect(find.text('Living room router'), findsNothing);
        expect(find.textContaining('renews'), findsNothing);
        expect(find.textContaining('GB of 100GB'), findsNothing);
        expect(find.text('Upgrade'), findsNothing);
        await tester.tap(find.text('Buy a pass').first);
        expect(bought, 1);
      },
    );

    testWidgets(
      'cpe on: the router card and fixed-plan usage appear below the pass',
      (tester) async {
        await _pumpDashboard(tester, showRouterCard: true);
        expect(find.text('Day Pass'), findsOneWidget);
        expect(find.text('Living room router'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
      },
    );

    testWidgets('My passes opens the passes screen', (tester) async {
      var opened = 0;
      await _pumpDashboard(
        tester,
        showRouterCard: false,
        onOpenPasses: () => opened++,
      );
      await tester.tap(find.text('My passes'));
      expect(opened, 1);
    });
  });

  test('the demo tenant ships with the cpe flag off', () {
    expect(FeatureFlags.demo.cpe, isFalse);
    expect(FeatureFlags.demo.hotspotPasses, isTrue);
  });

  group('demo catalogue', () {
    testWidgets('hotspot passes come first, with ZAR prices and data caps', (tester) async {
      final cubit = CatalogCubit(MockCatalogRepository());
      addTearDown(cubit.close);
      await tester.pump(const Duration(seconds: 1)); // fake time: the mock's 400 ms delay
      expect(cubit.state.selectedCategory, ProductCategory.hotspotPass);
      expect(
        cubit.state.availableCategories.first,
        ProductCategory.hotspotPass,
      );
      final passes = cubit.state.visibleProducts;
      expect(passes.map((p) => p.name), [
        '1 Hour Pass',
        'Day Pass',
        '7 Day Pass',
        '30 Day Pass',
      ]);
      expect(passes.map((p) => p.priceCents), everyElement(greaterThan(0)));
      expect(passes.every((p) => p.dataDescription.contains('GB')), isTrue);
      // The physical products are still there, in later tabs.
      expect(cubit.state.availableCategories, contains(ProductCategory.home5g));
    });
  });

  testWidgets('a paid hotspot order offers View my passes', (tester) async {
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
    var viewed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: ConfirmationPage(
            onDone: () {},
            onResume: (_) {},
            onViewPasses: () => viewed++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View my passes'));
    expect(viewed, 1);
    expect(find.textContaining('RICA'), findsNothing);
    expect(find.textContaining('Router'), findsNothing);
  });
}
