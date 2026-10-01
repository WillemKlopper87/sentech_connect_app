// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDone => 'Done';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginSubtitle => 'Log in to manage your connection';

  @override
  String get loginUseBiometrics => 'Use biometrics';

  @override
  String get loginOr => 'or';

  @override
  String get loginMobileHint => 'Mobile number';

  @override
  String get biometricPromptReason =>
      'Confirm it is you to log in to Sentech Connect';

  @override
  String get biometricNotEnrolled =>
      'No fingerprint or face is set up on this phone. Add one in system settings.';

  @override
  String get biometricUnavailable =>
      'Biometrics are not available right now. Log in with your mobile number and SMS code.';

  @override
  String get biometricLockedOut =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get biometricPermanentlyLockedOut =>
      'Biometrics are locked. Unlock your phone with your PIN or pattern first.';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginPhoneInvalid =>
      'Enter a valid South African mobile number, e.g. 082 123 4567.';

  @override
  String get loginNewCustomerHint =>
      'New here? Enter your number and we\'ll create your account.';

  @override
  String loginWelcomeBackName(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get loginNotYou => 'Not you? Sign out';

  @override
  String otpSentTo(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get otpCodeHint => '6-digit code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResend => 'Resend code';

  @override
  String otpResendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get otpChangeNumber => 'Change number';

  @override
  String get otpInvalidCode =>
      'That code is not right or has expired. Try again or ask for a new code.';

  @override
  String get otpRateLimited =>
      'Too many attempts. Please wait a moment before trying again.';

  @override
  String get otpServerError =>
      'Something went wrong on our end. Please try again.';

  @override
  String get otpSessionSetupFailed =>
      'We could not finish signing you in. Please request a new code.';

  @override
  String get registerCompleteProfileTitle => 'Complete your profile';

  @override
  String get legalGateTitle => 'Terms of Service';

  @override
  String get legalGateChecking => 'Checking your Terms of Service…';

  @override
  String get legalGateUnavailable =>
      'We could not check the Terms of Service right now. Check your connection and try again.';

  @override
  String get legalGateSignOut => 'Sign out';

  @override
  String get otpDemoHint => 'Demo mode: any 6-digit code except 000000 works.';

  @override
  String get otpOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get registerAcceptTerms =>
      'I accept the Terms of Service and the Privacy notice';

  @override
  String get accountRequestOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get accountRequestRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get biometricFailed =>
      'Biometric check failed. Try again or log in with your SMS code.';

  @override
  String get registerTitle => 'Create an account';

  @override
  String get registerPersonalDetails => 'PERSONAL DETAILS';

  @override
  String get registerFullName => 'Full name';

  @override
  String get registerEmail => 'Email address';

  @override
  String get registerMobile => 'Mobile number';

  @override
  String get registerInstallationAddress => 'INSTALLATION ADDRESS';

  @override
  String get registerAddressHint => 'Street address, suburb, city';

  @override
  String get registerLocationCaptured => 'Location captured';

  @override
  String get registerUseLocation => 'Use my current location';

  @override
  String get registerLocationHelp =>
      'Narrows your coverage check to your exact location — you can still edit the address above.';

  @override
  String get registerContactHeading => 'HOW SHOULD WE CONTACT YOU?';

  @override
  String get registerMarketingHeading => 'MARKETING PREFERENCES';

  @override
  String get registerMarketingEmail => 'Send me offers by email';

  @override
  String get registerMarketingSms => 'Send me offers by SMS';

  @override
  String get registerMarketingPush => 'Send me push notifications';

  @override
  String get registerCreateAccount => 'Create account';

  @override
  String get registerSaveFailed =>
      'Could not save your details — please try again.';

  @override
  String get registerLocationDenied =>
      'Location permission denied — enter your address manually.';

  @override
  String get registerLocationFailed =>
      'Could not get your location — check that location services are on.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountNotLoggedIn => 'Not logged in';

  @override
  String get accountAppearance => 'APPEARANCE';

  @override
  String get accountThemeSystem => 'Match device setting';

  @override
  String get accountThemeLight => 'Light';

  @override
  String get accountThemeDark => 'Dark';

  @override
  String get accountLanguage => 'LANGUAGE';

  @override
  String get accountLanguageSystem => 'Match device language';

  @override
  String get accountLogOut => 'Log out';

  @override
  String get accountLogOutTitle => 'Log out?';

  @override
  String get accountLogOutBody => 'You can log back in at any time.';

  @override
  String get accountNotifications => 'NOTIFICATIONS';

  @override
  String get accountPushTitle => 'Push notifications';

  @override
  String get accountPushOn => 'On — usage alerts, outages and order updates';

  @override
  String get accountPushOff =>
      'Off — turn on to get usage alerts, outages and order updates';

  @override
  String get accountPushBlocked => 'Blocked — change this in system settings';

  @override
  String get accountPushTurnOn => 'Turn on';

  @override
  String get accountPushOpenSettings => 'Open settings';

  @override
  String get accountPrivacy => 'PRIVACY & DATA';

  @override
  String get accountPrivacyPolicy => 'Privacy policy';

  @override
  String get accountDownloadData => 'Download my data';

  @override
  String get accountDownloadDataDone =>
      'Request received. We will send your data to your email once it is ready.';

  @override
  String get accountDeleteData => 'Delete my account & data';

  @override
  String get accountDeleteTitle => 'Delete your account?';

  @override
  String get accountDeleteBody =>
      'This permanently deletes your Sentech account and all personal data stored on this phone. This cannot be undone.';

  @override
  String get accountDeleteConfirm => 'Delete everything';

  @override
  String get accountRequestFailed =>
      'We could not complete that request. Please try again.';

  @override
  String get accountLinkFailed => 'Could not open the link.';

  @override
  String get supportTitle => 'Help & support';

  @override
  String get supportSearchHint => 'Search FAQs';

  @override
  String supportNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get supportStillStuck => 'STILL STUCK?';

  @override
  String get supportWhatsApp => 'WhatsApp';

  @override
  String get supportSubmitTicket => 'Submit a ticket';

  @override
  String get supportTicketCategory => 'Category';

  @override
  String get supportTicketDescribe => 'Describe the issue';

  @override
  String get supportCategoryBilling => 'Billing';

  @override
  String get supportCategoryTechnical => 'Technical';

  @override
  String get supportCategoryOther => 'Other';

  @override
  String get supportWhatsAppFailed =>
      'Could not open WhatsApp — is it installed?';

  @override
  String get supportTicketOpened =>
      'Ticket opened in your email app — send it to submit.';

  @override
  String get supportTicketNoEmail =>
      'Could not open an email app on this device.';

  @override
  String get consentTitle => 'Your privacy';

  @override
  String get consentLocationBody =>
      'We use your phone\'s location once to check 5G coverage at your address. It is not stored on your phone or kept after the check.';

  @override
  String get consentRicaBody =>
      'South African law (RICA) requires us to verify your identity. We will process your face and ID information for verification only, under POPIA.';

  @override
  String get consentLegalBody =>
      'To use the app you need to accept the Terms of Service and the Privacy notice.';

  @override
  String get dataExportTitle => 'Your data';

  @override
  String get dataExportBody =>
      'This is the personal information we hold about you. Keep it private.';

  @override
  String get consentPolicyLink => 'Read our privacy policy';

  @override
  String get consentAgree => 'I agree';

  @override
  String get consentDecline => 'Not now';

  @override
  String get notifRationaleTitle => 'Stay in the loop';

  @override
  String get notifRationaleBody =>
      'Allow notifications so we can tell you when your data is running low, when there is an outage in your area, and when your order moves forward. You can turn this off at any time.';

  @override
  String get notifRationaleAllow => 'Allow notifications';

  @override
  String get notifRationaleLater => 'Not now';

  @override
  String get a11yCart => 'Shopping cart';

  @override
  String get a11yDecreaseQuantity => 'Decrease quantity';

  @override
  String get a11yIncreaseQuantity => 'Increase quantity';

  @override
  String get a11yToggleTorch => 'Toggle flashlight';

  @override
  String get a11yEnterCode => 'Enter code manually';

  @override
  String get tenantPickerTitle => 'Choose your internet provider';

  @override
  String get tenantPickerSubtitle =>
      'Pick the provider you buy Wi-Fi passes from. You can change this later in Account.';

  @override
  String get tenantTypeOperator => 'Network operator';

  @override
  String get tenantTypeReseller => 'Reseller';

  @override
  String get tenantChangeTitle => 'Change provider?';

  @override
  String get tenantChangeBody =>
      'Switching provider signs you out on this phone. Your account with the current provider is not affected.';

  @override
  String get tenantChangeConfirm => 'Switch';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of the app is no longer supported. Install the latest version from your app store to continue.';

  @override
  String get paymentClosedExpired =>
      'This order has expired and can no longer be paid. If you already paid, it will still be applied once the payment provider confirms it.';

  @override
  String get paymentClosedCancelled =>
      'This order was cancelled and can no longer be paid. A payment received after cancellation is held for review and refunded or applied by our team.';

  @override
  String get paymentStillPending =>
      'We have not received confirmation from the payment provider yet. If you completed the payment, check again in a moment. A payment that needs a manual check is held for review: our team will apply or refund it.';

  @override
  String get paymentPayAgainHint =>
      'Only pay again if you did not complete the payment.';

  @override
  String get paymentHandoffInvalid =>
      'We could not open the payment page safely. You have not been charged. Please try again.';

  @override
  String get paymentCheckAgain => 'Check again';

  @override
  String get paymentPayAgain => 'Pay again';

  @override
  String get paymentBackToDashboard => 'Back to dashboard';

  @override
  String get accountProvider => 'PROVIDER';

  @override
  String get accountChangeProvider => 'Change provider';
}
