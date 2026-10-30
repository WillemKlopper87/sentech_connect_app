import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

/// The one switch for customer entry points whose data is still a mock.
///
/// It reads the same list the locator uses ([stillMockInProd]): a feature is
/// guarded when the build is not demo AND its repository is still listed
/// there. When the real engagement-credits API lands, the repository is swapped
/// in `locator.dart` and removed from [stillMockInProd] (a test forces both), and
/// the entry point comes back by itself. Demo, dev and test builds always show
/// them, so the mocks stay usable.
///
/// Returns true when [repository] is a mock in [environment]'s real flavour.
/// [mockInProd] exists for tests.
bool isMockedInProd(
  AppEnvironment environment,
  Type repository, {
  List<Type> mockInProd = stillMockInProd,
}) => !environment.isDemo && mockInProd.contains(repository);

/// Rewarded-ad "Free Wi-Fi" (`FreeWifiRepository`, watch-ad dialog). Once a real
/// API exists the provider must also have switched the `credits` module on.
bool freeWifiVisible(
  AppEnvironment environment, {
  required bool creditsModuleOn,
  List<Type> mockInProd = stillMockInProd,
}) {
  if (environment.isDemo) return true;
  return !isMockedInProd(environment, FreeWifiRepository, mockInProd: mockInProd) &&
      creditsModuleOn;
}

/// Promotions banner and page (`PromotionsRepository`). The app config has no
/// module for offers, so only the mock guard applies.
bool promotionsVisible(
  AppEnvironment environment, {
  List<Type> mockInProd = stillMockInProd,
}) => !isMockedInProd(environment, PromotionsRepository, mockInProd: mockInProd);
