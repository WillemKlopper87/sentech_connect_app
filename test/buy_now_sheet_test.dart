import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/data_saver.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/buy_now_sheet.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/test_setup.dart';

const dayPass = Plan(
  id: 'day',
  name: 'Day Pass',
  priceCents: 3500,
  dataDescription: '5 GB data · valid 24 hours',
  speedMbps: 10,
  category: ProductCategory.hotspotPass,
);
const router = Plan(
  id: 'home',
  name: 'Home 100',
  priceCents: 54900,
  dataDescription: '100GB',
  speedMbps: 100,
  category: ProductCategory.home5g,
);
const longPass = Plan(
  id: 'long',
  name: 'Day Pass with a much longer product name for small screens',
  priceCents: 3500,
  dataDescription:
      '5 GB data · valid 24 hours at supported WiFi hotspots across this area',
  speedMbps: 10,
  category: ProductCategory.hotspotPass,
);

class RecordingCheckoutRepository extends MockCheckoutRepository {
  RecordingCheckoutRepository(SimulatedNetwork network)
    : super(
        InMemorySecureStore(),
        network: network,
        latency: const Duration(milliseconds: 100),
      );

  final keys = <String?>[];

  @override
  Future<Either<Failure, Order>> createOrder({
    required List<CartItem> items,
    String? idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    return super.createOrder(items: items, idempotencyKey: idempotencyKey);
  }
}

class ControlledCheckoutRepository extends MockCheckoutRepository {
  ControlledCheckoutRepository()
    : super(InMemorySecureStore(), latency: Duration.zero);

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Either<Failure, Order>> createOrder({
    required List<CartItem> items,
    String? idempotencyKey,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.createOrder(items: items, idempotencyKey: idempotencyKey);
  }
}

void main() {
  setUpAppTests();

  Future<void> pumpHost(
    WidgetTester tester,
    CartCubit cart,
    void Function(Order) onCreated, {
    double scale = 1,
    Plan plan = dayPass,
    bool showDemoMethods = false,
    bool reduceMotion = false,
    bool dataSaver = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cart),
            BlocProvider(
              create: (_) =>
                  DataSaverCubit(initial: dataSaver, save: (_) async {}),
            ),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showBuyNowSheet(
                  context,
                  plan,
                  onOrderCreated: onCreated,
                  showDemoMethods: showDemoMethods,
                  showCashVoucher: showDemoMethods,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'review shows real details, VAT and Pay, and cancellation keeps cart',
    (tester) async {
      final cart = CartCubit()..addItem(router);
      addTearDown(cart.close);
      await pumpHost(tester, cart, (_) {});
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('5 GB data · valid 24 hours'), findsOneWidget);
      expect(find.text('R35 incl. VAT'), findsOneWidget);
      expect(find.text('Pay R35 incl. VAT'), findsOneWidget);
      expect(cart.state.items.single.plan, router);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(cart.state.items.single.plan, router);
    },
  );

  testWidgets(
    'Pay creates one pass order after explicit tap and preserves cart',
    (tester) async {
      locator.registerSingleton<CheckoutRepository>(
        MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero),
      );
      final cart = CartCubit()..addItem(router);
      addTearDown(cart.close);
      final created = <Order>[];
      await pumpHost(tester, cart, created.add);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(created, isEmpty);
      await tester.tap(find.text('Pay R35 incl. VAT'));
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(created.single.status, OrderStatus.awaitingPayment);
      expect(created.single.totalCents, 3500);
      expect(cart.state.items.single.plan, router);
    },
  );

  testWidgets('review fits 360x690 at 2x text scale', (tester) async {
    tester.view.physicalSize =
        const Size(360, 690) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final cart = CartCubit();
    addTearDown(cart.close);
    await pumpHost(
      tester,
      cart,
      (_) {},
      scale: 2,
      plan: longPass,
      showDemoMethods: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Pay R35 incl. VAT'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'error stays in sheet; retry uses the same key and double tap creates once',
    (tester) async {
      final network = SimulatedNetwork()..offline = true;
      final repo = RecordingCheckoutRepository(network);
      locator.registerSingleton<CheckoutRepository>(repo);
      final cart = CartCubit()..addItem(router);
      addTearDown(cart.close);
      final created = <Order>[];
      await pumpHost(tester, cart, created.add);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay R35 incl. VAT'));
      await tester.tap(find.text('Pay R35 incl. VAT'));
      await tester.pumpAndSettle();
      expect(repo.keys, hasLength(1));
      expect(created, isEmpty);
      expect(find.text('Try again'), findsOneWidget);
      network.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.keys, hasLength(2));
      expect(repo.keys.first, repo.keys.last);
      expect(created, hasLength(1));
      expect(cart.state.items.single.plan, router);
    },
  );

  testWidgets('demo methods show cash only for a visible voucher offering', (
    tester,
  ) async {
    final cart = CartCubit();
    addTearDown(cart.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cart,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showBuyNowSheet(
                  context,
                  dayPass,
                  onOrderCreated: (_) {},
                  showDemoMethods: true,
                  showCashVoucher: false,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Instant EFT'), findsOneWidget);
    expect(find.text('Cash voucher'), findsNothing);
  });

  testWidgets(
    'voucher card opens Buy now; physical product stays in cart flow',
    (tester) async {
      final catalog = CatalogCubit(MockCatalogRepository());
      final cart = CartCubit()..addItem(router);
      addTearDown(catalog.close);
      addTearDown(cart.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: catalog),
              BlocProvider.value(value: cart),
            ],
            child: CatalogPage(onOpenCart: () {}, onOrderCreated: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vouchers'));
      await tester.pumpAndSettle();
      expect(find.text('Add to cart'), findsNothing);
      await tester.tap(find.text('5GB Wi-Fi Voucher'));
      await tester.pumpAndSettle();
      expect(find.text('Pay R59 incl. VAT'), findsOneWidget);
      expect(find.text('Cash voucher'), findsOneWidget);
      expect(cart.state.items.single.plan, router);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home 5G'));
      await tester.pumpAndSettle();
      expect(find.text('Add to cart'), findsWidgets);
    },
  );

  for (final dismissWithBack in [false, true]) {
    testWidgets(
      'late order after pending ${dismissWithBack ? 'back' : 'barrier'} dismissal cannot navigate or pop host',
      (tester) async {
        final repo = ControlledCheckoutRepository();
        locator.registerSingleton<CheckoutRepository>(repo);
        final cart = CartCubit()..addItem(router);
        addTearDown(cart.close);
        final created = <Order>[];
        await pumpHost(tester, cart, created.add);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pay R35 incl. VAT'));
        await tester.pump();
        await repo.started.future;
        if (dismissWithBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester
            .pump(); // reverse transition has started, subtree still alive
        repo.release.complete();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(created, isEmpty);
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Pay R35 incl. VAT'), findsNothing);
        expect(cart.state.items.single.plan, router);
      },
    );
  }

  for (final dataSaver in [false, true]) {
    testWidgets(
      'pending create is static with ${dataSaver ? 'Data saver' : 'reduced motion'}',
      (tester) async {
        final repo = ControlledCheckoutRepository();
        locator.registerSingleton<CheckoutRepository>(repo);
        final cart = CartCubit();
        addTearDown(cart.close);
        await pumpHost(
          tester,
          cart,
          (_) {},
          dataSaver: dataSaver,
          reduceMotion: !dataSaver,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pay R35 incl. VAT'));
        await tester.pump();
        await repo.started.future;
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Creating order'), findsOneWidget);
        repo.release.complete();
        await tester.pumpAndSettle();
      },
    );
  }
}
