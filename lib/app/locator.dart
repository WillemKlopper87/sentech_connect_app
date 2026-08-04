import 'package:get_it/get_it.dart';
import 'package:sentech_connect_app/features/account_dashboard/data/repositories/mock_account_repository.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/repositories/account_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/coverage/data/repositories/mock_coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';
import 'package:sentech_connect_app/features/promotions/data/repositories/mock_promotions_repository.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:sentech_connect_app/features/rica/data/repositories/mock_liveness_repository.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

final locator = GetIt.instance;

/// Registers mock-backed repository implementations behind their domain
/// interfaces. Swapping in real Dio-backed implementations later is a
/// drop-in change here — nothing above this layer needs to know.
void setupLocator() {
  locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  locator.registerLazySingleton<CoverageRepository>(() => MockCoverageRepository());
  locator.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository());
  locator.registerLazySingleton<CheckoutRepository>(() => MockCheckoutRepository());
  locator.registerLazySingleton<LivenessRepository>(() => MockLivenessRepository());
  locator.registerLazySingleton<AccountRepository>(() => MockAccountRepository());
  locator.registerLazySingleton<SupportRepository>(() => MockSupportRepository());
  locator.registerLazySingleton<RegistrationRepository>(() => LocalRegistrationRepository());
  locator.registerLazySingleton<PromotionsRepository>(() => MockPromotionsRepository());
  locator.registerLazySingleton<FreeWifiRepository>(() => MockFreeWifiRepository());
  locator.registerLazySingleton<WifiHotspotsRepository>(() => MockWifiHotspotsRepository());
}
