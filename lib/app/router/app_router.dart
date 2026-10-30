import 'package:sentech_connect_app/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/mock_feature_guard.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/dev_payment_simulator.dart';
import 'package:sentech_connect_app/app/main_shell.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/registration_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/splash_page.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/pages/cart_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/identity_rule.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/checkout_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/payment_page.dart';
import 'package:sentech_connect_app/features/coverage/presentation/bloc/coverage_cubit.dart';
import 'package:sentech_connect_app/features/coverage/presentation/pages/coverage_page.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/domain/usage_alert_scheduler.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/legal_gate_page.dart';
import 'package:sentech_connect_app/features/promotions/presentation/bloc/promotions_cubit.dart';
import 'package:sentech_connect_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';
import 'package:sentech_connect_app/features/rica/presentation/pages/rica_page.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/services_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/service_detail_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/services_page.dart';
import 'package:sentech_connect_app/features/subscriber/subscriber_gate.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/tenant_picker_page.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/update_required_page.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/wifi_hotspots_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/wifi_hotspots_page.dart';

/// Router/usage data is mock-backed, so it only shows in the demo flavor (and
/// only with the tenant's `cpe` flag): a server flag must never show
/// fabricated account data to real customers.
bool showRouterCardFor({required bool isDemo, required bool cpe}) =>
    isDemo && cpe;

abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const consent = '/consent';
  static const coverage = '/coverage';
  static const main = '/main';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const passes = '/passes';
  static const promotions = '/promotions';
  static const wifiHotspots = '/wifi-hotspots';
  static const tenantPicker = '/tenant';
  static const updateRequired = '/update-required';

  // Subscriber account (module `subscriber_billing`); screens arrive in later
  // slices. Ids are always loaded from the repository, never passed via `extra`.
  static const plans = '/plans';
  static const planDetail = '/plans/:planId';
  static const signup = '/signup/:planId';
  static const services = '/services';
  static const serviceDetail = '/services/:serviceId';
  static const invoices = '/invoices';
  static const invoiceDetail = '/invoices/:invoiceId';
  static const kyc = '/kyc';

  static String planFor(String planId) => '/plans/$planId';
  static String signupFor(String planId) => '/signup/$planId';
  static String serviceFor(String serviceId) => '/services/$serviceId';
  static String invoiceFor(String invoiceId) => '/invoices/$invoiceId';

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
    OrderStatus.awaitingPayment ||
    OrderStatus.paymentFailed => paymentFor(order.id),
    OrderStatus.paid ||
    OrderStatus.expired ||
    OrderStatus.cancelled => confirmationFor(order.id),
  };

  /// Query parameter on `/login` holding the route the user originally asked for.
  static const fromParam = 'from';

  static const _public = {splash, login, tenantPicker, updateRequired};

  /// Everything except splash/login needs a signed-in user.
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
/// - Signed in without a name yet (new customer) -> `/register` (complete the profile);
///   terms/privacy not accepted yet -> `/consent`. The route asked for travels as `from`.
/// - Signed in + `/login`/`/register` -> the intended route (`from`), else
///   coverage right after a fresh sign-in (first-time onboarding), else `/main`.
String? authRedirect(
  AuthState auth,
  Uri uri, {
  bool coverageOnboarding = true,
}) {
  final location = uri.path;
  if (!auth.isSignedIn) {
    if (!AppRoutes.isProtected(location)) return null;
    final target = uri.toString();
    if (location == AppRoutes.main) return AppRoutes.login;
    return Uri(
      path: AppRoutes.login,
      queryParameters: {AppRoutes.fromParam: target},
    ).toString();
  }
  // Steps every signed-in session passes first, whatever began it (SMS code,
  // biometric unlock, restore at launch): new customers (no name yet)
  // complete their profile, and the CURRENT terms and privacy notice must be
  // accepted. (Splash and the tenant screens keep their own flow; they lead on
  // to a protected route, which lands here.)
  final gate = auth.user!.fullName.trim().isEmpty
      ? AppRoutes.register
      : (auth.legal == LegalStatus.accepted ? null : AppRoutes.consent);
  if (gate != null) {
    const ownFlow = {
      AppRoutes.splash,
      AppRoutes.tenantPicker,
      AppRoutes.updateRequired,
    };
    if (location == gate || ownFlow.contains(location)) return null;
    return _towards(gate, uri);
  }
  if (location == AppRoutes.login ||
      location == AppRoutes.register ||
      location == AppRoutes.consent) {
    final from = safeFrom(uri.queryParameters[AppRoutes.fromParam]);
    if (from != null) return from;
    return auth.freshSignIn && coverageOnboarding
        ? AppRoutes.coverage
        : AppRoutes.main;
  }
  return null;
}

/// [gate] with the route the customer was after kept as `from`, so the
/// deep link survives the profile / consent step.
String _towards(String gate, Uri uri) {
  final candidate =
      uri.queryParameters[AppRoutes.fromParam] ??
      (uri.path == AppRoutes.main ? null : uri.toString());
  final from = safeFrom(candidate);
  return from == null
      ? gate
      : Uri(
          path: gate,
          queryParameters: {AppRoutes.fromParam: from},
        ).toString();
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
      return location == AppRoutes.updateRequired
          ? null
          : AppRoutes.updateRequired;
    case TenantStatus.ready:
      return location == AppRoutes.tenantPicker ||
              location == AppRoutes.updateRequired
          ? AppRoutes.main
          : null;
  }
}

/// Accepts only in-app absolute paths to protected routes, so a crafted
/// `from` value can never redirect somewhere unexpected.
String? safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null ||
      !AppRoutes.isProtected(path) ||
      path == AppRoutes.register ||
      path == AppRoutes.consent) {
    return null;
  }
  return from;
}

/// Owns the app [GoRouter] and the subscriptions that re-run its guards
/// when the auth or tenant state changes. Pass the app-root cubits; the
/// router does not own them.
class AppRouter {
  AppRouter(
    AuthCubit authCubit, {
    TenantCubit? tenantCubit,
    String initialLocation = AppRoutes.splash,
    bool quickSplash = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : _refresh = _GuardRefresh(authCubit, tenantCubit) {
    router = _buildRouter(
      authCubit,
      tenantCubit,
      _refresh,
      initialLocation,
      quickSplash,
      navigatorKey,
    );
  }

  final _GuardRefresh _refresh;
  late final GoRouter router;

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

/// True once the provider's config is loaded and `subscriber_billing` is off:
/// the subscriber routes then bounce home. (Before the config loads they stay,
/// so a deep link at launch is not lost.)
bool _subscriberModuleOff(TenantCubit? tenant) =>
    tenant != null && tenant.state.status == TenantStatus.ready && !subscriberBillingOn(tenant.state);

GoRouter _buildRouter(
  AuthCubit authCubit,
  TenantCubit? tenantCubit,
  Listenable refresh,
  String initialLocation,
  bool quickSplash,
  GlobalKey<NavigatorState>? navigatorKey,
) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) =>
        (tenantCubit == null
            ? null
            : tenantRedirect(tenantCubit.state, state.uri)) ??
        authRedirect(
          authCubit.state,
          state.uri,
          coverageOnboarding:
              tenantCubit == null ||
              tenantCubit.state.featureFlags.cpe ||
              !tenantCubit.state.featureFlags.hotspotPasses,
        ),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.routerPageNotFound)),
      body: Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.main),
          child: Text(context.l10n.routerBackToHome),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashPage(
          instant: quickSplash,
          onFinished: () async {
            final tenant = tenantCubit;
            if (tenant != null && !tenant.state.isSettled) {
              // `orElse`: a closed cubit ends the stream, which must not throw here.
              await tenant.stream.firstWhere(
                (s) => s.isSettled,
                orElse: () => tenant.state,
              );
            }
            if (!context.mounted) return;
            // A restored session skips login and the first-time coverage step.
            context.go(
              authCubit.state.isSignedIn ? AppRoutes.main : AppRoutes.login,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.tenantPicker,
        builder: (context, state) => const TenantPickerPage(),
      ),
      GoRoute(
        path: AppRoutes.updateRequired,
        builder: (context, state) => const UpdateRequiredPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            LoginPage(demoMode: locator<AppEnvironment>().isDemo),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(
        path: AppRoutes.consent,
        builder: (context, state) => const LegalGatePage(),
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
          onOpenPasses: () => context.push(AppRoutes.passes),
          // Router/usage data is mock-backed: a server-side `cpe` flag must
          // never show it to real prod customers.
          showRouterCard: showRouterCardFor(
            isDemo: locator<AppEnvironment>().isDemo,
            cpe: tenantCubit?.state.featureFlags.cpe ?? false,
          ),
          showMockFeatures: locator<AppEnvironment>().isDemo,
          showPromotions: promotionsVisible(locator<AppEnvironment>()),
          showFreeWifi: freeWifiVisible(
            locator<AppEnvironment>(),
            creditsModuleOn:
                tenantCubit?.state.isModuleOn(AppModuleKeys.credits) ?? false,
          ),
          onChangeProvider: tenantCubit?.openPicker,
          providerName: tenantCubit?.state.config?.tenant.name,
          supportWhatsAppNumber:
              tenantCubit?.state.config?.tenant.branding.whatsAppNumber,
        ),
      ),
      GoRoute(
        path: AppRoutes.passes,
        builder: (context, state) => BlocProvider(
          create: (_) => PassesCubit(
            locator(),
            alerts: locator.isRegistered<UsageAlertCoordinator>()
                ? locator()
                : null,
          ),
          child: MyPassesPage(
            onBuyPass: () => context.go(AppRoutes.main),
            now: locator<PlatformClock>().wallNow,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.promotions,
        redirect: (context, state) =>
            promotionsVisible(locator<AppEnvironment>()) ? null : AppRoutes.main,
        builder: (context, state) => BlocProvider(
          create: (_) => PromotionsCubit(
            locator(),
            catalog: locator(),
            now: locator<PlatformClock>().wallNow,
          ),
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
      // Subscriber services (S3). Hidden when the module is off.
      GoRoute(
        path: AppRoutes.services,
        redirect: (context, state) => _subscriberModuleOff(tenantCubit) ? AppRoutes.main : null,
        builder: (context, state) => BlocProvider(
          create: (_) => ServicesCubit(locator()),
          child: const ServicesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.serviceDetail,
        redirect: (context, state) => _subscriberModuleOff(tenantCubit) ? AppRoutes.main : null,
        builder: (context, state) => BlocProvider(
          create: (_) => ServiceDetailCubit(locator(), state.pathParameters['serviceId']!),
          child: const ServiceDetailPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => CartPage(
          onCheckout: () => context.push(AppRoutes.checkout),
          buyInApp: tenantCubit?.state.config?.buyInApp ?? true,
        ),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) {
          return BlocProvider(
            create: (_) => CheckoutCubit(locator(), context.read<CartCubit>()),
            child: CheckoutPage(
              // RICA follows the products in the cart, not the tenant flag
              // alone: a WiFi pass never goes to the face check.
              requiresIdentityCheck: requiresIdentityCheck(
                ricaFlag: tenantCubit?.state.featureFlags.rica ?? true,
                items: context.read<CartCubit>().state.items,
              ),
              onOrderCreated: (order) =>
                  context.push(AppRoutes.forOrder(order)),
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
            create: (_) =>
                PaymentCubit(locator(), context.read<CartCubit>(), orderId),
            child: PaymentPage(
              showDemoMethods: locator<AppEnvironment>().isDemo,
              // Hotspot orders hide it regardless (PaymentPage derives that
              // from the order).
              showIdentityVerified:
                  tenantCubit?.state.featureFlags.rica ?? true,
              devSimulator:
                  kDebugMode && locator.isRegistered<DevPaymentSimulator>()
                  ? locator<DevPaymentSimulator>()
                  : null,
              onPaid: (order) =>
                  context.go(AppRoutes.confirmationFor(order.id)),
              onNeedsVerification: (order) =>
                  context.push(AppRoutes.ricaFor(order.id)),
              onClosed: () => context.go(AppRoutes.main),
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
              // App config has no verified SSID. Tenant name is only a brand.
              onFindWifi: () => context.push(AppRoutes.wifiHotspots),
              onDone: () => context.go(AppRoutes.main),
              onResume: (order) => context.go(AppRoutes.forOrder(order)),
              onViewPasses: () => context.push(AppRoutes.passes),
            ),
          );
        },
      ),
    ],
  );
}
