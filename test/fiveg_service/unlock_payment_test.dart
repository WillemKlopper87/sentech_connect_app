import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:mocktail/mocktail.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/fiveg_service/data/http_fiveg_repository.dart';

import '../helpers/api_harness.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_themed.dart';

const _service = 'a6b4c2d0-1111-4a22-8b33-00000000c001';
const _orderId = '0c3b9a1e-8f2d-4e6a-9b7c-5d4e3f2a1b0c';
const _orderPath = '/v1/orders/$_orderId';

/// The same unlock order, paid by the gateway's server-to-server notification.
Map<String, Object?> _paidOrder() => {...fixtureMap('fiveg_unlock_order.json'), 'status': 'fulfilled', 'paid_at': '2026-11-10T09:05:00Z'};

void main() {
  group('an unlock is paid through the shared payment screen', () {
    late ApiHarness h;
    late HttpCheckoutRepository checkout;
    late CartCubit cart;

    setUp(() async {
      h = ApiHarness();
      await h.signIn();
      checkout = HttpCheckoutRepository(h.api);
      cart = CartCubit();
    });

    tearDown(() => cart.close());

    test('the unlock order is created by the 5G route and then paid with the checkout hand-off', () async {
      h.adapter.on('POST', '/v1/me/subscriber/services/$_service/data/unlock-orders',
          (_) => FakeReply(201, fixture('fiveg_unlock_order.json')));
      h.adapter.on('GET', _orderPath, (_) {
        final polls = h.adapter.requestsTo('GET', _orderPath).length;
        return FakeReply(200, polls == 1 ? fixture('fiveg_unlock_order.json') : _paidOrder());
      });
      h.adapter.on('POST', '$_orderPath/checkout', (_) => FakeReply(200, fixture('checkout_netcash.json')));

      final created = await HttpFiveGRepository(h.api).createUnlockOrder(
        _service,
        productCode: 'data_unlock_50gb',
        idempotencyKey: 'app-unlock-key-1',
      );
      expect(created.getOrElse((_) => throw StateError('no order')).id, _orderId);

      final cubit = PaymentCubit(
        checkout,
        cart,
        _orderId,
        pollDelays: const [Duration.zero, Duration.zero],
        wait: (_) async {},
      );
      // The order is read over the fake HTTP adapter, which needs real event turns.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.status, PaymentStatus.ready);
      expect(cubit.state.order?.kind, OrderKind.dataUnlock);
      expect(cubit.state.order?.isHotspotPass, isFalse);

      await cubit.pay();
      expect(cubit.state.status, PaymentStatus.handoff);
      expect(cubit.state.handoff?.amountCents, 3000);

      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(cubit.state.order?.kind, OrderKind.dataUnlock);
      expect(h.adapter.requestsTo('POST', '$_orderPath/checkout'), hasLength(1));
      await cubit.close();
    });

    test('a usage read after payment shows the unlock applied while the service restores', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services/$_service/data', (_) {
        return FakeReply(200, {...fixtureMap('fiveg_usage_normal.json'), 'restoring': true, 'pending_unlock': null});
      });
      final usage = await HttpFiveGRepository(h.api).getUsage(_service);
      expect(usage.getOrElse((_) => throw StateError('no usage')).restoring, isTrue);
      expect(usage.getOrElse((_) => throw StateError('no usage')).pendingUnlock, isNull);
    });
  });

  group('the confirmation after a paid data unlock', () {
    late _MockCheckout checkout;

    setUp(() {
      checkout = _MockCheckout();
      when(() => checkout.getOrder(_orderId)).thenAnswer(
        (_) async => Right(
          orderFromJson({...fixtureMap('fiveg_unlock_order.json'), 'status': 'fulfilled'}),
        ),
      );
    });

    Future<void> pump(WidgetTester tester, {VoidCallback? onBackToFiveG, VoidCallback? onDone}) async {
      await pumpThemed(
        tester,
        BlocProvider(
          create: (_) => OrderCubit(checkout, _orderId),
          child: ConfirmationPage(
            onDone: onDone ?? () {},
            onResume: (_) {},
            onBackToFiveG: onBackToFiveG,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('says the unlock is paid, not that a pass is ready, and returns to the 5G screen', (tester) async {
      var back = 0;
      await pump(tester, onBackToFiveG: () => back++);
      expect(find.text('Data unlock paid'), findsOneWidget);
      expect(find.text('Your pass is ready'), findsNothing);
      expect(find.textContaining('Wi-Fi'), findsNothing);
      await tester.tap(find.text('Back to 5G data'));
      expect(back, 1);
    });

    testWidgets('without a service it goes home', (tester) async {
      var home = 0;
      await pump(tester, onDone: () => home++);
      expect(find.text('Back to 5G data'), findsNothing);
      await tester.tap(find.text('Back to Home'));
      expect(home, 1);
    });
  });
}

class _MockCheckout extends Mock implements CheckoutRepository {}
