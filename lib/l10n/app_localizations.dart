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

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Customer app copy: common continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Customer app copy: common retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Customer app copy: login welcome back.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// Customer app copy: login subtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to manage your connection'**
  String get loginSubtitle;

  /// Customer app copy: login use biometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get loginUseBiometrics;

  /// Customer app copy: login or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// Customer app copy: login mobile hint.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get loginMobileHint;

  /// Customer app copy: biometric prompt reason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you to log in to Sentech Connect'**
  String get biometricPromptReason;

  /// Customer app copy: biometric not enrolled.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint or face is set up on this phone. Add one in system settings.'**
  String get biometricNotEnrolled;

  /// Customer app copy: biometric unavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are not available right now. Log in with your mobile number and SMS code.'**
  String get biometricUnavailable;

  /// Customer app copy: biometric locked out.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get biometricLockedOut;

  /// Customer app copy: biometric permanently locked out.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are locked. Unlock your phone with your PIN or pattern first.'**
  String get biometricPermanentlyLockedOut;

  /// Customer app copy: login send code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendCode;

  /// Customer app copy: login phone invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid South African mobile number, e.g. 082 123 4567.'**
  String get loginPhoneInvalid;

  /// Customer app copy: login new customer hint.
  ///
  /// In en, this message translates to:
  /// **'New here? Enter your number and we\'ll create your account.'**
  String get loginNewCustomerHint;

  /// Customer app copy: login welcome back name.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String loginWelcomeBackName(String name);

  /// Customer app copy: login not you.
  ///
  /// In en, this message translates to:
  /// **'Not you? Sign out'**
  String get loginNotYou;

  /// Customer app copy: otp sent to.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String otpSentTo(String phone);

  /// Customer app copy: otp code hint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpCodeHint;

  /// Customer app copy: otp verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// Customer app copy: otp resend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// Customer app copy: otp resend in.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String otpResendIn(int seconds);

  /// Customer app copy: otp change number.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get otpChangeNumber;

  /// Customer app copy: otp invalid code.
  ///
  /// In en, this message translates to:
  /// **'That code is not right or has expired. Try again or ask for a new code.'**
  String get otpInvalidCode;

  /// Customer app copy: otp rate limited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment before trying again.'**
  String get otpRateLimited;

  /// Customer app copy: otp server error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again.'**
  String get otpServerError;

  /// Customer app copy: otp session setup failed.
  ///
  /// In en, this message translates to:
  /// **'We could not finish signing you in. Please request a new code.'**
  String get otpSessionSetupFailed;

  /// Customer app copy: register complete profile title.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get registerCompleteProfileTitle;

  /// Customer app copy: legal gate title.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalGateTitle;

  /// Customer app copy: legal gate checking.
  ///
  /// In en, this message translates to:
  /// **'Checking your Terms of Service…'**
  String get legalGateChecking;

  /// Customer app copy: legal gate unavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not check the Terms of Service right now. Check your connection and try again.'**
  String get legalGateUnavailable;

  /// Customer app copy: legal gate sign out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get legalGateSignOut;

  /// Customer app copy: otp demo hint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: any 6-digit code except 000000 works.'**
  String get otpDemoHint;

  /// Customer app copy: otp offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get otpOffline;

  /// Customer app copy: register accept terms.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms of Service and the Privacy notice'**
  String get registerAcceptTerms;

  /// Customer app copy: account request offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get accountRequestOffline;

  /// Customer app copy: account request rate limited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get accountRequestRateLimited;

  /// Customer app copy: signed out provider unavailable.
  ///
  /// In en, this message translates to:
  /// **'Your provider is currently unavailable, so you have been signed out. Please try again later.'**
  String get signedOutProviderUnavailable;

  /// Customer app copy: biometric failed.
  ///
  /// In en, this message translates to:
  /// **'Biometric check failed. Try again or log in with your SMS code.'**
  String get biometricFailed;

  /// Customer app copy: register title.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get registerTitle;

  /// Customer app copy: register personal details.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL DETAILS'**
  String get registerPersonalDetails;

  /// Customer app copy: register full name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerFullName;

  /// Customer app copy: register email.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get registerEmail;

  /// Customer app copy: register mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get registerMobile;

  /// Customer app copy: register installation address.
  ///
  /// In en, this message translates to:
  /// **'INSTALLATION ADDRESS'**
  String get registerInstallationAddress;

  /// Customer app copy: register address hint.
  ///
  /// In en, this message translates to:
  /// **'Street address, suburb, city'**
  String get registerAddressHint;

  /// Customer app copy: register location captured.
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get registerLocationCaptured;

  /// Customer app copy: register use location.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get registerUseLocation;

  /// Customer app copy: register location help.
  ///
  /// In en, this message translates to:
  /// **'Narrows your coverage check to your exact location — you can still edit the address above.'**
  String get registerLocationHelp;

  /// Customer app copy: register contact heading.
  ///
  /// In en, this message translates to:
  /// **'HOW SHOULD WE CONTACT YOU?'**
  String get registerContactHeading;

  /// Customer app copy: register marketing heading.
  ///
  /// In en, this message translates to:
  /// **'MARKETING PREFERENCES'**
  String get registerMarketingHeading;

  /// Customer app copy: register marketing email.
  ///
  /// In en, this message translates to:
  /// **'Send me offers by email'**
  String get registerMarketingEmail;

  /// Customer app copy: register marketing sms.
  ///
  /// In en, this message translates to:
  /// **'Send me offers by SMS'**
  String get registerMarketingSms;

  /// Customer app copy: register marketing push.
  ///
  /// In en, this message translates to:
  /// **'Send me push notifications'**
  String get registerMarketingPush;

  /// Customer app copy: register create account.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerCreateAccount;

  /// Customer app copy: register save failed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your details — please try again.'**
  String get registerSaveFailed;

  /// Customer app copy: register location denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied — enter your address manually.'**
  String get registerLocationDenied;

  /// Customer app copy: register location failed.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location — check that location services are on.'**
  String get registerLocationFailed;

  /// Customer app copy: account title.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// Customer app copy: account not logged in.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get accountNotLoggedIn;

  /// Customer app copy: account appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// Account switch for fewer pictures and decorative animations.
  ///
  /// In en, this message translates to:
  /// **'Data saver: fewer pictures and no animations'**
  String get accountDataSaver;

  /// Shown when the Data saver setting could not be saved on this device.
  ///
  /// In en, this message translates to:
  /// **'Could not save Data saver. Try again.'**
  String get accountDataSaverSaveFailed;

  /// Customer app copy: account theme system.
  ///
  /// In en, this message translates to:
  /// **'Match device setting'**
  String get accountThemeSystem;

  /// Customer app copy: account theme light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accountThemeLight;

  /// Customer app copy: account theme dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get accountThemeDark;

  /// Customer app copy: account language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// Customer app copy: account language system.
  ///
  /// In en, this message translates to:
  /// **'Match device language'**
  String get accountLanguageSystem;

  /// Customer app copy: account log out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogOut;

  /// Customer app copy: account log out title.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get accountLogOutTitle;

  /// Customer app copy: account log out body.
  ///
  /// In en, this message translates to:
  /// **'You can log back in at any time.'**
  String get accountLogOutBody;

  /// Customer app copy: account push title.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get accountPushTitle;

  /// Customer app copy: account push on.
  ///
  /// In en, this message translates to:
  /// **'On — usage alerts, outages and order updates'**
  String get accountPushOn;

  /// Customer app copy: account push off.
  ///
  /// In en, this message translates to:
  /// **'Off — turn on to get usage alerts, outages and order updates'**
  String get accountPushOff;

  /// Customer app copy: account push blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked — change this in system settings'**
  String get accountPushBlocked;

  /// Customer app copy: account push turn on.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get accountPushTurnOn;

  /// Customer app copy: account push open settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get accountPushOpenSettings;

  /// Customer app copy: account privacy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & DATA'**
  String get accountPrivacy;

  /// Customer app copy: account privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get accountPrivacyPolicy;

  /// Customer app copy: account download data.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get accountDownloadData;

  /// Customer app copy: account download data done.
  ///
  /// In en, this message translates to:
  /// **'Request received. We will send your data to your email once it is ready.'**
  String get accountDownloadDataDone;

  /// Customer app copy: account delete data.
  ///
  /// In en, this message translates to:
  /// **'Delete my account & data'**
  String get accountDeleteData;

  /// Customer app copy: account delete title.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// Customer app copy: account delete body.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your Sentech account and all personal data stored on this phone. This cannot be undone.'**
  String get accountDeleteBody;

  /// Customer app copy: account delete confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get accountDeleteConfirm;

  /// Customer app copy: account request failed.
  ///
  /// In en, this message translates to:
  /// **'We could not complete that request. Please try again.'**
  String get accountRequestFailed;

  /// Customer app copy: account link failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get accountLinkFailed;

  /// Customer app copy: support title.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get supportTitle;

  /// Customer app copy: support search hint.
  ///
  /// In en, this message translates to:
  /// **'Search FAQs'**
  String get supportSearchHint;

  /// Customer app copy: support no results.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String supportNoResults(String query);

  /// Customer app copy: support still stuck.
  ///
  /// In en, this message translates to:
  /// **'STILL STUCK?'**
  String get supportStillStuck;

  /// Customer app copy: support whats app.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get supportWhatsApp;

  /// Customer app copy: support submit ticket.
  ///
  /// In en, this message translates to:
  /// **'Submit a ticket'**
  String get supportSubmitTicket;

  /// Customer app copy: support ticket category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportTicketCategory;

  /// Customer app copy: support ticket describe.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get supportTicketDescribe;

  /// Customer app copy: support category billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get supportCategoryBilling;

  /// Customer app copy: support category technical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get supportCategoryTechnical;

  /// Customer app copy: support category other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportCategoryOther;

  /// Customer app copy: support whats app failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp — is it installed?'**
  String get supportWhatsAppFailed;

  /// Customer app copy: support ticket opened.
  ///
  /// In en, this message translates to:
  /// **'Ticket opened in your email app — send it to submit.'**
  String get supportTicketOpened;

  /// Customer app copy: support ticket no email.
  ///
  /// In en, this message translates to:
  /// **'Could not open an email app on this device.'**
  String get supportTicketNoEmail;

  /// Customer app copy: consent title.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get consentTitle;

  /// Customer app copy: consent location body.
  ///
  /// In en, this message translates to:
  /// **'We use your phone\'s location once to check 5G coverage at your address. It is not stored on your phone or kept after the check.'**
  String get consentLocationBody;

  /// Customer app copy: consent location map service.
  ///
  /// In en, this message translates to:
  /// **'To turn your location into an address, your phone\'s map service (Google or Apple) looks it up.'**
  String get consentLocationMapService;

  /// Customer app copy: coverage address lookup notice.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s map service (Google or Apple) finds the address you type.'**
  String get coverageAddressLookupNotice;

  /// Customer app copy: consent rica body.
  ///
  /// In en, this message translates to:
  /// **'South African law (RICA) requires us to verify your identity. We will process your face and ID information for verification only, under POPIA.'**
  String get consentRicaBody;

  /// Customer app copy: consent legal body.
  ///
  /// In en, this message translates to:
  /// **'To use the app you need to accept the Terms of Service and the Privacy notice.'**
  String get consentLegalBody;

  /// Customer app copy: data export title.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get dataExportTitle;

  /// Customer app copy: data export body.
  ///
  /// In en, this message translates to:
  /// **'This is the personal information we hold about you. Keep it private.'**
  String get dataExportBody;

  /// Customer app copy: consent policy link.
  ///
  /// In en, this message translates to:
  /// **'Read our privacy policy'**
  String get consentPolicyLink;

  /// Customer app copy: consent agree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get consentAgree;

  /// Customer app copy: consent decline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get consentDecline;

  /// Customer app copy: notif rationale title.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop'**
  String get notifRationaleTitle;

  /// Customer app copy: notif rationale body.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so we can tell you when your data is running low, when there is an outage in your area, and when your order moves forward. You can turn this off at any time.'**
  String get notifRationaleBody;

  /// Customer app copy: notif rationale allow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notifRationaleAllow;

  /// Customer app copy: notif rationale later.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notifRationaleLater;

  /// Customer app copy: a11y cart.
  ///
  /// In en, this message translates to:
  /// **'Shopping cart'**
  String get a11yCart;

  /// Customer app copy: a11y decrease quantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get a11yDecreaseQuantity;

  /// Customer app copy: a11y increase quantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get a11yIncreaseQuantity;

  /// Customer app copy: a11y toggle torch.
  ///
  /// In en, this message translates to:
  /// **'Toggle flashlight'**
  String get a11yToggleTorch;

  /// Customer app copy: a11y enter code.
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get a11yEnterCode;

  /// Customer app copy: tenant picker title.
  ///
  /// In en, this message translates to:
  /// **'Choose your internet provider'**
  String get tenantPickerTitle;

  /// Customer app copy: tenant picker subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the provider you buy Wi-Fi passes from. You can change this later in Account.'**
  String get tenantPickerSubtitle;

  /// Customer app copy: tenant type operator.
  ///
  /// In en, this message translates to:
  /// **'Network operator'**
  String get tenantTypeOperator;

  /// Customer app copy: tenant type reseller.
  ///
  /// In en, this message translates to:
  /// **'Reseller'**
  String get tenantTypeReseller;

  /// Customer app copy: tenant change title.
  ///
  /// In en, this message translates to:
  /// **'Change provider?'**
  String get tenantChangeTitle;

  /// Customer app copy: tenant change body.
  ///
  /// In en, this message translates to:
  /// **'Switching provider signs you out on this phone. Your account with the current provider is not affected.'**
  String get tenantChangeBody;

  /// Customer app copy: tenant change confirm.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get tenantChangeConfirm;

  /// Customer app copy: update required title.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// Customer app copy: update required body.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Install the latest version from your app store to continue.'**
  String get updateRequiredBody;

  /// Customer app copy: payment closed expired.
  ///
  /// In en, this message translates to:
  /// **'This order has expired and can no longer be paid. If you already paid, it will still be applied once the payment provider confirms it.'**
  String get paymentClosedExpired;

  /// Customer app copy: payment closed cancelled.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled and can no longer be paid. A payment received after cancellation is held for review and refunded or applied by our team.'**
  String get paymentClosedCancelled;

  /// Customer app copy: payment still pending.
  ///
  /// In en, this message translates to:
  /// **'We have not received confirmation from the payment provider yet. If you completed the payment, check again in a moment. A payment that needs a manual check is held for review: our team will apply or refund it.'**
  String get paymentStillPending;

  /// Customer app copy: payment pay again hint.
  ///
  /// In en, this message translates to:
  /// **'Only pay again if you did not complete the payment.'**
  String get paymentPayAgainHint;

  /// Customer app copy: payment handoff invalid.
  ///
  /// In en, this message translates to:
  /// **'We could not open the payment page safely. You have not been charged. Please try again.'**
  String get paymentHandoffInvalid;

  /// Customer app copy: payment check again.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get paymentCheckAgain;

  /// Customer app copy: payment pay again.
  ///
  /// In en, this message translates to:
  /// **'Pay again'**
  String get paymentPayAgain;

  /// Customer app copy: payment back to dashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get paymentBackToDashboard;

  /// Account row that returns to the provider picker.
  ///
  /// In en, this message translates to:
  /// **'Switch WiFi provider'**
  String get accountSwitchProvider;

  /// Account row that opens the provider's support channels.
  ///
  /// In en, this message translates to:
  /// **'Contact {provider}'**
  String accountContactProvider(String provider);

  /// Customer app copy: passes title.
  ///
  /// In en, this message translates to:
  /// **'My passes'**
  String get passesTitle;

  /// A pass has ended.
  ///
  /// In en, this message translates to:
  /// **'Pass ended'**
  String get passEnded;

  /// Pass end date and remaining time.
  ///
  /// In en, this message translates to:
  /// **'ends {date} (in {time})'**
  String passEndsIn(String date, String time);

  /// Total data cap for the pass.
  ///
  /// In en, this message translates to:
  /// **'of {cap}'**
  String passOfCap(String cap);

  /// Age of cached or older pass information.
  ///
  /// In en, this message translates to:
  /// **'Updated {ago} ago'**
  String passesUpdated(String ago);

  /// Account setting for pass usage alerts.
  ///
  /// In en, this message translates to:
  /// **'Usage alerts'**
  String get accountUsageAlerts;

  /// Alerts cannot be delivered until a transport exists.
  ///
  /// In en, this message translates to:
  /// **'Usage alerts are not available yet.'**
  String get accountUsageAlertsUnavailable;

  /// Customer app copy: passes empty.
  ///
  /// In en, this message translates to:
  /// **'You have no active passes. Buy one in Shop.'**
  String get passesEmpty;

  /// Customer app copy: passes show expired.
  ///
  /// In en, this message translates to:
  /// **'Show expired passes'**
  String get passesShowExpired;

  /// Customer app copy: passes status active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get passesStatusActive;

  /// Customer app copy: passes status scheduled.
  ///
  /// In en, this message translates to:
  /// **'Starts later'**
  String get passesStatusScheduled;

  /// Customer app copy: passes status expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get passesStatusExpired;

  /// Customer app copy: passes status exhausted.
  ///
  /// In en, this message translates to:
  /// **'Used up'**
  String get passesStatusExhausted;

  /// Customer app copy: passes status revoked.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get passesStatusRevoked;

  /// Customer app copy: passes expires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String passesExpires(String date);

  /// Customer app copy: passes starts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String passesStarts(String date);

  /// Customer app copy: passes devices.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} devices'**
  String passesDevices(int count);

  /// Customer app copy: dashboard my passes.
  ///
  /// In en, this message translates to:
  /// **'My passes'**
  String get dashboardMyPasses;

  /// Customer app copy: dashboard buy pass.
  ///
  /// In en, this message translates to:
  /// **'Buy a pass'**
  String get dashboardBuyPass;

  /// Customer app copy: dashboard no pass.
  ///
  /// In en, this message translates to:
  /// **'No active pass'**
  String get dashboardNoPass;

  /// Customer app copy: dashboard no pass hint.
  ///
  /// In en, this message translates to:
  /// **'Buy a Wi-Fi pass to get online.'**
  String get dashboardNoPassHint;

  /// Customer app copy: dashboard time left.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String dashboardTimeLeft(String time);

  /// Customer app copy: dashboard data left.
  ///
  /// In en, this message translates to:
  /// **'{left} of {total} left'**
  String dashboardDataLeft(String left, String total);

  /// Customer app copy: dashboard uncapped.
  ///
  /// In en, this message translates to:
  /// **'Uncapped data'**
  String get dashboardUncapped;

  /// Customer app copy: confirmation view passes.
  ///
  /// In en, this message translates to:
  /// **'View my passes'**
  String get confirmationViewPasses;

  /// Customer app copy: passes expired at.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String passesExpiredAt(String date);

  /// Customer app copy: passes ended at.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String passesEndedAt(String date);

  /// Customer app copy: passes just paid hint.
  ///
  /// In en, this message translates to:
  /// **'Just paid? It can take a minute to appear. Pull down to refresh.'**
  String get passesJustPaidHint;

  /// Customer app copy: duration days hours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String durationDaysHours(int days, int hours);

  /// Customer app copy: duration hours minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// Customer app copy: duration minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);

  /// Customer app copy: size megabytes.
  ///
  /// In en, this message translates to:
  /// **'{amount} MB'**
  String sizeMegabytes(String amount);

  /// Customer app copy: size gigabytes.
  ///
  /// In en, this message translates to:
  /// **'{amount} GB'**
  String sizeGigabytes(String amount);

  /// Customer app copy: dashboard top up.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get dashboardTopUp;

  /// Customer app copy: dashboard upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get dashboardUpgrade;

  /// Customer app copy: dashboard report issue.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get dashboardReportIssue;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get navShop;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get navHelp;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// Navigation or common action label.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Price including VAT.
  ///
  /// In en, this message translates to:
  /// **'{price} incl. VAT'**
  String priceInclVat(String price);

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'Finish your order #{number}'**
  String homeFinishOrder(String number);

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'{used} GB of {total} GB'**
  String homeDataUsed(String used, String total);

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'{plan} · renews {date}'**
  String homePlanRenews(String plan, String date);

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'MAC •• •• {suffix}'**
  String homeRouterAddress(String suffix);

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to continue'**
  String get homeVerifyYourIdentityToContinue;

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'Your last payment did not go through. Try again.'**
  String get homeYourLastPaymentDidNotGo;

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'Complete your payment'**
  String get homeCompleteYourPayment;

  /// Customer copy in dashboard page.
  ///
  /// In en, this message translates to:
  /// **'USED'**
  String get homeUsed;

  /// Customer copy in catalog page.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get shopTitle;

  /// Customer copy in catalog page.
  ///
  /// In en, this message translates to:
  /// **'{name} added to cart'**
  String shopAddedToCart(String name);

  /// Editorial recommendation selected by the catalogue owner; no popularity claim.
  ///
  /// In en, this message translates to:
  /// **'Our pick'**
  String get planBadgeOurPick;

  /// Customer copy in catalog page.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get pricePerMonth;

  /// Customer copy in catalog page.
  ///
  /// In en, this message translates to:
  /// **'{data} · up to {speed} Mbps'**
  String shopPlanSpeed(String data, String speed);

  /// Customer copy in catalog page.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get shopAddToCart;

  /// Customer copy in cart page.
  ///
  /// In en, this message translates to:
  /// **'{price} each'**
  String cartPriceEach(String price);

  /// Customer copy in cart page.
  ///
  /// In en, this message translates to:
  /// **'Your cart'**
  String get cartYourCart;

  /// Customer copy in cart page.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartYourCartIsEmpty;

  /// Customer copy in cart page.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get cartTotal;

  /// Customer copy in cart page.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get cartCheckout;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutCheckout;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get checkoutToPay;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get checkoutTotalDue;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'Verify identity to continue'**
  String get checkoutVerifyIdentityToContinue;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get checkoutContinueToPayment;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Order #{number} expired before payment was confirmed.'**
  String orderExpiredBeforePayment(String number);

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Order #{number} was cancelled.'**
  String orderCancelled(String number);

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Order #{number} is not complete yet.'**
  String orderNotComplete(String number);

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String orderNumberLabel(String number);

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get confirmationOrder;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get confirmationBackToHome;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Continue your order'**
  String get confirmationContinueYourOrder;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Track my installation'**
  String get confirmationTrackMyInstallation;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Courier dispatched'**
  String get confirmationCourierDispatched;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Router kit on its way'**
  String get confirmationRouterKitOnItsWay;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Self-install'**
  String get confirmationSelfInstall;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Follow the setup guide in the app'**
  String get confirmationFollowTheSetupGuideInThe;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Activation'**
  String get confirmationActivation;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Signal confirmed, service live'**
  String get confirmationSignalConfirmedServiceLive;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Pay {price} securely'**
  String paymentPaySecurely(String price);

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentPayment;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment. This can take a minute. Your order stays saved if you leave this screen.'**
  String get paymentConfirmingYourPaymentThisCanTake;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Choose how to pay on the secure payment page.'**
  String get paymentChooseHowToPayOnThe;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Pay on a secure payment page. We never see or store your card details.'**
  String get paymentPayOnASecurePaymentPage;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get paymentIdentityVerified;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'WiFi pass order'**
  String get paymentWifiPassOrder;

  /// Customer copy in payment page.
  ///
  /// In en, this message translates to:
  /// **'Your order'**
  String get paymentYourOrder;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'{product} is ready'**
  String voucherProductReady(String product);

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'{amount} GB has been added to your account.'**
  String voucherDataAdded(String amount);

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Too many tries'**
  String get voucherTooManyTries;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Wait a few minutes, then try again.'**
  String get voucherWaitAFewMinutesThenTry;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get voucherYouReOffline;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get voucherSomethingWentWrong;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. We could not confirm whether this voucher was used.'**
  String get voucherCheckYourConnectionAndTryAgain;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'We could not check this voucher. Please try again.'**
  String get voucherWeCouldNotCheckThisVoucher;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Voucher redeemed'**
  String get voucherVoucherRedeemed;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Data has been added to your account.'**
  String get voucherDataHasBeenAddedToYour;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Your pass is on your account. Find it under My passes.'**
  String get voucherYourPassIsOnYourAccount;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Already used'**
  String get voucherAlreadyUsed;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'This voucher has already been redeemed.'**
  String get voucherThisVoucherHasAlreadyBeenRedeemed;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Voucher expired'**
  String get voucherVoucherExpired;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'This voucher is no longer valid.'**
  String get voucherThisVoucherIsNoLongerValid;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'One character looks wrong'**
  String get voucherOneCharacterLooksWrong;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Compare the code with your voucher card, then try again.'**
  String get voucherCompareTheCodeWithYourVoucher;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Check the code'**
  String get voucherCheckTheCode;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Voucher codes never use 0, 1, I, L, O or U. Check those characters.'**
  String get voucherVoucherCodesNeverUse01;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Voucher codes have 12 letters and numbers.'**
  String get voucherVoucherCodesHave12LettersAnd;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Not a voucher code'**
  String get voucherNotAVoucherCode;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'Check the code on your voucher card and try again.'**
  String get voucherCheckTheCodeOnYourVoucher;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work'**
  String get voucherThatCodeDidnTWork;

  /// Customer copy in voucher result sheet.
  ///
  /// In en, this message translates to:
  /// **'It may be mistyped, already used or not active yet. Check it, or ask the shop.'**
  String get voucherItMayBeMistypedAlreadyUsed;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Scan voucher'**
  String get scanScanVoucher;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Align the voucher\'s QR code within the frame'**
  String get scanAlignTheVoucherSQrCode;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Type the code instead'**
  String get scanTypeTheCodeInstead;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Enter voucher code'**
  String get scanEnterVoucherCode;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'e.g. ABCD-2345-EFGH'**
  String get scanEGAbcd2345Efgh;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'12 letters and numbers, on your voucher card'**
  String get scan12LettersAndNumbersOnYour;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get scanPaste;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get scanRedeem;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Enable the camera in system settings, or type the code below.'**
  String get scanEnableTheCameraInSystemSettings;

  /// Customer copy in voucher scanner page.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Please type the code below.'**
  String get scanCameraUnavailablePleaseTypeTheCode;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad for 45 minutes of free WiFi. {remaining} of 3 free views left today.'**
  String freeWifiAdOffer(String remaining);

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String freeWifiTimeRemaining(String minutes, String seconds);

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Free WiFi'**
  String get freeWifiFreeWifi;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
  String get freeWifiWatchAd;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Hotspots'**
  String get freeWifiHotspots;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Free WiFi active'**
  String get freeWifiFreeWifiActive;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'TIME LEFT'**
  String get freeWifiTimeLeft;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'DATA LEFT'**
  String get freeWifiDataLeft;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Find hotspots near me'**
  String get freeWifiFindHotspotsNearMe;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all 3 free WiFi ads today. Come back tomorrow.'**
  String get freeWifiYouVeUsedAll3Free;

  /// Customer copy in free wifi card.
  ///
  /// In en, this message translates to:
  /// **'Updates from your account as you use it.'**
  String get freeWifiUpdatesFromYourAccountAsYou;

  /// Customer copy in watch ad dialog.
  ///
  /// In en, this message translates to:
  /// **'Your free WiFi ad is playing…'**
  String get freeWifiYourFreeWifiAdIsPlaying;

  /// Customer copy in watch ad dialog.
  ///
  /// In en, this message translates to:
  /// **'(simulated — no skip until it finishes)'**
  String get freeWifiSimulatedNoSkipUntilItFinishes;

  /// Customer copy in wifi hotspots page.
  ///
  /// In en, this message translates to:
  /// **'WiFi hotspots near you'**
  String get hotspotsWifiHotspotsNearYou;

  /// Customer copy in wifi hotspots page.
  ///
  /// In en, this message translates to:
  /// **'Enable location to see which hotspot is closest to you.'**
  String get hotspotsEnableLocationToSeeWhichHotspot;

  /// Customer copy in wifi hotspots page.
  ///
  /// In en, this message translates to:
  /// **'CLOSEST'**
  String get hotspotsClosest;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Current location ({latitude}, {longitude})'**
  String coverageCurrentLocation(String latitude, String longitude);

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Estimated speed: up to {speed} Mbps'**
  String coverageEstimatedSpeed(String speed);

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to use this.'**
  String get coverageTurnOnLocationServicesToUse;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied — enter your address manually.'**
  String get coverageLocationPermissionDeniedEnterYourAddress;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location — check that location services are on.'**
  String get coverageCouldNotGetYourLocationCheck;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Coverage check'**
  String get coverageCoverageCheck;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get coverageAddress;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get coverageUseMyCurrentLocation;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'View plans for this address'**
  String get coverageViewPlansForThisAddress;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Check a different address'**
  String get coverageCheckADifferentAddress;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Check this address'**
  String get coverageCheckThisAddress;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Not yet covered'**
  String get coverageNotYetCovered;

  /// Customer copy in coverage page.
  ///
  /// In en, this message translates to:
  /// **'Home internet is available here'**
  String get coverageHomeInternetIsAvailableHere;

  /// Identity verification privacy explanation.
  ///
  /// In en, this message translates to:
  /// **'Your face and ID information are used for verification only, under POPIA. You will be asked to confirm your consent before the check starts.'**
  String get ricaPrivacyNotice;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get ricaVerifyYourIdentity;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'Look at the camera and blink slowly…'**
  String get ricaLookAtTheCameraAndBlink;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'Ready to verify when you are.'**
  String get ricaReadyToVerifyWhenYouAre;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach our servers. Check your connection and try again.'**
  String get ricaWeCouldnTReachOurServers;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update your order. Try again in a moment.'**
  String get ricaWeCouldnTUpdateYourOrder;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your identity. Keep your face well lit and fully in the frame. Please try again. You haven\'t been charged.'**
  String get ricaWeCouldnTVerifyYourIdentity;

  /// Customer copy in promotions page.
  ///
  /// In en, this message translates to:
  /// **'{count} points'**
  String promotionsPoints(String count);

  /// Customer copy in promotions page.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String promotionsExpires(String date);

  /// Customer copy in promotions page.
  ///
  /// In en, this message translates to:
  /// **'Promotions & loyalty'**
  String get promotionsPromotionsLoyalty;

  /// Customer copy in promotions page.
  ///
  /// In en, this message translates to:
  /// **'Your Sentech loyalty balance'**
  String get promotionsYourSentechLoyaltyBalance;

  /// Customer copy in promotions page.
  ///
  /// In en, this message translates to:
  /// **'CURRENT OFFERS'**
  String get promotionsCurrentOffers;

  /// Customer copy in app router.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routerPageNotFound;

  /// Customer copy in app router.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get routerBackToHome;

  /// Customer copy in osm map.
  ///
  /// In en, this message translates to:
  /// **'Map data {attribution}'**
  String mapDataAttribution(String attribution);

  /// Customer copy in payment web view page.
  ///
  /// In en, this message translates to:
  /// **'Close payment'**
  String get paymentClosePayment;

  /// Customer copy in payment web view page.
  ///
  /// In en, this message translates to:
  /// **'Secure payment'**
  String get paymentSecurePayment;

  /// Customer copy in fake gateway sheet.
  ///
  /// In en, this message translates to:
  /// **'No money moves. This simulates payment for {price}.'**
  String paymentTestExplanation(String price);

  /// Customer copy in fake gateway sheet.
  ///
  /// In en, this message translates to:
  /// **'Test payment (local stack)'**
  String get paymentTestPaymentLocalStack;

  /// Customer copy in fake gateway sheet.
  ///
  /// In en, this message translates to:
  /// **'Approve test payment'**
  String get paymentApproveTestPayment;

  /// Customer copy in fake gateway sheet.
  ///
  /// In en, this message translates to:
  /// **'Decline test payment'**
  String get paymentDeclineTestPayment;

  /// Customer copy in boot video screen.
  ///
  /// In en, this message translates to:
  /// **'Sentech Connect is starting'**
  String get bootSentechConnectIsStarting;

  /// Customer copy in boot video screen.
  ///
  /// In en, this message translates to:
  /// **'Skip intro'**
  String get bootSkipIntro;

  /// Customer copy in boot video screen.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get bootSkip;

  /// Customer copy in failure view.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get failureYouReOfflineCheckYourConnection;

  /// Customer copy in failure view.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureSomethingWentWrongPleaseTryAgain;

  /// Shop category.
  ///
  /// In en, this message translates to:
  /// **'Home 5G'**
  String get productCategoryHome5g;

  /// Shop category.
  ///
  /// In en, this message translates to:
  /// **'MiFi'**
  String get productCategoryMifi;

  /// Shop category.
  ///
  /// In en, this message translates to:
  /// **'Vouchers'**
  String get productCategoryVoucher;

  /// Shop category.
  ///
  /// In en, this message translates to:
  /// **'WiFi passes'**
  String get productCategoryHotspotPass;

  /// Startup failure; must work before services initialize.
  ///
  /// In en, this message translates to:
  /// **'App configuration error — please reinstall or contact support'**
  String get startupErrorMessage;

  /// Language name shown in its own language (autonym).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language name shown in its own language (autonym).
  ///
  /// In en, this message translates to:
  /// **'isiZulu'**
  String get languageZulu;

  /// Language name shown in its own language (autonym).
  ///
  /// In en, this message translates to:
  /// **'Afrikaans'**
  String get languageAfrikaans;

  /// Hotspot distance in meters.
  ///
  /// In en, this message translates to:
  /// **'{distance} m away'**
  String hotspotMetersAway(String distance);

  /// Hotspot distance in kilometers.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String hotspotKilometersAway(String distance);

  /// Demo FAQ question.
  ///
  /// In en, this message translates to:
  /// **'Why is my speed slower than expected?'**
  String get demoFaq1Question;

  /// Demo FAQ answer; not a promise of configured payment methods.
  ///
  /// In en, this message translates to:
  /// **'Speed may drop from 6–10pm, when more people use the network. Thick walls and nearby electronics can also slow your connection. Move your router to an open, central spot. If that does not help, report the issue below.'**
  String get demoFaq1Answer;

  /// Demo FAQ question.
  ///
  /// In en, this message translates to:
  /// **'How do I top up my data?'**
  String get demoFaq2Question;

  /// Demo FAQ answer; not a promise of configured payment methods.
  ///
  /// In en, this message translates to:
  /// **'Open Shop and choose a top-up or voucher. Pay by card, Ozow, or PayShap. Top-ups reach your account within a few minutes.'**
  String get demoFaq2Answer;

  /// Demo FAQ question.
  ///
  /// In en, this message translates to:
  /// **'My router lights are red'**
  String get demoFaq3Question;

  /// Demo FAQ answer; not a promise of configured payment methods.
  ///
  /// In en, this message translates to:
  /// **'A solid red light usually means a signal or power problem. Check that the power cable is firmly plugged in. Wait 2 minutes for your router to reconnect. If it stays red, report the issue below.'**
  String get demoFaq3Answer;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'Upgrade and save'**
  String get demoPromotion1Title;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'Switch to Home 100 this month. Get 20% off your first month.'**
  String get demoPromotion1Description;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'20% OFF'**
  String get demoPromotion1Badge;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'Refer a friend'**
  String get demoPromotion2Title;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'Give a friend a free installation — you both get 10GB bonus data.'**
  String get demoPromotion2Description;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'REFERRAL'**
  String get demoPromotion2Badge;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'Loyalty reward'**
  String get demoPromotion3Title;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'You\'ve earned enough points for a free Wi-Fi voucher. Redeem it in Vouchers.'**
  String get demoPromotion3Description;

  /// Demo promotional copy; available in demo only.
  ///
  /// In en, this message translates to:
  /// **'LOYALTY'**
  String get demoPromotion3Badge;

  /// Pre-filled WhatsApp message.
  ///
  /// In en, this message translates to:
  /// **'Hi Sentech, I need help with my account.'**
  String get supportChatGreeting;

  /// Support email subject.
  ///
  /// In en, this message translates to:
  /// **'[{category}] Support request'**
  String supportEmailSubject(String category);

  /// Demo offers shortcut; credits are not implemented.
  ///
  /// In en, this message translates to:
  /// **'See current offers'**
  String get homePromotionsLabel;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'Next we verify your identity (required by RICA). You are only charged after that succeeds.'**
  String get checkoutIdentityNotice;

  /// Customer copy in checkout page.
  ///
  /// In en, this message translates to:
  /// **'Pay on a secure payment page. Your pass starts when payment is confirmed.'**
  String get checkoutPaymentNotice;

  /// Customer copy in rica page.
  ///
  /// In en, this message translates to:
  /// **'Required by South African law (RICA) before we can activate your service.'**
  String get ricaLawNotice;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get confirmationReady;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'Your WiFi pass is paid'**
  String get confirmationPassPaid;

  /// Customer copy in confirmation page.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set. Connect at a WiFi hotspot to start.'**
  String get confirmationConnectHint;

  /// Customer copy in osm map.
  ///
  /// In en, this message translates to:
  /// **'Map not available.'**
  String get mapUnavailable;

  /// Customer copy in connectivity cubit.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Some things won\'t work until you reconnect.'**
  String get offlineBanner;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get failureNoInternetConnection;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end.'**
  String get failureSomethingWentWrongOnOurEnd;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'This address is not yet in our coverage area.'**
  String get failureThisAddressIsNotYetInOur;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not finish signing you in. Please try again.'**
  String get failureWeCouldNotFinishSigningYouIn;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again.'**
  String get failureYourSessionHasEndedSignInAgain;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Your internet service is currently unavailable.'**
  String get failureThisProviderIsCurrentlyUnavailable;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'This is not offered by your provider.'**
  String get failureNotOfferedByProvider;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Buy this from your provider directly.'**
  String get failureBuyFromProviderDirectly;

  /// Shown instead of a Pay button when the provider collects its own payments. The provider name is data sent by the server.
  ///
  /// In en, this message translates to:
  /// **'Buy this from {provider} directly.'**
  String paymentBuyFromProvider(String provider);

  /// Heading above the provider's support email and phone buttons.
  ///
  /// In en, this message translates to:
  /// **'Contact {provider}.'**
  String paymentContactProvider(String provider);

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not find that.'**
  String get failureWeCouldNotFindThat;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get failureTooManyAttemptsPleaseWaitAndTry;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We received an unexpected response. Please try again.'**
  String get failureWeReceivedAnUnexpectedResponsePleaseTry;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get failureTheRequestWasCancelled;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not make a secure connection. Check your network and try again.'**
  String get failureWeCouldNotMakeASecureConnection;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Blocked a request to an unexpected address.'**
  String get failureBlockedARequestToAnUnexpectedAddress;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid South African mobile number.'**
  String get failureEnterAValidSouthAfricanMobileNumber;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code.'**
  String get failureEnterThe6DigitCode;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Could not save your details on this device.'**
  String get failureCouldNotSaveYourDetailsOnThis;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Could not read your saved details.'**
  String get failureCouldNotReadYourSavedDetails;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'The code is invalid or has expired.'**
  String get failureTheCodeIsInvalidOrHasExpired;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Your session could not be verified. Sign in again.'**
  String get failureYourSessionCouldNotBeVerifiedSign;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not load the complete catalogue. Please try again.'**
  String get failureWeCouldNotLoadTheCompleteCatalogue;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty.'**
  String get failureYourCartIsEmpty;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not load your open order. Please try again.'**
  String get failureWeCouldNotLoadYourOpenOrder;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Identity checks are not needed for this order.'**
  String get failureIdentityChecksAreNotNeededForThis;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not find that order.'**
  String get failureWeCouldNotFindThatOrder;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'A newer order replaced this one. You can no longer pay for this order.'**
  String get failureThisOrderWasReplacedByANewer;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'This order can no longer be paid.'**
  String get failureThisOrderCanNoLongerBePaid;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity before paying.'**
  String get failureVerifyYourIdentityBeforePaying;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'The payment was not completed. You have not been charged.'**
  String get failureThePaymentWasNotCompletedYouHave;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not open the payment page safely.'**
  String get failureWeCouldNotOpenThePaymentPage;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not load all of your passes. Please try again.'**
  String get failureWeCouldNotLoadAllOfYour;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not load the legal documents. Try again.'**
  String get failureWeCouldNotLoadTheLegalDocuments;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Could not save your consent on this device.'**
  String get failureCouldNotSaveYourConsentOnThis;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Could not save your choice on this device.'**
  String get failureCouldNotSaveYourChoiceOnThis;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'We could not find your internet service.'**
  String get failureUnknownProvider;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s date or time looks wrong. Set it to automatic and try again.'**
  String get failureYourPhoneSDateOrTimeLooks;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'You already have a free WiFi session running.'**
  String get failureYouAlreadyHaveAFreeWifiSession;

  /// Customer error matching an internal failure message; external details remain data.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s free WiFi limit.'**
  String get failureYouVeReachedTodaySFreeWifi;

  /// Permission failure when the server sends no customer-facing detail.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that.'**
  String get failureNotAllowed;

  /// Preferred contact method label in registration.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactMethodEmail;

  /// Preferred contact method label in registration.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get contactMethodSms;

  /// Fallback above a list sorted by known customer distance.
  ///
  /// In en, this message translates to:
  /// **'Map not available. Here are the nearest spots.'**
  String get mapUnavailableNearestSpots;

  /// Fallback above a hotspot list when customer location is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Map not available. Here are the WiFi spots.'**
  String get mapUnavailableWifiSpots;

  /// Greeting for an unknown or signed-out customer.
  ///
  /// In en, this message translates to:
  /// **'Hello!'**
  String get loginTitleNew;

  /// Explicitly read the clipboard for the SMS verification code.
  ///
  /// In en, this message translates to:
  /// **'Paste code'**
  String get otpPasteCode;

  /// Inline error for ambiguous, empty or overlong pasted verification text.
  ///
  /// In en, this message translates to:
  /// **'Paste only the 6-digit code.'**
  String get otpPasteOnlyCode;

  /// Honest disclosure when legal consent text uses the English fallback.
  ///
  /// In en, this message translates to:
  /// **'This text is only in English for now.'**
  String get legalBodyLanguageNote;

  /// Opens the configured public tenant Terms document.
  ///
  /// In en, this message translates to:
  /// **'Read the Terms'**
  String get consentTermsLink;

  /// Shown when the tenant has no valid public Terms URL.
  ///
  /// In en, this message translates to:
  /// **'Terms link is unavailable. Please try again later.'**
  String get consentTermsUnavailable;

  /// A legal document could not be opened externally.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link. Please try again.'**
  String get legalLinkOpenFailed;

  /// Link text to the provider's public complaints procedure.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get legalComplaints;

  /// Link text to the provider's PAIA (access to information) manual.
  ///
  /// In en, this message translates to:
  /// **'PAIA manual'**
  String get legalPaia;

  /// Link text to the provider's cooling-off rights information.
  ///
  /// In en, this message translates to:
  /// **'Cooling-off rights'**
  String get legalCoolingOff;

  /// Link text to the provider's service charter.
  ///
  /// In en, this message translates to:
  /// **'Service charter'**
  String get legalServiceCharter;

  /// Plain first-run instruction above the mobile number field.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get loginEnterPhone;

  /// Paid pass title using the plan from the loaded order.
  ///
  /// In en, this message translates to:
  /// **'{plan} is ready'**
  String passReadyTitle(String plan);

  /// Connect heading when no verified network name is available.
  ///
  /// In en, this message translates to:
  /// **'Connect to WiFi'**
  String get passReadyConnect;

  /// Connect heading for a verified WiFi network name.
  ///
  /// In en, this message translates to:
  /// **'Connect to {network}'**
  String passReadyConnectNamed(String network);

  /// First step to use a paid WiFi pass.
  ///
  /// In en, this message translates to:
  /// **'Turn on WiFi'**
  String get passReadyTurnOnWifi;

  /// Generic second step; no network name is known.
  ///
  /// In en, this message translates to:
  /// **'Choose the hotspot WiFi network'**
  String get passReadyChooseNetwork;

  /// Second step using a verified WiFi network name.
  ///
  /// In en, this message translates to:
  /// **'Choose {network}'**
  String passReadyChooseNamed(String network);

  /// Third step to reach the hotspot sign-in page.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page opens. If not, open any website.'**
  String get passReadySignInStep;

  /// Leave the pass-ready screen.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get passReadyDone;

  /// Open the hotspot finder, only when available.
  ///
  /// In en, this message translates to:
  /// **'Find WiFi near me'**
  String get passReadyFindWifi;

  /// Paid total and reference from the loaded order.
  ///
  /// In en, this message translates to:
  /// **'{price} incl. VAT · Order #{orderNumber}'**
  String passReadyOrderDetail(String price, String orderNumber);

  /// Action to reopen voucher entry and correct the code during this flow.
  ///
  /// In en, this message translates to:
  /// **'Check the code'**
  String get commonCheckCode;

  /// Manual voucher entry helper; display prefixes and demo formats also exist.
  ///
  /// In en, this message translates to:
  /// **'Enter the code printed on your voucher card.'**
  String get scanVoucherCodeHelper;

  /// Data allowance of an actual pass without a data cap.
  ///
  /// In en, this message translates to:
  /// **'Uncapped data'**
  String get voucherUncappedData;

  /// Actual voucher pass data allowance in megabytes; do not round it.
  ///
  /// In en, this message translates to:
  /// **'{amount} MB'**
  String voucherDataMb(int amount);

  /// Actual voucher pass allowance, duration in minutes and maximum device count.
  ///
  /// In en, this message translates to:
  /// **'{data} · {minutes} min · Devices: {devices}'**
  String voucherPassDetail(String data, int minutes, int devices);

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get promotionsTitle;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'No offers right now'**
  String get promotionsEmpty;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'Offers are unavailable. Try again later.'**
  String get promotionsUnavailable;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get promotionsOngoing;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'I can\'t connect to the WiFi'**
  String get hotspotFaq1Question;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'Connect to the hotspot. Open a website starting with http://. This opens the sign-in page. If needed, turn off your VPN or private DNS. Try again.'**
  String get hotspotFaq1Answer;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'I paid but have no pass'**
  String get hotspotFaq2Question;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'Wait 1 minute for payment confirmation. Check your orders and receipts. If money left your account, contact support with your order reference.'**
  String get hotspotFaq2Answer;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'My hotspot connection is slow'**
  String get hotspotFaq3Question;

  /// Task 10 owned offers and hotspot help copy.
  ///
  /// In en, this message translates to:
  /// **'Move closer to the hotspot. Disconnect and reconnect to WiFi. If it stays slow, contact support.'**
  String get hotspotFaq3Answer;

  /// Action on a pass or voucher catalog card.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get buyNow;

  /// Retry creating an unpaid order in the Buy now sheet.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get buyNowTryAgain;

  /// Static progress text for Buy now when motion is reduced.
  ///
  /// In en, this message translates to:
  /// **'Creating order'**
  String get buyNowCreatingOrder;

  /// Heading for actual plan details in the Buy now sheet.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get buyNowWhatYouGet;

  /// Maximum plan speed shown when catalog supplies it.
  ///
  /// In en, this message translates to:
  /// **'Up to {speed} Mbps'**
  String buyNowSpeed(String speed);

  /// Action to create an unpaid order and continue to payment. Price includes VAT.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String buyNowPay(String price);

  /// Heading for illustrative demo payment methods.
  ///
  /// In en, this message translates to:
  /// **'Ways to pay'**
  String get paymentMethodsHeading;

  /// Illustrative demo payment method label.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// Illustrative demo payment method label.
  ///
  /// In en, this message translates to:
  /// **'Instant EFT'**
  String get paymentMethodInstantEft;

  /// Illustrative demo payment method, shown only with the voucher offering.
  ///
  /// In en, this message translates to:
  /// **'Cash voucher'**
  String get paymentMethodCashVoucher;

  /// Editorial recommendation; no popularity claim.
  ///
  /// In en, this message translates to:
  /// **'Selected by us for you'**
  String get planBadgeOurPickHint;

  /// Status label of a pass whose service the provider has paused (status suspended). Not expired: it can come back.
  ///
  /// In en, this message translates to:
  /// **'Service suspended'**
  String get passesStatusSuspended;

  /// Shown on the code step. Other people may hold codes for the same number, so the customer picks the SMS that says Code ref followed by these four characters.
  ///
  /// In en, this message translates to:
  /// **'Use the SMS that shows reference {reference}.'**
  String otpUseSmsReference(String reference);

  /// Customer error for 422 binding_required: the platform wants the sign-in binding that this build did not send, so the app must be updated.
  ///
  /// In en, this message translates to:
  /// **'Sign-in could not be completed. Please update the app and try again.'**
  String get failureBindingRequired;

  /// Customer error for 403 human_verification_failed: the human check (Turnstile) token was missing, wrong or expired.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm that you are a person. Please try again.'**
  String get failureHumanVerificationFailed;

  /// Customer error for 503 human_verification_unavailable when the server gave no wait time. Nobody can request a code until the check provider is back.
  ///
  /// In en, this message translates to:
  /// **'The security check is not available right now. Please try again in a moment.'**
  String get failureHumanVerificationUnavailable;

  /// Same as the previous message with the Retry-After wait of the server, under two minutes.
  ///
  /// In en, this message translates to:
  /// **'The security check is not available right now. Please try again in {seconds} seconds.'**
  String failureHumanVerificationUnavailableSeconds(int seconds);

  /// Same as the previous message with the Retry-After wait of the server, two minutes or more (rounded up).
  ///
  /// In en, this message translates to:
  /// **'The security check is not available right now. Please try again in {minutes} minutes.'**
  String failureHumanVerificationUnavailableMinutes(int minutes);

  /// Customer error for 403 reauth_required: the fresh code for deleting the account was wrong, used or expired. Nothing was deleted.
  ///
  /// In en, this message translates to:
  /// **'That code did not work. Check it and try again.'**
  String get failureReauthRequired;

  /// Customer error for 503 sms_unavailable: the one-time code could not be sent by SMS right now.
  ///
  /// In en, this message translates to:
  /// **'We could not send the SMS. Please try again in a moment.'**
  String get failureSmsUnavailable;

  /// Customer error for 422 consent_version_outdated: the terms or privacy version the app sent is not the current one.
  ///
  /// In en, this message translates to:
  /// **'The terms were updated. Please review and accept the latest version.'**
  String get failureConsentVersionOutdated;

  /// Customer error for 404 subscriber_not_found: the customer has no subscriber record with this provider yet.
  ///
  /// In en, this message translates to:
  /// **'We could not find a service account for you with this provider.'**
  String get failureSubscriberNotFound;

  /// Customer error for 409 active_service_exists: deleting the account (or signing up again) is refused while a service is active.
  ///
  /// In en, this message translates to:
  /// **'You still have an active service. Cancel it first, or contact your provider.'**
  String get failureActiveServiceExists;

  /// Customer error when the delete-account code cannot be sent (401 from delete-challenge: no phone number on the account). The customer stays signed in.
  ///
  /// In en, this message translates to:
  /// **'We cannot send a code to this account. Contact support to delete your account.'**
  String get failureDeleteContactSupport;

  /// Button on the first delete-account step: asks the platform to SMS a 6-digit code to the number on the account.
  ///
  /// In en, this message translates to:
  /// **'Send me a code'**
  String get accountDeleteSendCode;

  /// Title of the second delete-account step.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent you'**
  String get accountDeleteCodeTitle;

  /// Body of the second delete-account step: why a code is asked for and that deleting cannot be undone.
  ///
  /// In en, this message translates to:
  /// **'For your safety we sent a 6-digit code by SMS to the number on your account. Enter it to delete your account and all your data. This cannot be undone.'**
  String get accountDeleteCodeBody;

  /// Closes the delete-account dialog when nothing more can be done there (for example contact support).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get accountDeleteClose;

  /// Shown on a pass whose status is suspended (the provider paused the service, for example an unpaid invoice). Not an expiry; there is no countdown.
  ///
  /// In en, this message translates to:
  /// **'Your provider has paused this service. Contact them to get it back.'**
  String get passesSuspendedNote;

  /// Title of the sheet that asks the customer to pass the human check (Turnstile) before an SMS code is sent.
  ///
  /// In en, this message translates to:
  /// **'Quick check: confirm you are a person'**
  String get humanCheckTitle;

  /// Why the human check exists, shown under the title.
  ///
  /// In en, this message translates to:
  /// **'This keeps automated sign-ups out. It usually takes a second.'**
  String get humanCheckBody;

  /// Status while the human check widget loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the check…'**
  String get humanCheckLoading;

  /// Status when the widget needs the customer to tick or solve something.
  ///
  /// In en, this message translates to:
  /// **'Please complete the check below.'**
  String get humanCheckChallenge;

  /// Shown when the human check page could not load (no network, blocked).
  ///
  /// In en, this message translates to:
  /// **'We could not load the check. Check your connection and try again.'**
  String get humanCheckFailedNetwork;

  /// Shown when the human check widget reported an error after quiet retries.
  ///
  /// In en, this message translates to:
  /// **'The check did not work this time. Please try again.'**
  String get humanCheckFailedWidget;

  /// Shown when the human check took too long or expired.
  ///
  /// In en, this message translates to:
  /// **'The check took too long. Please try again.'**
  String get humanCheckFailedTimeout;

  /// Button that starts the human check again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get humanCheckRetry;

  /// Button that closes the human check without finishing it.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get humanCheckCancel;

  /// Accessibility label of the embedded human check widget.
  ///
  /// In en, this message translates to:
  /// **'Security check'**
  String get humanCheckWidgetLabel;

  /// Shown with a failed human check: a way out that does not need the check.
  ///
  /// In en, this message translates to:
  /// **'Still stuck? Cancel and sign in on the website, or contact support.'**
  String get humanCheckHelp;

  /// Customer error for problem code feature_disabled.
  ///
  /// In en, this message translates to:
  /// **'This is not available from your provider.'**
  String get failureFeatureDisabled;

  /// Customer error for problem code order_not_cancellable.
  ///
  /// In en, this message translates to:
  /// **'This order can no longer be cancelled.'**
  String get failureOrderNotCancellable;

  /// Customer error for problem code order_cancelled.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled.'**
  String get failureOrderCancelled;

  /// Customer error for problem code support_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Support messages are not available right now. Please try again later.'**
  String get failureSupportUnavailable;

  /// Customer error for problem code support_contact_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Your provider has not set up support messages yet.'**
  String get failureSupportContactNotConfigured;

  /// Customer error for problem code invalid_message.
  ///
  /// In en, this message translates to:
  /// **'Check your message and try again.'**
  String get failureInvalidMessage;

  /// Customer error for problem code invalid_contact.
  ///
  /// In en, this message translates to:
  /// **'Check your contact details and try again.'**
  String get failureInvalidContact;

  /// Customer error for problem code invoice_not_payable.
  ///
  /// In en, this message translates to:
  /// **'This invoice can no longer be paid.'**
  String get failureInvoiceNotPayable;

  /// Customer error for problem code customer_link_required.
  ///
  /// In en, this message translates to:
  /// **'Your account is not linked to your provider yet. Contact your provider.'**
  String get failureCustomerLinkRequired;

  /// Customer error for problem code subscriber_profile_invalid.
  ///
  /// In en, this message translates to:
  /// **'Update your contact details before signing up.'**
  String get failureSubscriberProfileInvalid;

  /// Customer error for problem code no_active_entitlement.
  ///
  /// In en, this message translates to:
  /// **'You need an active pass to get online.'**
  String get failureNoActiveEntitlement;

  /// Customer error for problem code mac_invalid.
  ///
  /// In en, this message translates to:
  /// **'We could not identify this device. Connect from the Wi-Fi login page instead.'**
  String get failureMacInvalid;

  /// Customer error for problem code nas_unavailable.
  ///
  /// In en, this message translates to:
  /// **'This hotspot is not available right now. Try another one.'**
  String get failureNasUnavailable;

  /// Customer error for problem code login_url_invalid.
  ///
  /// In en, this message translates to:
  /// **'This hotspot login could not be opened. Connect from the Wi-Fi login page instead.'**
  String get failureLoginUrlInvalid;

  /// Customer error for problem code controller_not_supported.
  ///
  /// In en, this message translates to:
  /// **'One-tap login is not supported at this hotspot. Connect from the Wi-Fi login page instead.'**
  String get failureControllerNotSupported;
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
