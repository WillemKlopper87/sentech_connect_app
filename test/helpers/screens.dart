import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/pages/dashboard_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/pages/cart_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_scanner_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

final screenClock = DateTime.utc(2026, 10, 4, 10);

/// Small repositories implement the real contracts and return populated data.
/// Product copy is localized fixture data, not a new runtime translation.
class _Catalog implements CatalogRepository {
  _Catalog(this.l10n);
  final AppLocalizations l10n;
  List<Plan> get products => [
    for (final category in ProductCategory.values)
      Plan(
        id: category.name,
        name: l10n.productCategoryHotspotPass,
        priceCents: 3500,
        dataDescription: l10n.dashboardUncapped,
        speedMbps: 10,
        category: category,
        isFeatured: true,
      ),
  ];
  @override
  Future<Either<Failure, List<Plan>>> getProducts() async => Right(products);
}

class _Passes extends PassesRepository {
  _Passes(this.l10n);
  final AppLocalizations l10n;
  @override
  Future<Either<Failure, List<Pass>>> getPasses({
    bool includeExpired = false,
  }) async => Right([
    for (final status in [
      PassStatus.active,
      PassStatus.scheduled,
      if (includeExpired) PassStatus.expired,
    ])
      Pass(
        id: status.name,
        orderId: 'order-${status.name}',
        productName: l10n.productCategoryHotspotPass,
        status: status,
        startsAt: screenClock.subtract(const Duration(hours: 2)),
        expiresAt: screenClock.add(const Duration(hours: 22)),
        durationMinutes: 1440,
        dataMb: 5120,
        maxDevices: 2,
        usedBytes: 1288490188,
      ),
  ]);
}

class _Camera extends MobileScannerController {
  _Camera() : super(autoStart: false);
  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {}
  @override
  Future<void> stop() async {}
}

AuthCubit authForScreenTest({bool signedIn = false}) => AuthCubit(
  locator(),
  sessionStore: locator(),
  biometrics: MockBiometricAuthenticator(),
  wiper: locator(),
  initial: signedIn
      ? const AuthState(
          status: AuthStatus.success,
          user: User(
            id: 'customer',
            fullName: 'Nomsa Dlamini',
            mobileNumber: '0810000000',
          ),
        )
      : const AuthState(),
);

Widget buildScreenForTest(String screen, AppLocalizations l10n) {
  final catalog = _Catalog(l10n);
  return switch (screen) {
    'login' => BlocProvider(
      create: (_) => authForScreenTest(),
      child: const LoginPage(),
    ),
    'home' => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PassesCubit(_Passes(l10n))),
        BlocProvider(
          create: (_) => OpenOrderCubit(
            MockCheckoutRepository(
              InMemorySecureStore(),
              latency: Duration.zero,
            ),
          ),
        ),
      ],
      child: DashboardPage(
        onTopUp: () {},
        onBuyPass: () {},
        onOpenPasses: () {},
        onReportIssue: () {},
        onOpenPromotions: () {},
        onResumeOrder: (_) {},
        now: () => screenClock,
      ),
    ),
    'shop' => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CatalogCubit(catalog)),
        BlocProvider(
          create: (_) => CartCubit()..addItem(catalog.products.first),
        ),
      ],
      child: CatalogPage(
        onOpenCart: () {},
        onFindHotspots: () {},
        onOrderCreated: (_) {},
      ),
    ),
    'cart' => BlocProvider(
      create: (_) => CartCubit()..addItem(catalog.products.first),
      child: CartPage(onCheckout: () {}),
    ),
    'passes' => BlocProvider(
      create: (_) => PassesCubit(_Passes(l10n)),
      child: MyPassesPage(onBuyPass: () {}),
    ),
    'voucher' => VoucherScannerPage(controller: _Camera()),
    'account' => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => authForScreenTest(signedIn: true)),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: const AccountPage(),
    ),
    'help' => BlocProvider(
      create: (_) => SupportCubit(MockSupportRepository()),
      child: const SupportPage(),
    ),
    _ => throw ArgumentError.value(screen),
  };
}
