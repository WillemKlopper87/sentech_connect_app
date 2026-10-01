import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('en'),
    Locale('zu'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to manage your connection'**
  String get loginSubtitle;

  /// No description provided for @loginUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get loginUseBiometrics;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// No description provided for @loginMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get loginMobileHint;

  /// No description provided for @biometricPromptReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you to log in to Sentech Connect'**
  String get biometricPromptReason;

  /// No description provided for @biometricNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint or face is set up on this phone. Add one in system settings.'**
  String get biometricNotEnrolled;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are not available right now. Log in with your mobile number and SMS code.'**
  String get biometricUnavailable;

  /// No description provided for @biometricLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get biometricLockedOut;

  /// No description provided for @biometricPermanentlyLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are locked. Unlock your phone with your PIN or pattern first.'**
  String get biometricPermanentlyLockedOut;

  /// No description provided for @loginSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendCode;

  /// No description provided for @loginPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid South African mobile number, e.g. 082 123 4567.'**
  String get loginPhoneInvalid;

  /// No description provided for @loginNewCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'New here? Enter your number and we\'ll create your account.'**
  String get loginNewCustomerHint;

  /// No description provided for @loginWelcomeBackName.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String loginWelcomeBackName(String name);

  /// No description provided for @loginNotYou.
  ///
  /// In en, this message translates to:
  /// **'Not you? Sign out'**
  String get loginNotYou;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String otpSentTo(String phone);

  /// No description provided for @otpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpCodeHint;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get otpChangeNumber;

  /// No description provided for @otpInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not right or has expired. Try again or ask for a new code.'**
  String get otpInvalidCode;

  /// No description provided for @otpRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment before trying again.'**
  String get otpRateLimited;

  /// No description provided for @otpServerError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again.'**
  String get otpServerError;

  /// No description provided for @otpSessionSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not finish signing you in. Please request a new code.'**
  String get otpSessionSetupFailed;

  /// No description provided for @registerCompleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get registerCompleteProfileTitle;

  /// No description provided for @legalGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalGateTitle;

  /// No description provided for @legalGateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your Terms of Service…'**
  String get legalGateChecking;

  /// No description provided for @legalGateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not check the Terms of Service right now. Check your connection and try again.'**
  String get legalGateUnavailable;

  /// No description provided for @legalGateSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get legalGateSignOut;

  /// No description provided for @otpDemoHint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: any 6-digit code except 000000 works.'**
  String get otpDemoHint;

  /// No description provided for @otpOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get otpOffline;

  /// No description provided for @registerAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms of Service and the Privacy notice'**
  String get registerAcceptTerms;

  /// No description provided for @accountRequestOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get accountRequestOffline;

  /// No description provided for @accountRequestRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get accountRequestRateLimited;

  /// No description provided for @biometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric check failed. Try again or log in with your SMS code.'**
  String get biometricFailed;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get registerTitle;

  /// No description provided for @registerPersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL DETAILS'**
  String get registerPersonalDetails;

  /// No description provided for @registerFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerFullName;

  /// No description provided for @registerEmail.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get registerEmail;

  /// No description provided for @registerMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get registerMobile;

  /// No description provided for @registerInstallationAddress.
  ///
  /// In en, this message translates to:
  /// **'INSTALLATION ADDRESS'**
  String get registerInstallationAddress;

  /// No description provided for @registerAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Street address, suburb, city'**
  String get registerAddressHint;

  /// No description provided for @registerLocationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get registerLocationCaptured;

  /// No description provided for @registerUseLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get registerUseLocation;

  /// No description provided for @registerLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Narrows your coverage check to your exact location — you can still edit the address above.'**
  String get registerLocationHelp;

  /// No description provided for @registerContactHeading.
  ///
  /// In en, this message translates to:
  /// **'HOW SHOULD WE CONTACT YOU?'**
  String get registerContactHeading;

  /// No description provided for @registerMarketingHeading.
  ///
  /// In en, this message translates to:
  /// **'MARKETING PREFERENCES'**
  String get registerMarketingHeading;

  /// No description provided for @registerMarketingEmail.
  ///
  /// In en, this message translates to:
  /// **'Send me offers by email'**
  String get registerMarketingEmail;

  /// No description provided for @registerMarketingSms.
  ///
  /// In en, this message translates to:
  /// **'Send me offers by SMS'**
  String get registerMarketingSms;

  /// No description provided for @registerMarketingPush.
  ///
  /// In en, this message translates to:
  /// **'Send me push notifications'**
  String get registerMarketingPush;

  /// No description provided for @registerCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerCreateAccount;

  /// No description provided for @registerSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your details — please try again.'**
  String get registerSaveFailed;

  /// No description provided for @registerLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied — enter your address manually.'**
  String get registerLocationDenied;

  /// No description provided for @registerLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location — check that location services are on.'**
  String get registerLocationFailed;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get accountNotLoggedIn;

  /// No description provided for @accountAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get accountAppearance;

  /// No description provided for @accountThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device setting'**
  String get accountThemeSystem;

  /// No description provided for @accountThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accountThemeLight;

  /// No description provided for @accountThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get accountThemeDark;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get accountLanguage;

  /// No description provided for @accountLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device language'**
  String get accountLanguageSystem;

  /// No description provided for @accountLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogOut;

  /// No description provided for @accountLogOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get accountLogOutTitle;

  /// No description provided for @accountLogOutBody.
  ///
  /// In en, this message translates to:
  /// **'You can log back in at any time.'**
  String get accountLogOutBody;

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get accountNotifications;

  /// No description provided for @accountPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get accountPushTitle;

  /// No description provided for @accountPushOn.
  ///
  /// In en, this message translates to:
  /// **'On — usage alerts, outages and order updates'**
  String get accountPushOn;

  /// No description provided for @accountPushOff.
  ///
  /// In en, this message translates to:
  /// **'Off — turn on to get usage alerts, outages and order updates'**
  String get accountPushOff;

  /// No description provided for @accountPushBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked — change this in system settings'**
  String get accountPushBlocked;

  /// No description provided for @accountPushTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get accountPushTurnOn;

  /// No description provided for @accountPushOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get accountPushOpenSettings;

  /// No description provided for @accountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & DATA'**
  String get accountPrivacy;

  /// No description provided for @accountPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get accountPrivacyPolicy;

  /// No description provided for @accountDownloadData.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get accountDownloadData;

  /// No description provided for @accountDownloadDataDone.
  ///
  /// In en, this message translates to:
  /// **'Request received. We will send your data to your email once it is ready.'**
  String get accountDownloadDataDone;

  /// No description provided for @accountDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete my account & data'**
  String get accountDeleteData;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your Sentech account and all personal data stored on this phone. This cannot be undone.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get accountDeleteConfirm;

  /// No description provided for @accountRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not complete that request. Please try again.'**
  String get accountRequestFailed;

  /// No description provided for @accountLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get accountLinkFailed;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get supportTitle;

  /// No description provided for @supportSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search FAQs'**
  String get supportSearchHint;

  /// No description provided for @supportNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String supportNoResults(String query);

  /// No description provided for @supportStillStuck.
  ///
  /// In en, this message translates to:
  /// **'STILL STUCK?'**
  String get supportStillStuck;

  /// No description provided for @supportWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get supportWhatsApp;

  /// No description provided for @supportSubmitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit a ticket'**
  String get supportSubmitTicket;

  /// No description provided for @supportTicketCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportTicketCategory;

  /// No description provided for @supportTicketDescribe.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get supportTicketDescribe;

  /// No description provided for @supportCategoryBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get supportCategoryBilling;

  /// No description provided for @supportCategoryTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get supportCategoryTechnical;

  /// No description provided for @supportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportCategoryOther;

  /// No description provided for @supportWhatsAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp — is it installed?'**
  String get supportWhatsAppFailed;

  /// No description provided for @supportTicketOpened.
  ///
  /// In en, this message translates to:
  /// **'Ticket opened in your email app — send it to submit.'**
  String get supportTicketOpened;

  /// No description provided for @supportTicketNoEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not open an email app on this device.'**
  String get supportTicketNoEmail;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get consentTitle;

  /// No description provided for @consentLocationBody.
  ///
  /// In en, this message translates to:
  /// **'We use your phone\'s location once to check 5G coverage at your address. It is not stored on your phone or kept after the check.'**
  String get consentLocationBody;

  /// No description provided for @consentRicaBody.
  ///
  /// In en, this message translates to:
  /// **'South African law (RICA) requires us to verify your identity. We will process your face and ID information for verification only, under POPIA.'**
  String get consentRicaBody;

  /// No description provided for @consentLegalBody.
  ///
  /// In en, this message translates to:
  /// **'To use the app you need to accept the Terms of Service and the Privacy notice.'**
  String get consentLegalBody;

  /// No description provided for @dataExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get dataExportTitle;

  /// No description provided for @dataExportBody.
  ///
  /// In en, this message translates to:
  /// **'This is the personal information we hold about you. Keep it private.'**
  String get dataExportBody;

  /// No description provided for @consentPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'Read our privacy policy'**
  String get consentPolicyLink;

  /// No description provided for @consentAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get consentAgree;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get consentDecline;

  /// No description provided for @notifRationaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop'**
  String get notifRationaleTitle;

  /// No description provided for @notifRationaleBody.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so we can tell you when your data is running low, when there is an outage in your area, and when your order moves forward. You can turn this off at any time.'**
  String get notifRationaleBody;

  /// No description provided for @notifRationaleAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notifRationaleAllow;

  /// No description provided for @notifRationaleLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notifRationaleLater;

  /// No description provided for @a11yCart.
  ///
  /// In en, this message translates to:
  /// **'Shopping cart'**
  String get a11yCart;

  /// No description provided for @a11yDecreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get a11yDecreaseQuantity;

  /// No description provided for @a11yIncreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get a11yIncreaseQuantity;

  /// No description provided for @a11yToggleTorch.
  ///
  /// In en, this message translates to:
  /// **'Toggle flashlight'**
  String get a11yToggleTorch;

  /// No description provided for @a11yEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get a11yEnterCode;

  /// No description provided for @tenantPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your internet provider'**
  String get tenantPickerTitle;

  /// No description provided for @tenantPickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the provider you buy Wi-Fi passes from. You can change this later in Account.'**
  String get tenantPickerSubtitle;

  /// No description provided for @tenantTypeOperator.
  ///
  /// In en, this message translates to:
  /// **'Network operator'**
  String get tenantTypeOperator;

  /// No description provided for @tenantTypeReseller.
  ///
  /// In en, this message translates to:
  /// **'Reseller'**
  String get tenantTypeReseller;

  /// No description provided for @tenantChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change provider?'**
  String get tenantChangeTitle;

  /// No description provided for @tenantChangeBody.
  ///
  /// In en, this message translates to:
  /// **'Switching provider signs you out on this phone. Your account with the current provider is not affected.'**
  String get tenantChangeBody;

  /// No description provided for @tenantChangeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get tenantChangeConfirm;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Install the latest version from your app store to continue.'**
  String get updateRequiredBody;

  /// No description provided for @paymentClosedExpired.
  ///
  /// In en, this message translates to:
  /// **'This order has expired and can no longer be paid. If you already paid, it will still be applied once the payment provider confirms it.'**
  String get paymentClosedExpired;

  /// No description provided for @paymentClosedCancelled.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled and can no longer be paid. A payment received after cancellation is held for review and refunded or applied by our team.'**
  String get paymentClosedCancelled;

  /// No description provided for @paymentStillPending.
  ///
  /// In en, this message translates to:
  /// **'We have not received confirmation from the payment provider yet. If you completed the payment, check again in a moment. A payment that needs a manual check is held for review: our team will apply or refund it.'**
  String get paymentStillPending;

  /// No description provided for @paymentPayAgainHint.
  ///
  /// In en, this message translates to:
  /// **'Only pay again if you did not complete the payment.'**
  String get paymentPayAgainHint;

  /// No description provided for @paymentHandoffInvalid.
  ///
  /// In en, this message translates to:
  /// **'We could not open the payment page safely. You have not been charged. Please try again.'**
  String get paymentHandoffInvalid;

  /// No description provided for @paymentCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get paymentCheckAgain;

  /// No description provided for @paymentPayAgain.
  ///
  /// In en, this message translates to:
  /// **'Pay again'**
  String get paymentPayAgain;

  /// No description provided for @paymentBackToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get paymentBackToDashboard;

  /// No description provided for @accountProvider.
  ///
  /// In en, this message translates to:
  /// **'PROVIDER'**
  String get accountProvider;

  /// No description provided for @accountChangeProvider.
  ///
  /// In en, this message translates to:
  /// **'Change provider'**
  String get accountChangeProvider;

  /// No description provided for @passesTitle.
  ///
  /// In en, this message translates to:
  /// **'My passes'**
  String get passesTitle;

  /// No description provided for @passesEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no active passes. Buy one in Shop.'**
  String get passesEmpty;

  /// No description provided for @passesShowExpired.
  ///
  /// In en, this message translates to:
  /// **'Show expired passes'**
  String get passesShowExpired;

  /// No description provided for @passesStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get passesStatusActive;

  /// No description provided for @passesStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Starts later'**
  String get passesStatusScheduled;

  /// No description provided for @passesStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get passesStatusExpired;

  /// No description provided for @passesStatusExhausted.
  ///
  /// In en, this message translates to:
  /// **'Used up'**
  String get passesStatusExhausted;

  /// No description provided for @passesStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get passesStatusRevoked;

  /// No description provided for @passesExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String passesExpires(String date);

  /// No description provided for @passesStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String passesStarts(String date);

  /// No description provided for @passesDevices.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} devices'**
  String passesDevices(int count);

  /// No description provided for @dashboardMyPasses.
  ///
  /// In en, this message translates to:
  /// **'My passes'**
  String get dashboardMyPasses;

  /// No description provided for @dashboardBuyPass.
  ///
  /// In en, this message translates to:
  /// **'Buy a pass'**
  String get dashboardBuyPass;

  /// No description provided for @dashboardNoPass.
  ///
  /// In en, this message translates to:
  /// **'No active pass'**
  String get dashboardNoPass;

  /// No description provided for @dashboardNoPassHint.
  ///
  /// In en, this message translates to:
  /// **'Buy a Wi-Fi pass to get online.'**
  String get dashboardNoPassHint;

  /// No description provided for @dashboardTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String dashboardTimeLeft(String time);

  /// No description provided for @dashboardDataLeft.
  ///
  /// In en, this message translates to:
  /// **'{left} of {total} left'**
  String dashboardDataLeft(String left, String total);

  /// No description provided for @dashboardUncapped.
  ///
  /// In en, this message translates to:
  /// **'Uncapped data'**
  String get dashboardUncapped;

  /// No description provided for @confirmationViewPasses.
  ///
  /// In en, this message translates to:
  /// **'View my passes'**
  String get confirmationViewPasses;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['af', 'en', 'zu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'en':
      return AppLocalizationsEn();
    case 'zu':
      return AppLocalizationsZu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
