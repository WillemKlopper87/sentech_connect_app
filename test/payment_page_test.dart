import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/payment_page.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';

import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/test_setup.dart';

const _pass = Plan(
  id: 'pass',
  name: 'Day Pass',
  priceCents: 4900,
  dataDescription: '5 GB · 1 day',
  speedMbps: 0,
  category: ProductCategory.hotspotPass,
);

const _items = [CartItem(plan: _pass, quantity: 1)];

const _voucher = Plan(
  id: 'voucher_5gb',
  name: '5GB Wi-Fi Voucher',
  priceCents: 5900,
  dataDescription: 'Valid for 30 days',
  speedMbps: 50,
  category: ProductCategory.voucher,
);

const _home5g = Plan(
  id: 'home_100',
  name: 'Home 100',
  priceCents: 54900,
  dataDescription: '100GB',
  speedMbps: 100,
  category: ProductCategory.home5g,
);

Future<void> _pumpPage(
  WidgetTester tester,
  PaymentCubit cubit, {
  void Function(Order)? onPaid,
  bool showIdentityVerified = true,
  double textScale = 1,
  bool realTheme = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: realTheme ? AppTheme.light() : null,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BlocProvider.value(
        value: cubit,
        child: PaymentPage(
          showIdentityVerified: showIdentityVerified,
          onPaid: onPaid ?? (_) {},
          onNeedsVerification: (_) {},
          onClosed: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAppTests();

  testWidgets('secure payment explanation renders at body floor at 2x', (
    tester,
  ) async {
    final repo = MockCheckoutRepository(
      InMemorySecureStore(),
      latency: Duration.zero,
    );
    final cart = CartCubit()..addItem(_pass);
    addTearDown(cart.close);
    final order = (await tester.runAsync(
      () => repo.createOrder(items: _items),
    ))!.getOrElse((f) => throw StateError(f.message));
    final cubit = PaymentCubit(repo, cart, order.id);
    addTearDown(cubit.close);
    tester.view.physicalSize =
        const Size(360, 690) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpPage(tester, cubit, textScale: 2, realTheme: true);
    final label = find.text(
      'Pay on a secure payment page. We never see or store your card details.',
    );
    final paragraph = tester.widget<RichText>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    expect(paragraph.text.style!.fontSize, greaterThanOrEqualTo(15));
    final surface = Theme.of(tester.element(label)).colorScheme.surface;
    expect(
      ColorContrast.ratio(paragraph.text.style!.color!, surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(tester.getRect(label).bottom, lessThanOrEqualTo(690));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a replayed, superseded demo order loads on the payment page (closed, no error)',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit();
      addTearDown(cart.close);
      final a = (await tester.runAsync(
        () => repo.createOrder(items: _items, idempotencyKey: 'a'),
      ))!.getOrElse((f) => throw StateError(f.message));
      await tester.runAsync(
        () => repo.createOrder(items: _items, idempotencyKey: 'b'),
      );
      final replayed = (await tester.runAsync(
        () => repo.createOrder(items: _items, idempotencyKey: 'a'),
      ))!.getOrElse((f) => throw StateError(f.message));
      expect(replayed.id, a.id);

      final cubit = PaymentCubit(repo, cart, replayed.id);
      addTearDown(cubit.close);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _pumpPage(tester, cubit);
      expect(cubit.state.status, PaymentStatus.closed);
      expect(find.textContaining('can no longer be paid'), findsOneWidget);
      expect(find.textContaining('could not find'), findsNothing);
    },
  );

  testWidgets(
    'demo hotspot checkout: Pay hands off, polls the server order, and reports paid; never claims identity',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit()..addItem(_pass);
      addTearDown(cart.close);
      var order = (await tester.runAsync(
        () => repo.createOrder(items: _items),
      ))!.getOrElse((f) => throw StateError(f.message));
      order = (await tester.runAsync(
        () => repo.markIdentityVerified(order.id),
      ))!.getOrElse((f) => throw StateError(f.message));
      expect(order.isHotspotPass, isTrue);

      final cubit = PaymentCubit(repo, cart, order.id, wait: (_) async {});
      addTearDown(cubit.close);
      Order? paid;
      await _pumpPage(tester, cubit, onPaid: (o) => paid = o);
      expect(find.textContaining('Identity verified'), findsNothing);
      expect(find.text('WiFi pass order'), findsOneWidget);
      expect(find.text('Pay R49.00 incl. VAT securely'), findsOneWidget);
      expect(find.textContaining('incl. VAT incl. VAT'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.textContaining('Pay '),
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(paid?.id, order.id);
      expect(cart.state.items, isEmpty);
    },
  );

  testWidgets(
    'a WiFi voucher purchase (no RICA) shows nothing about identity',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit()..addItem(_voucher);
      addTearDown(cart.close);
      final order = (await tester.runAsync(
        () => repo.createOrder(
          items: const [CartItem(plan: _voucher, quantity: 1)],
        ),
      ))!.getOrElse((f) => throw StateError(f.message));
      expect(order.isHotspotPass, isFalse);
      expect(order.status, OrderStatus.awaitingPayment);

      final cubit = PaymentCubit(repo, cart, order.id);
      addTearDown(cubit.close);
      await _pumpPage(tester, cubit);
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.textContaining('Pay '),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Identity'), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
    },
  );

  testWidgets('a Home 5G order shows Identity verified once RICA is done', (
    tester,
  ) async {
    final repo = MockCheckoutRepository(
      InMemorySecureStore(),
      latency: Duration.zero,
    );
    final cart = CartCubit()..addItem(_home5g);
    addTearDown(cart.close);
    final order = (await tester.runAsync(
      () =>
          repo.createOrder(items: const [CartItem(plan: _home5g, quantity: 1)]),
    ))!.getOrElse((f) => throw StateError(f.message));
    final verified = (await tester.runAsync(
      () => repo.markIdentityVerified(order.id),
    ))!.getOrElse((f) => throw StateError(f.message));
    expect(verified.identityVerified, isTrue);

    final cubit = PaymentCubit(repo, cart, order.id);
    addTearDown(cubit.close);
    await _pumpPage(tester, cubit);
    expect(find.text('Identity verified'), findsOneWidget);
  });

  testWidgets(
    'a still-pending payment offers Check again and Pay again (no false success)',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit()..addItem(_pass);
      addTearDown(cart.close);
      final order = (await tester.runAsync(
        () => repo.createOrder(items: _items),
      ))!.getOrElse((f) => throw StateError(f.message));
      await tester.runAsync(() => repo.markIdentityVerified(order.id));
      // No poll ever sees the order paid: the schedule is empty.
      final cubit = PaymentCubit(repo, cart, order.id, pollDelays: const []);
      addTearDown(cubit.close);
      await _pumpPage(tester, cubit);
      await tester.tap(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.textContaining('Pay '),
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.status, PaymentStatus.stillPending);
      expect(find.text('Check again'), findsOneWidget);
      expect(find.text('Pay again'), findsOneWidget);
      expect(
        find.text('Only pay again if you did not complete the payment.'),
        findsOneWidget,
      );
      expect(cart.state.items, isNotEmpty);
    },
  );
}
