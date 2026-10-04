import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/pages/cart_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/checkout_page.dart';
import 'helpers/test_setup.dart';
import 'helpers/pump_themed.dart';

const _plans = [
  Plan(
    id: 'home_unlimited',
    name: 'Home Unlimited',
    priceCents: 79900,
    dataDescription: 'Uncapped data',
    speedMbps: 100,
    category: ProductCategory.home5g,
  ),
  Plan(
    id: 'voucher_20gb',
    name: '20GB Wi-Fi Voucher',
    priceCents: 19900,
    dataDescription: 'Valid for 30 days',
    speedMbps: 50,
    category: ProductCategory.voucher,
  ),
  Plan(
    id: 'mifi_50',
    name: 'MiFi 50',
    priceCents: 34900,
    dataDescription: '50GB anytime data',
    speedMbps: 50,
    category: ProductCategory.mifi,
  ),
];

void main() {
  setUpAppTests();

  /// A phone-sized window at the given text scale. Text scaling is applied
  /// through MediaQuery, as the OS font-size setting does.
  Future<void> pumpScaled(
    WidgetTester tester,
    Widget home, {
    double scale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 3; // 360 x 720 dp
    addTearDown(tester.view.reset);
    await pumpThemed(
      tester,
      home,
      textScale: scale,
      size: const Size(360, 720),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  AuthCubit newAuth() => AuthCubit(
    locator(),
    sessionStore: locator(),
    biometrics: MockBiometricAuthenticator(),
    wiper: locator(),
  );

  Widget loginPage(AuthCubit auth) =>
      BlocProvider.value(value: auth, child: const LoginPage());

  Widget checkoutPage(CartCubit cart) => BlocProvider(
    create: (_) => CheckoutCubit(
      MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero),
      cart,
    ),
    child: CheckoutPage(onOrderCreated: (_) {}),
  );

  CartCubit fullCart() {
    final cart = CartCubit();
    for (final p in _plans) {
      cart.addItem(p);
    }
    return cart;
  }

  group('text scale 2.0', () {
    testWidgets('login: no overflow, and every control is still reachable', (
      tester,
    ) async {
      final auth = newAuth();
      addTearDown(auth.close);
      await pumpScaled(tester, loginPage(auth), scale: 2.0);

      expect(tester.takeException(), isNull);
      for (final label in ['Send code']) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      // The form still works at large text.
      await tester.enterText(
        find.widgetWithText(TextField, 'Mobile number'),
        '0810000000',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'checkout: no overflow, totals and the primary button stay visible',
      (tester) async {
        final cart = fullCart();
        addTearDown(cart.close);
        await pumpScaled(tester, checkoutPage(cart), scale: 2.0);

        expect(tester.takeException(), isNull);
        expect(find.text('Home Unlimited'), findsOneWidget);
        expect(find.text('To pay'), findsOneWidget);
        await tester.ensureVisible(find.text('Verify identity to continue'));
        expect(find.text('Verify identity to continue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cart: no overflow at 2.0', (tester) async {
      final cart = fullCart();
      addTearDown(cart.close);
      await pumpScaled(
        tester,
        BlocProvider.value(
          value: cart,
          child: CartPage(onCheckout: () {}),
        ),
        scale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('touch targets and labels', () {
    testWidgets('login meets the Android 48dp tap-target guideline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final auth = newAuth();
      addTearDown(auth.close);
      await pumpScaled(tester, loginPage(auth));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('checkout meets the tap-target guideline', (tester) async {
      final handle = tester.ensureSemantics();
      final cart = fullCart();
      addTearDown(cart.close);
      await pumpScaled(tester, checkoutPage(cart));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('cart: quantity steppers are 48dp and labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final cart = fullCart();
      addTearDown(cart.close);
      await pumpScaled(
        tester,
        BlocProvider.value(
          value: cart,
          child: CartPage(onCheckout: () {}),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(find.byTooltip('Increase quantity'), findsNWidgets(3));
      expect(find.byTooltip('Decrease quantity'), findsNWidgets(3));
      handle.dispose();
    });

    testWidgets(
      'catalog: the icon-only cart button is labelled and category chips are 48dp',
      (tester) async {
        final handle = tester.ensureSemantics();
        final cubit = CatalogCubit(MockCatalogRepository(SimulatedNetwork()));
        final cart = CartCubit();
        addTearDown(() {
          cubit.close();
          cart.close();
        });
        await pumpScaled(
          tester,
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: cart),
            ],
            child: CatalogPage(
              onOpenCart: () {},
              onFindHotspots: () {},
              onOrderCreated: (_) {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byTooltip('Shopping cart'), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      },
    );
  });
}
