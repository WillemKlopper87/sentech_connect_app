import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/main_shell.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/registration_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/splash_page.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/pages/cart_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/checkout_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';
import 'package:sentech_connect_app/features/promotions/presentation/bloc/promotions_cubit.dart';
import 'package:sentech_connect_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';
import 'package:sentech_connect_app/features/rica/presentation/pages/rica_page.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/wifi_hotspots_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/wifi_hotspots_page.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const coverage = '/coverage';
  static const main = '/main';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const rica = '/rica';
  static const confirmation = '/confirmation';
  static const promotions = '/promotions';
  static const wifiHotspots = '/wifi-hotspots';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashPage(
          onFinished: () {
            // A restored session (see AppPreferences) skips straight past
            // login and the coverage-check onboarding step, which are
            // first-time-only — a returning customer lands on their
            // dashboard, not back at square one.
            final signedIn = context.read<AuthCubit>().state.status == AuthStatus.success;
            context.go(signedIn ? AppRoutes.main : AppRoutes.login);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(
          onLoggedIn: () => context.go(AppRoutes.coverage),
          onRegister: () => context.push(AppRoutes.register),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegistrationPage(
          onRegistered: () => context.go(AppRoutes.coverage),
        ),
      ),
      GoRoute(
        path: AppRoutes.coverage,
        builder: (context, state) => BlocProvider(
          create: (_) => CoverageCubit(locator()),
          child: CoveragePage(onCovered: () => context.go(AppRoutes.main)),
        ),
      ),
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) => MainShell(
          onOpenCart: () => context.push(AppRoutes.cart),
          onLoggedOut: () => context.go(AppRoutes.login),
          onOpenPromotions: () => context.push(AppRoutes.promotions),
          onFindHotspots: () => context.push(AppRoutes.wifiHotspots),
        ),
      ),
      GoRoute(
        path: AppRoutes.promotions,
        builder: (context, state) => BlocProvider(
          create: (_) => PromotionsCubit(locator()),
          child: const PromotionsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.wifiHotspots,
        builder: (context, state) => BlocProvider(
          create: (_) => WifiHotspotsCubit(locator()),
          child: const WifiHotspotsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => CartPage(
          onCheckout: () => context.push(AppRoutes.checkout),
        ),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) {
          return BlocProvider(
            create: (_) => CheckoutCubit(locator(), context.read<CartCubit>()),
            child: CheckoutPage(
              onPaid: (order) => context.push(AppRoutes.rica, extra: order),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.rica,
        builder: (context, state) {
          final order = state.extra as Order;
          return BlocProvider(
            create: (_) => RicaCubit(locator()),
            child: RicaPage(
              onVerified: () => context.go(AppRoutes.confirmation, extra: order),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.confirmation,
        builder: (context, state) {
          final order = state.extra as Order;
          return ConfirmationPage(
            order: order,
            onDone: () => context.go(AppRoutes.main),
          );
        },
      ),
    ],
  );
}
