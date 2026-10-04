import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/pass_ready_view.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/first_run_tenant.dart';
import 'helpers/pump_themed.dart';
import 'helpers/test_setup.dart';

const _order = Order(
  id: 'paid-pass',
  orderNumber: 'SEN-48213',
  planName: 'Day Pass',
  totalCents: 3575,
  status: OrderStatus.paid,
  isHotspotPass: true,
);

Future<MockCheckoutRepository> _repository(Order order) async {
  final store = InMemorySecureStore();
  await store.write('orders', jsonEncode([order.toJson()]));
  return MockCheckoutRepository(store, latency: Duration.zero);
}

void main() {
  testWidgets('shows three named connect steps and invokes each action', (
    tester,
  ) async {
    var done = 0;
    var found = 0;
    var viewed = 0;
    await pumpThemed(
      tester,
      PassReadyView(
        title: 'Day Pass is ready',
        networkName: 'Verified WiFi',
        detail: 'R35.75 incl. VAT · Order #SEN-48213',
        onDone: () => done++,
        onFindWifi: () => found++,
        onViewPasses: () => viewed++,
      ),
    );
    expect(find.text('Connect to Verified WiFi'), findsOneWidget);
    expect(find.text('Choose Verified WiFi'), findsOneWidget);
    for (var step = 1; step <= 3; step++) {
      expect(find.byKey(Key('connect-step-$step')), findsOneWidget);
    }
    await tester.tap(find.text('Done'));
    await tester.tap(find.text('Find WiFi near me'));
    await tester.tap(find.text('View my passes'));
    expect([done, found, viewed], [1, 1, 1]);
  });

  for (final network in <String?>[null, '', '  ']) {
    testWidgets('missing network $network uses honest generic guidance', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        PassReadyView(
          title: 'Day Pass is ready',
          networkName: network,
          detail: 'Order #SEN-48213',
          onDone: () {},
        ),
      );
      expect(find.text('Connect to WiFi'), findsOneWidget);
      expect(find.text('Choose the hotspot WiFi network'), findsOneWidget);
      expect(find.text('Find WiFi near me'), findsNothing);
      expect(find.text('View my passes'), findsNothing);
      expect(find.textContaining('connected'), findsNothing);
      expect(find.textContaining('receipt'), findsNothing);
    });
  }

  for (final locale in ['en', 'zu']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'real theme $locale $brightness ${scale}x wraps and scrolls at 360x690',
          (tester) async {
            var done = 0;
            await pumpThemed(
              tester,
              PassReadyView(
                title: 'A longer Day Pass name is ready',
                networkName:
                    'Verified community WiFi network with a longer name',
                detail: 'R1234.75 incl. VAT · Order #SEN-48213123456789',
                onDone: () => done++,
                onFindWifi: () {},
                onViewPasses: () {},
                celebrate: false,
              ),
              locale: Locale(locale),
              brightness: brightness,
              textScale: scale,
              size: const Size(360, 690),
            );
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.text('Done'));
            await tester.tap(find.text('Done'));
            expect(done, 1);
            await tester.ensureVisible(find.text('View my passes'));
            expect(tester.takeException(), isNull);
            final context = tester.element(find.byType(PassReadyView));
            final theme = Theme.of(context);
            for (final text in tester.widgetList<Text>(
              find.descendant(
                of: find.byType(PassReadyView),
                matching: find.byType(Text),
              ),
            )) {
              final style = DefaultTextStyle.of(
                tester.element(find.byWidget(text)),
              ).style.merge(text.style);
              expect(style.fontSize, greaterThanOrEqualTo(13));
              final elevated = find.ancestor(
                of: find.byWidget(text),
                matching: find.byType(ElevatedButton),
              );
              final background = elevated.evaluate().isEmpty
                  ? theme.scaffoldBackgroundColor
                  : theme.elevatedButtonTheme.style!.backgroundColor!.resolve(
                      {},
                    )!;
              expect(
                ColorContrast.ratio(style.color!, background),
                greaterThanOrEqualTo(4.5),
              );
            }
            final body = tester.widget<Text>(find.text('Turn on WiFi'));
            expect(body.style!.fontSize, greaterThanOrEqualTo(15));
            final button = tester.widget<ElevatedButton>(
              find.byType(ElevatedButton),
            );
            final background =
                button.style?.backgroundColor?.resolve({}) ??
                theme.elevatedButtonTheme.style!.backgroundColor!.resolve({})!;
            final foreground =
                button.style?.foregroundColor?.resolve({}) ??
                theme.elevatedButtonTheme.style!.foregroundColor!.resolve({})!;
            expect(
              ColorContrast.ratio(foreground, background),
              greaterThanOrEqualTo(4.5),
            );
          },
        );
      }
    }
  }

  group('confirmation states', () {
    for (final status in OrderStatus.values) {
      testWidgets('$status only shows ready for paid hotspot', (tester) async {
        final cubit = OrderCubit(
          await _repository(_order.copyWith(status: status)),
          _order.id,
        );
        addTearDown(cubit.close);
        Order? resumed;
        var done = 0;
        await pumpThemed(
          tester,
          BlocProvider.value(
            value: cubit,
            child: ConfirmationPage(
              onDone: () => done++,
              onResume: (order) => resumed = order,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (status == OrderStatus.paid) {
          expect(find.byType(PassReadyView), findsOneWidget);
          expect(find.text('Day Pass is ready'), findsOneWidget);
          expect(
            find.text('R35.75 incl. VAT · Order #SEN-48213'),
            findsOneWidget,
          );
        } else {
          expect(find.byType(PassReadyView), findsNothing);
          if (status == OrderStatus.expired ||
              status == OrderStatus.cancelled) {
            await tester.tap(find.text('Back to Home'));
            expect(done, 1);
            expect(resumed, isNull);
          } else {
            await tester.tap(find.text('Continue your order'));
            expect(resumed?.status, status);
          }
        }
        expect(find.textContaining('Identity verified'), findsNothing);
      });
    }
  });

  group('actual confirmation route', () {
    setUpAppTests();
    for (final demo in [true, false]) {
      testWidgets('demo=$demo uses generic steps and gates hotspot finder', (
        tester,
      ) async {
        locator.registerSingleton<CheckoutRepository>(
          await _repository(_order),
        );
        locator.registerSingleton<AppEnvironment>(
          demo
              ? AppEnvironment.demo
              : const AppEnvironment(flavor: AppFlavor.prod),
        );
        final tenant = await firstRunTenant(cpe: false);
        final auth = AuthCubit(
          locator(),
          sessionStore: locator(),
          biometrics: MockBiometricAuthenticator(),
          wiper: locator(),
          initial: const AuthState(
            status: AuthStatus.success,
            user: User(id: 'usr', fullName: 'Lindiwe', mobileNumber: '081'),
          ),
        );
        final router = AppRouter(
          auth,
          tenantCubit: tenant,
          initialLocation: AppRoutes.confirmationFor(_order.id),
        );
        addTearDown(() async {
          router.dispose();
          await auth.close();
          await tenant.close();
        });
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: tenant),
              BlocProvider(create: (_) => CartCubit()),
              BlocProvider(create: (_) => ThemeCubit()),
              BlocProvider(create: (_) => LocaleCubit()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router.router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Connect to WiFi'), findsOneWidget);
        expect(find.text('Connect to Sentech'), findsNothing);
        expect(
          find.text('R35.75 incl. VAT · Order #SEN-48213'),
          findsOneWidget,
        );
        expect(
          find.text('Find WiFi near me'),
          demo ? findsOneWidget : findsNothing,
        );
        if (demo) {
          await tester.tap(find.text('Find WiFi near me'));
          await tester.pump(const Duration(seconds: 1));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          expect(router.router.state.uri.path, AppRoutes.wifiHotspots);
          router.router.pop();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('View my passes'));
        await tester.pumpAndSettle();
        expect(router.router.state.uri.path, AppRoutes.passes);
        router.router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect(router.router.state.uri.path, AppRoutes.main);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
