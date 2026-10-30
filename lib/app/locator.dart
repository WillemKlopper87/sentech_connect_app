import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/dev_payment_simulator.dart';
import 'package:sentech_connect_app/app/default_personal_data_wiper.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/biometrics/local_auth_biometric_authenticator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/connectivity_service.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/human_check_config.dart';
import 'package:sentech_connect_app/core/security/human_check_gate.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/shared/widgets/human_check_sheet.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/core/storage/flutter_secure_store.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/coverage/data/repositories/mock_coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/mock_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/kyc/plugin_id_image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/promotions/data/repositories/mock_promotions_repository.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:sentech_connect_app/features/rica/data/repositories/mock_liveness_repository.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/data/http_hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/data/mock_hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/repositories/hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/http_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/pass_local_store.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/usage_alert_scheduler.dart';
import 'package:sentech_connect_app/features/support/data/repositories/http_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/http_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/mock_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/http_wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

final locator = GetIt.instance;

/// Repositories with no platform backend yet (M1 covers tenants, auth,
/// catalog, orders, payments, entitlements and privacy only). They are mock
/// in BOTH flavors (ruling R-M4-8) and are swapped here once their API
/// exists; nothing above this file changes. README ("Mock repositories and
/// their real routes") lists the same set with the real API route for each.
const stillMockInProd = <Type>[
  CoverageRepository,
  FreeWifiRepository,
  PromotionsRepository,
  SupportRepository,
  LivenessRepository,
];

/// Mocks and local-only stores that are mock BY DESIGN until the task named
/// beside each one swaps in its HTTP implementation. A later task must remove
/// the entry in the same change (test/locator_test.dart fails otherwise, in
/// both directions).
const mockUntilLaterTasks = <Type>[];

/// [environment] comes from `AppEnvironment.fromDefines()` in main.dart;
/// tests use the default (demo), which never creates an [ApiClient].
void setupLocator({
  CrashReporter? crashReporter,
  AppEnvironment environment = AppEnvironment.demo,
  TurnstileConfig? turnstile,
}) {
  // Validate before registering anything, so a bad environment leaves no
  // half-built container. A prod flavor must never fall back to mocks: that
  // would ship fake data as if it were real.
  final baseUrl = environment.apiBaseUrl;
  if (!environment.isDemo && baseUrl == null) {
    throw const InvalidEnvironment('APP_FLAVOR=prod needs an API base URL.');
  }
  locator.registerSingleton<AppEnvironment>(environment);
  _registerPlatformServices(crashReporter);
  _registerStillMockRepositories();
  locator.registerLazySingleton<IdImagePicker>(() => PluginIdImagePicker());
  if (environment.isDemo) {
    _registerDemoRepositories();
  } else {
    _registerProdRepositories(baseUrl!, turnstile ?? TurnstileConfig.fromDefines());
  }
}

void _registerPlatformServices(CrashReporter? crashReporter) {
  // Tests re-register these with fakes (see test/helpers/test_setup.dart).
  locator.registerLazySingleton<ConnectivityService>(
    () => ConnectivityPlusService(),
  );
  locator.registerLazySingleton<SimulatedNetwork>(() => SimulatedNetwork());
  locator.registerSingleton<CrashReporter>(
    crashReporter ?? ConsoleCrashReporter(),
  );
  locator.registerLazySingleton<PlatformClock>(() => SystemPlatformClock());
  locator.registerLazySingleton<SecureStore>(() => FlutterSecureStore());
  locator.registerLazySingleton<BiometricAuthenticator>(
    () => LocalAuthBiometricAuthenticator(),
  );
  locator.registerLazySingleton<SessionStore>(
    () => SecureSessionStore(locator()),
  );
  locator.registerLazySingleton<NotificationService>(
    () => PermissionNotificationService(),
  );
  locator.registerLazySingleton<TenantContext>(() => TenantContext());
  locator.registerLazySingleton<PassLocalStore>(() => PassLocalStore());
  locator.registerLazySingleton<TenantPreferences>(
    () => SharedPrefsTenantPreferences(),
  );
  locator.registerLazySingleton<SessionEvents>(() => SessionEvents());
  locator.registerLazySingleton<PersonalDataWiper>(
    () => DefaultPersonalDataWiper(
      registration: locator(),
      checkout: locator(),
      freeWifi: locator(),
      consent: locator(),
      passes: locator(),
    ),
  );
}

void _registerStillMockRepositories() {
  locator.registerLazySingleton<CoverageRepository>(
    () => MockCoverageRepository(locator()),
  );
  locator.registerLazySingleton<LivenessRepository>(
    () => MockLivenessRepository(),
  );
  locator.registerLazySingleton<SupportRepository>(
    () => MockSupportRepository(),
  );
  locator.registerLazySingleton<PromotionsRepository>(
    () => MockPromotionsRepository(now: locator<PlatformClock>().wallNow),
  );
  locator.registerLazySingleton<FreeWifiRepository>(
    () => MockFreeWifiRepository(locator(), clock: locator()),
  );
}

void _registerDemoRepositories() {
  locator.registerLazySingleton<WifiHotspotsRepository>(
    () => MockWifiHotspotsRepository(),
  );
  locator.registerLazySingleton<TenantRepository>(
    () => MockTenantRepository(locator()),
  );
  locator.registerLazySingleton<ConsentRepository>(
    () => LocalConsentRepository(locator()),
  );
  locator.registerLazySingleton<SubscriberPlansRepository>(
    () => MockSubscriberPlansRepository(),
  );
  locator.registerLazySingleton<SubscriberRepository>(
    () => MockSubscriberRepository(),
  );
  locator.registerLazySingleton<InvoiceRepository>(
    () => MockInvoiceRepository(),
  );
  locator.registerLazySingleton<KycRepository>(() => MockKycRepository());
  locator.registerLazySingleton<HotspotLoginRepository>(() => MockHotspotLoginRepository());
  locator.registerLazySingleton<SubscriberProfileRepository>(() => MockSubscriberProfileRepository());
  locator.registerLazySingleton<PrivacyRepository>(
    () => MockPrivacyRepository(locator()),
  );
  locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  locator.registerLazySingleton<CatalogRepository>(
    () => MockCatalogRepository(locator()),
  );
  locator.registerLazySingleton<PassesRepository>(
    () => MockPassesRepository(network: locator()),
  );
  locator.registerLazySingleton<CheckoutRepository>(
    () => MockCheckoutRepository(locator(), network: locator()),
  );
  locator.registerLazySingleton<RegistrationRepository>(
    () => LocalRegistrationRepository(locator()),
  );
  locator.registerLazySingleton<VoucherRepository>(
    () => MockVoucherRepository(locator(), network: locator()),
  );
  locator.registerLazySingleton<SupportMessageRepository>(
    () => MockSupportMessageRepository(),
  );
}

void _registerProdRepositories(Uri baseUrl, TurnstileConfig? turnstile) {
  _registerHumanCheck(turnstile);
  locator.registerLazySingleton<TokenStore>(() => SecureTokenStore(locator()));
  locator.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: baseUrl,
      tokens: locator(),
      tenant: locator(),
      sessionEvents: locator(),
    ),
  );
  locator.registerLazySingleton<WifiHotspotsRepository>(
    () => HttpWifiHotspotsRepository(locator(), locator()),
  );
  locator.registerLazySingleton<TenantRepository>(
    () => HttpTenantRepository(locator(), crashReporter: locator()),
  );
  locator.registerLazySingleton<ConsentRepository>(
    () => HttpConsentRepository(
      locator(),
      local: LocalConsentRepository(locator()),
      tenant: locator(),
    ),
  );
  locator.registerLazySingleton<PrivacyRepository>(
    () => HttpPrivacyRepository(
      locator(),
      humanCheck: locator<HumanCheckGate>().forAction(HumanCheckAction.deleteChallenge),
    ),
  );
  locator.registerLazySingleton<AuthRepository>(
    () => HttpAuthRepository(
      locator(),
      tokens: locator(),
      tenant: locator(),
      humanCheck: locator<HumanCheckGate>().forAction(HumanCheckAction.otpRequest),
    ),
  );
  locator.registerLazySingleton<PassesRepository>(
    () => HttpPassesRepository(
      locator(),
      tokens: locator(),
      cache: locator(),
      now: locator<PlatformClock>().wallNow,
    ),
  );
  locator.registerLazySingleton<UsageAlertScheduler>(
    () => const NoopUsageAlertScheduler(),
  );
  locator.registerLazySingleton<UsageAlertCoordinator>(
    () => UsageAlertCoordinator(
      api: locator(),
      tokens: locator(),
      store: locator(),
      scheduler: locator(),
      now: locator<PlatformClock>().wallNow,
      notifications: locator(),
    ),
  );
  locator.registerLazySingleton<CatalogRepository>(
    () => HttpCatalogRepository(locator(), locator()),
  );
  locator.registerLazySingleton<SubscriberPlansRepository>(
    () => HttpSubscriberPlansRepository(locator(), locator()),
  );
  locator.registerLazySingleton<SubscriberRepository>(
    () => HttpSubscriberRepository(locator()),
  );
  locator.registerLazySingleton<InvoiceRepository>(
    () => HttpInvoiceRepository(locator()),
  );
  locator.registerLazySingleton<KycRepository>(() => HttpKycRepository(locator()));
  locator.registerLazySingleton<HotspotLoginRepository>(() => HttpHotspotLoginRepository(locator()));
  locator.registerLazySingleton<SubscriberProfileRepository>(() => HttpSubscriberProfileRepository(locator()));
  locator.registerLazySingleton<CheckoutRepository>(
    () => HttpCheckoutRepository(locator()),
  );
  locator.registerLazySingleton<VoucherRepository>(
    () => HttpVoucherRepository(locator()),
  );
  // The dev simulate endpoint only exists on dev/test APIs; the app offers it
  // only in debug builds talking to a local host (ruling R-M4-13).
  if (kDebugMode && AppEnvironment.localDevHosts.contains(baseUrl.host)) {
    locator.registerLazySingleton<DevPaymentSimulator>(
      () => DevPaymentSimulator(locator()),
    );
  }
  locator.registerLazySingleton<SupportMessageRepository>(
    () => HttpSupportMessageRepository(
      locator(),
      tenant: locator(),
      humanCheck: locator<HumanCheckGate>().forAction(HumanCheckAction.supportMessage),
    ),
  );
  locator.registerLazySingleton<RegistrationRepository>(
    () => HttpRegistrationRepository(
      locator(),
      local: LocalRegistrationRepository(locator()),
    ),
  );
}

/// The human check for the real API (prod flavor only; the demo flavor never
/// has a WebView and uses no check at all).
///
/// [HumanCheckGate] asks the API what is enforced and which Turnstile site key
/// to use (the API wins; the build defines in [turnstile] are only the
/// fallback when that route fails) and hands each repository a
/// [HumanCheckProvider] for ITS action: `locator<HumanCheckGate>().forAction(..)`.
/// Tiers, in order of preference: (A, not built yet) platform attestation,
/// (B) the Turnstile WebView, (none) dev and test stacks that accept a request
/// without a token. A future attestation provider is composed inside the gate
/// as `FallbackHumanCheckProvider(primary: attestation, fallback: turnstile)`;
/// the repositories only ever see a [HumanCheckProvider].
void _registerHumanCheck(TurnstileConfig? turnstile) {
  final presenter = NavigatorHumanCheckPresenter(GlobalKey<NavigatorState>(debugLabel: 'root'));
  locator.registerSingleton<NavigatorHumanCheckPresenter>(presenter);
  locator.registerLazySingleton<HumanCheckConfigRepository>(
    () => HttpHumanCheckConfigRepository(locator()),
  );
  locator.registerLazySingleton<HumanCheckGate>(
    () => HumanCheckGate(
      repository: locator(),
      tenant: locator(),
      presenter: presenter,
      buildConfig: turnstile,
    ),
  );
}
