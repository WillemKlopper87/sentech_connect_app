import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/connectivity_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/network/connectivity_service.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/checkout_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/coverage/data/repositories/mock_coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  test('ConnectivityCubit follows the connectivity service', () async {
    final service = FakeConnectivityService();
    final cubit = ConnectivityCubit(service);
    addTearDown(cubit.close);
    service.setOnline(false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isFalse);
    service.setOnline(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isTrue);
  });

  testWidgets('global offline banner appears and disappears with connectivity', (tester) async {
    await tester.pumpWidget(const SentechConnectApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsNothing);

    final connectivity = locator<ConnectivityService>() as FakeConnectivityService;
    connectivity.setOnline(false);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget); // screen state is preserved

    connectivity.setOnline(true);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("You're offline"), findsNothing);
  });

  group('retry UI', () {
    late SimulatedNetwork network;

    setUp(() => network = SimulatedNetwork());

    testWidgets('catalog: offline failure shows retry, then recovers', (tester) async {
      network.offline = true;
      final cubit = CatalogCubit(MockCatalogRepository(network));
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider(create: (_) => CartCubit()),
          ],
          child: CatalogPage(onOpenCart: () {}, onFindHotspots: () {}),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('Day Pass'), findsNothing);

      network.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('coverage: offline failure shows retry, then recovers', (tester) async {
      network.offline = true;
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider(
          create: (_) => CoverageCubit(MockCoverageRepository(network)),
          child: CoveragePage(onCovered: () {}),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining("You're offline"), findsOneWidget);

      network.offline = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('5G FWA available'), findsOneWidget);
    });

    testWidgets('checkout: a failed order creation shows retry, then continues', (tester) async {
      network.offline = true;
      final cart = CartCubit()
        ..addItem(const Plan(
          id: 'home_100',
          name: 'Home 100',
          priceCents: 54900,
          dataDescription: '100GB',
          speedMbps: 100,
          category: ProductCategory.home5g,
        ));
      addTearDown(cart.close);
      final created = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider(
          create: (_) => CheckoutCubit(
            MockCheckoutRepository(InMemorySecureStore(), network: network, latency: Duration.zero),
            cart,
          ),
          child: CheckoutPage(onOrderCreated: (o) => created.add(o.id)),
        ),
      ));
      await tester.tap(find.text('Verify identity to continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(created, isEmpty);

      network.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(created, hasLength(1));
    });
  });
}
