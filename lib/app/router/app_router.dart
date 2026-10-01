import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/checkout_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/payment_page.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';
import 'package:sentech_connect_app/features/promotions/presentation/bloc/promotions_cubit.dart';
import 'package:sentech_connect_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';
import 'package:sentech_connect_app/features/rica/presentation/pages/rica_page.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/tenant_picker_page.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/update_required_page.dart';
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
  static const promotions = '/promotions';
  static const wifiHotspots = '/wifi-hotspots';
  static const tenantPicker = '/tenant';
  static const updateRequired = '/update-required';

  // Order-scoped routes carry the order id as a path parameter; the order
  // itself is always loaded from the repository (never via `extra`), so the
  // screens survive process death and deep links.
  static const rica = '/rica/:orderId';
  static const payment = '/payment/:orderId';
  static const confirmation = '/confirmation/:orderId';

  static String ricaFor(String orderId) => '/rica/$orderId';
  static String paymentFor(String orderId) => '/payment/$orderId';
  static String confirmationFor(String orderId) => '/confirmation/$orderId';

  /// Where an order should be picked up, given how far it got.
  static String forOrder(Order order) => switch (order.status) {
        OrderStatus.pendingVerification => ricaFor(order.id),
        OrderStatus.awaitingPayment => paymentFor(order.id),
        OrderStatus.paid => confirmationFor(order.id),
      };

  /// Query parameter on `/login` holding the route the user originally asked for.
  static const fromParam = 'from';

  static const _public = {splash, login, register, tenantPicker, updateRequired};

  /// Everything except splash/login/register needs a signed-in user.
  static bool isProtected(String location) => !_public.contains(location);
}

/// Re-runs the router's redirect whenever the auth or tenant state changes.
class _GuardRefresh extends ChangeNotifier {
  _GuardRefresh(AuthCubit auth, TenantCubit? tenant) {
    _subscriptions = [
      auth.stream.listen((_) => notifyListeners()),
      if (tenant != null) tenant.stream.listen((_) => notifyListeners()),
    ];
  }

  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Pure redirect rule, separated out so it can be unit tested.
///
/// - Signed out + protected route  -> `/login?from=<intended route>`
/// - Signed in + `/login`/`/register` -> the intended route (`from`), else
///   coverage right after a fresh sign-in (first-time onboarding), else `/main`.
String? authRedirect(AuthState auth, Uri uri) {
  final location = uri.path;
  if (!auth.isSignedIn) {
    if (!AppRoutes.isProtected(location)) return null;
    final target = uri.toString();
    if (location == AppRoutes.main) return AppRoutes.login;
    return Uri(path: AppRoutes.login, queryParameters: {AppRoutes.fromParam: target}).toString();
  }
  if (location == AppRoutes.login || location == AppRoutes.register) {
    final from = safeFrom(uri.queryParameters[AppRoutes.fromParam]);
    if (from != null) return from;
    return auth.freshSignIn ? AppRoutes.coverage : AppRoutes.main;
  }
  return null;
}

/// Tenant rules run before the auth rules: no screen is usable until a
/// tenant is chosen, and none at all when this app version is too old.
String? tenantRedirect(TenantState tenant, Uri uri) {
  final location = uri.path;
  switch (tenant.status) {
    case TenantStatus.initial || TenantStatus.loading:
      return null;
    case TenantStatus.needsSelection || TenantStatus.failure:
      return location == AppRoutes.tenantPicker ? null : AppRoutes.tenantPicker;
    case TenantStatus.updateRequired:
      return location == AppRoutes.updateRequired ? null : AppRoutes.updateRequired;
    case TenantStatus.ready:
      return location == AppRoutes.tenantPicker || location == AppRoutes.updateRequired ? AppRoutes.main : null;
  }
}

/// Accepts only in-app absolute paths to protected routes, so a crafted
/// `from` value can never redirect somewhere unexpected.
String? safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
  final path = Uri.tryParse(from)?.path;
  if (path == null || !AppRoutes.isProtected(path)) return null;
  return from;
}

/// Owns the app [GoRouter] and the subscriptions that re-run its guards
/// when the auth or tenant state changes. Pass the app-root cubits; the
/// router does not own them.
class AppRouter {
  AppRouter(AuthCubit authCubit, {TenantCubit? tenantCubit, String initialLocation = AppRoutes.splash})
      : _refresh = _GuardRefresh(authCubit, tenantCubit) {
    router = _buildRouter(authCubit, tenantCubit, _refresh, initialLocation);
  }

  final _GuardRefresh _refresh;
  late final GoRouter router;

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

GoRouter _buildRouter(AuthCubit authCubit, TenantCubit? tenantCubit, Listenable refresh, String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) =>
        (tenantCubit == null ? null : tenantRedirect(tenantCubit.state, state.uri)) ?? authRedirect(authCubit.state, state.uri),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.main),
          child: const Text('Back to dashboard'),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashPage(
          onFinished: () async {
            final tenant = tenantCubit;
            if (tenant != null && !tenant.state.isSettled) {
              // `orElse`: a closed cubit ends the stream, which must not throw here.
              await tenant.stream.firstWhere((s) => s.isSettled, orElse: () => tenant.state);
            }
            if (!context.mounted) return;
            // A restored session skips login and the first-time coverage step.
            context.go(authCubit.state.isSignedIn ? AppRoutes.main : AppRoutes.login);
          },
        ),
      ),
      GoRoute(path: AppRoutes.tenantPicker, builder: (context, state) => const TenantPickerPage()),
      GoRoute(path: AppRoutes.updateRequired, builder: (context, state) => const UpdateRequiredPage()),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(
          onRegister: () => context.push(AppRoutes.register),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegistrationPage(),
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
          onResumeOrder: (order) => context.push(AppRoutes.forOrder(order)),
          onOpenPromotions: () => context.push(AppRoutes.promotions),
          onFindHotspots: () => context.push(AppRoutes.wifiHotspots),
          onChangeProvider: tenantCubit?.openPicker,
          providerName: tenantCubit?.state.config?.tenant.name,
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
              onOrderCreated: (order) => context.push(AppRoutes.ricaFor(order.id)),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.rica,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return BlocProvider(
            create: (_) => RicaCubit(locator(), locator(), orderId),
            child: RicaPage(
              onVerified: () => context.push(AppRoutes.paymentFor(orderId)),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return BlocProvider(
            create: (_) => PaymentCubit(locator(), context.read<CartCubit>(), orderId),
            child: PaymentPage(
              onPaid: (order) => context.go(AppRoutes.confirmationFor(order.id)),
              onNeedsVerification: (order) => context.push(AppRoutes.ricaFor(order.id)),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.confirmation,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return BlocProvider(
            create: (_) => OrderCubit(locator(), orderId),
            child: ConfirmationPage(
              onDone: () => context.go(AppRoutes.main),
              onResume: (order) => context.go(AppRoutes.forOrder(order)),
            ),
          );
        },
      ),
    ],
  );
}

