import 'package:get_it/get_it.dart';
import 'package:sentech_connect_app/app/default_personal_data_wiper.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/biometrics/local_auth_biometric_authenticator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/connectivity_service.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/core/storage/flutter_secure_store.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
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
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/mock_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';
import 'package:sentech_connect_app/features/promotions/data/repositories/mock_promotions_repository.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:sentech_connect_app/features/rica/data/repositories/mock_liveness_repository.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/mock_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

final locator = GetIt.instance;

/// Repositories with no platform backend yet (M1 covers tenants, auth,
/// catalog, orders, payments, entitlements and privacy only). They are mock
/// in BOTH flavors (ruling R-M4-8) and are swapped here once their API
/// exists; nothing above this file changes. README lists the same set.
const stillMockInProd = <Type>[
  CoverageRepository,
  FreeWifiRepository,
  WifiHotspotsRepository,
  VoucherRepository,
  AccountRepository,
  PromotionsRepository,
  SupportRepository,
  LivenessRepository,
];

/// [environment] comes from `AppEnvironment.fromDefines()` in main.dart;
/// tests use the default (demo), which never creates an [ApiClient].
void setupLocator({CrashReporter? crashReporter, AppEnvironment environment = AppEnvironment.demo}) {
  locator.registerSingleton<AppEnvironment>(environment);
  _registerPlatformServices(crashReporter);
  _registerStillMockRepositories();
  final baseUrl = environment.apiBaseUrl;
  if (environment.isDemo || baseUrl == null) {
    _registerDemoRepositories();
  } else {
    _registerProdRepositories(baseUrl);
  }
}

void _registerPlatformServices(CrashReporter? crashReporter) {
  // Tests re-register these with fakes (see test/helpers/test_setup.dart).
  locator.registerLazySingleton<ConnectivityService>(() => ConnectivityPlusService());
  locator.registerLazySingleton<SimulatedNetwork>(() => SimulatedNetwork());
  locator.registerSingleton<CrashReporter>(crashReporter ?? ConsoleCrashReporter());
  locator.registerLazySingleton<PlatformClock>(() => SystemPlatformClock());
  locator.registerLazySingleton<SecureStore>(() => FlutterSecureStore());
  locator.registerLazySingleton<BiometricAuthenticator>(() => LocalAuthBiometricAuthenticator());
  locator.registerLazySingleton<SessionStore>(() => SecureSessionStore(locator()));
  locator.registerLazySingleton<NotificationService>(() => PermissionNotificationService());
  locator.registerLazySingleton<TenantContext>(() => TenantContext());
  locator.registerLazySingleton<SessionEvents>(() => SessionEvents());
  locator.registerLazySingleton<PersonalDataWiper>(
    () => DefaultPersonalDataWiper(
      registration: locator(),
      checkout: locator(),
      freeWifi: locator(),
      consent: locator(),
    ),
  );
}

void _registerStillMockRepositories() {
  locator.registerLazySingleton<CoverageRepository>(() => MockCoverageRepository(locator()));
  locator.registerLazySingleton<LivenessRepository>(() => MockLivenessRepository());
  locator.registerLazySingleton<AccountRepository>(() => MockAccountRepository(locator()));
  locator.registerLazySingleton<SupportRepository>(() => MockSupportRepository());
  locator.registerLazySingleton<PromotionsRepository>(() => MockPromotionsRepository());
  locator.registerLazySingleton<VoucherRepository>(() => MockVoucherRepository(locator(), network: locator()));
  locator.registerLazySingleton<FreeWifiRepository>(() => MockFreeWifiRepository(locator(), clock: locator()));
  locator.registerLazySingleton<WifiHotspotsRepository>(() => MockWifiHotspotsRepository());
}

void _registerDemoRepositories() {
  locator.registerLazySingleton<TenantRepository>(() => MockTenantRepository(locator()));
  locator.registerLazySingleton<ConsentRepository>(() => LocalConsentRepository(locator()));
  locator.registerLazySingleton<PrivacyRepository>(() => MockPrivacyRepository(locator()));
  locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  locator.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository(locator()));
  locator.registerLazySingleton<CheckoutRepository>(() => MockCheckoutRepository(locator(), network: locator()));
  locator.registerLazySingleton<RegistrationRepository>(() => LocalRegistrationRepository(locator()));
}

void _registerProdRepositories(Uri baseUrl) {
  locator.registerLazySingleton<TokenStore>(() => SecureTokenStore(locator()));
  locator.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: baseUrl, tokens: locator(), tenant: locator(), sessionEvents: locator()),
  );
  locator.registerLazySingleton<TenantRepository>(() => HttpTenantRepository(locator()));
  locator.registerLazySingleton<ConsentRepository>(() => LocalConsentRepository(locator()));
  locator.registerLazySingleton<PrivacyRepository>(() => MockPrivacyRepository(locator()));
  locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  locator.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository(locator()));
  locator.registerLazySingleton<CheckoutRepository>(() => MockCheckoutRepository(locator(), network: locator()));
  locator.registerLazySingleton<RegistrationRepository>(() => LocalRegistrationRepository(locator()));
}
