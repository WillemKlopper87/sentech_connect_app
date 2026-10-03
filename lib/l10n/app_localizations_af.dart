// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Afrikaans (`af`).
class AppLocalizationsAf extends AppLocalizations {
  AppLocalizationsAf([String locale = 'af']) : super(locale);

  @override
  String get commonCancel => 'Kanselleer';

  @override
  String get commonContinue => 'Gaan voort';

  @override
  String get commonRetry => 'Probeer weer';

  @override
  String get commonDone => 'Klaar';

  @override
  String get loginWelcomeBack => 'Welkom terug';

  @override
  String get loginSubtitle => 'Teken in om jou verbinding te bestuur';

  @override
  String get loginUseBiometrics => 'Gebruik biometrie';

  @override
  String get loginOr => 'of';

  @override
  String get loginMobileHint => 'Selfoonnommer';

  @override
  String get biometricPromptReason =>
      'Bevestig dat dit jy is om by Sentech Connect in te teken';

  @override
  String get biometricNotEnrolled =>
      'Geen vingerafdruk of gesig is op hierdie foon opgestel nie. Voeg een in die stelselinstellings by.';

  @override
  String get biometricUnavailable => 'Biometrie is tans nie beskikbaar nie.';

  @override
  String get biometricLockedOut =>
      'Te veel pogings. Wag \'n oomblik en probeer weer.';

  @override
  String get biometricPermanentlyLockedOut =>
      'Biometrie is gesluit. Ontsluit eers jou foon met jou PIN of patroon.';

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
  String get signedOutProviderUnavailable =>
      'Your provider is currently unavailable, so you have been signed out. Please try again later.';

  @override
  String get biometricFailed =>
      'Biometriese kontrole het misluk. Probeer weer.';

  @override
  String get registerTitle => 'Skep \'n rekening';

  @override
  String get registerPersonalDetails => 'PERSOONLIKE BESONDERHEDE';

  @override
  String get registerFullName => 'Volle naam';

  @override
  String get registerEmail => 'E-posadres';

  @override
  String get registerMobile => 'Selfoonnommer';

  @override
  String get registerInstallationAddress => 'INSTALLASIE-ADRES';

  @override
  String get registerAddressHint => 'Straatadres, voorstad, stad';

  @override
  String get registerLocationCaptured => 'Ligging vasgelê';

  @override
  String get registerUseLocation => 'Gebruik my huidige ligging';

  @override
  String get registerLocationHelp =>
      'Vernou jou dekkingskontrole tot jou presiese ligging — jy kan steeds die adres hierbo wysig.';

  @override
  String get registerContactHeading => 'HOE MOET ONS JOU KONTAK?';

  @override
  String get registerMarketingHeading => 'BEMARKINGSVOORKEURE';

  @override
  String get registerMarketingEmail => 'Stuur my aanbiedinge per e-pos';

  @override
  String get registerMarketingSms => 'Stuur my aanbiedinge per SMS';

  @override
  String get registerMarketingPush => 'Stuur my stootkennisgewings';

  @override
  String get registerCreateAccount => 'Skep rekening';

  @override
  String get registerSaveFailed =>
      'Kon nie jou besonderhede stoor nie — probeer asseblief weer.';

  @override
  String get registerLocationDenied =>
      'Liggingtoestemming geweier — voer jou adres handmatig in.';

  @override
  String get registerLocationFailed =>
      'Kon nie jou ligging kry nie — maak seker liggingdienste is aan.';

  @override
  String get accountTitle => 'Rekening';

  @override
  String get accountNotLoggedIn => 'Nie ingeteken nie';

  @override
  String get accountAppearance => 'UITSIG';

  @override
  String get accountThemeSystem => 'Volg toestelinstelling';

  @override
  String get accountThemeLight => 'Lig';

  @override
  String get accountThemeDark => 'Donker';

  @override
  String get accountLanguage => 'TAAL';

  @override
  String get accountLanguageSystem => 'Volg toesteltaal';

  @override
  String get accountLogOut => 'Teken uit';

  @override
  String get accountLogOutTitle => 'Teken uit?';

  @override
  String get accountLogOutBody => 'Jy kan enige tyd weer inteken.';

  @override
  String get accountNotifications => 'KENNISGEWINGS';

  @override
  String get accountPushTitle => 'Stootkennisgewings';

  @override
  String get accountPushOn =>
      'Aan — gebruikswaarskuwings, onderbrekings en bestellingopdaterings';

  @override
  String get accountPushOff =>
      'Af — skakel aan vir gebruikswaarskuwings, onderbrekings en bestellingopdaterings';

  @override
  String get accountPushBlocked =>
      'Geblokkeer — verander dit in die stelselinstellings';

  @override
  String get accountPushTurnOn => 'Skakel aan';

  @override
  String get accountPushOpenSettings => 'Maak instellings oop';

  @override
  String get accountPrivacy => 'PRIVAATHEID EN DATA';

  @override
  String get accountPrivacyPolicy => 'Privaatheidsbeleid';

  @override
  String get accountDownloadData => 'Laai my data af';

  @override
  String get accountDownloadDataDone =>
      'Versoek ontvang. Ons stuur jou data na jou e-pos sodra dit gereed is.';

  @override
  String get accountDeleteData => 'Vee my rekening en data uit';

  @override
  String get accountDeleteTitle => 'Vee jou rekening uit?';

  @override
  String get accountDeleteBody =>
      'Dit vee jou Sentech-rekening en alle persoonlike data op hierdie foon permanent uit. Dit kan nie ongedaan gemaak word nie.';

  @override
  String get accountDeleteConfirm => 'Vee alles uit';

  @override
  String get accountRequestFailed =>
      'Ons kon nie daardie versoek voltooi nie. Probeer asseblief weer.';

  @override
  String get accountLinkFailed => 'Kon nie die skakel oopmaak nie.';

  @override
  String get supportTitle => 'Hulp en ondersteuning';

  @override
  String get supportSearchHint => 'Soek gereelde vrae';

  @override
  String supportNoResults(String query) {
    return 'Geen resultate vir \"$query\"';
  }

  @override
  String get supportStillStuck => 'STEEDS VASGEKEER?';

  @override
  String get supportWhatsApp => 'WhatsApp';

  @override
  String get supportSubmitTicket => 'Dien \'n kaartjie in';

  @override
  String get supportTicketCategory => 'Kategorie';

  @override
  String get supportTicketDescribe => 'Beskryf die probleem';

  @override
  String get supportCategoryBilling => 'Fakturering';

  @override
  String get supportCategoryTechnical => 'Tegnies';

  @override
  String get supportCategoryOther => 'Ander';

  @override
  String get supportWhatsAppFailed =>
      'Kon nie WhatsApp oopmaak nie — is dit geïnstalleer?';

  @override
  String get supportTicketOpened =>
      'Kaartjie in jou e-pos-toepassing oopgemaak — stuur dit om in te dien.';

  @override
  String get supportTicketNoEmail =>
      'Kon nie \'n e-pos-toepassing op hierdie toestel oopmaak nie.';

  @override
  String get consentTitle => 'Jou privaatheid';

  @override
  String get consentLocationBody =>
      'Ons gebruik jou foon se ligging een keer om 5G-dekking by jou adres te kontroleer. Dit word nie op jou foon gestoor of ná die kontrole behou nie.';

  @override
  String get consentLocationMapService =>
      'To turn your location into an address, your phone\'s map service (Google or Apple) looks it up.';

  @override
  String get coverageAddressLookupNotice =>
      'Your phone\'s map service (Google or Apple) finds the address you type.';

  @override
  String get consentRicaBody =>
      'Suid-Afrikaanse wetgewing (RICA) vereis dat ons jou identiteit verifieer. Ons verwerk jou gesig- en ID-inligting slegs vir verifikasie, ingevolge POPIA.';

  @override
  String get consentLegalBody =>
      'To use the app you need to accept the Terms of Service and the Privacy notice.';

  @override
  String get dataExportTitle => 'Your data';

  @override
  String get dataExportBody =>
      'This is the personal information we hold about you. Keep it private.';

  @override
  String get consentPolicyLink => 'Lees ons privaatheidsbeleid';

  @override
  String get consentAgree => 'Ek stem in';

  @override
  String get consentDecline => 'Nie nou nie';

  @override
  String get notifRationaleTitle => 'Bly op hoogte';

  @override
  String get notifRationaleBody =>
      'Laat kennisgewings toe sodat ons jou kan sê wanneer jou data laag raak, wanneer daar \'n onderbreking in jou area is, en wanneer jou bestelling vorder. Jy kan dit enige tyd afskakel.';

  @override
  String get notifRationaleAllow => 'Laat kennisgewings toe';

  @override
  String get notifRationaleLater => 'Nie nou nie';

  @override
  String get a11yCart => 'Inkopiemandjie';

  @override
  String get a11yDecreaseQuantity => 'Verminder hoeveelheid';

  @override
  String get a11yIncreaseQuantity => 'Verhoog hoeveelheid';

  @override
  String get a11yToggleTorch => 'Skakel flitslig aan of af';

  @override
  String get a11yEnterCode => 'Voer kode handmatig in';

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

  @override
  String get passesTitle => 'My passes';

  @override
  String get passesEmpty => 'You have no active passes. Buy one in Shop.';

  @override
  String get passesShowExpired => 'Show expired passes';

  @override
  String get passesStatusActive => 'Active';

  @override
  String get passesStatusScheduled => 'Starts later';

  @override
  String get passesStatusExpired => 'Expired';

  @override
  String get passesStatusExhausted => 'Used up';

  @override
  String get passesStatusRevoked => 'Cancelled';

  @override
  String passesExpires(String date) {
    return 'Expires $date';
  }

  @override
  String passesStarts(String date) {
    return 'Starts $date';
  }

  @override
  String passesDevices(int count) {
    return 'Up to $count devices';
  }

  @override
  String get dashboardMyPasses => 'My passes';

  @override
  String get dashboardBuyPass => 'Buy a pass';

  @override
  String get dashboardNoPass => 'No active pass';

  @override
  String get dashboardNoPassHint => 'Buy a Wi-Fi pass to get online.';

  @override
  String dashboardTimeLeft(String time) {
    return '$time left';
  }

  @override
  String dashboardDataLeft(String left, String total) {
    return '$left of $total left';
  }

  @override
  String get dashboardUncapped => 'Uncapped data';

  @override
  String get confirmationViewPasses => 'View my passes';

  @override
  String passesExpiredAt(String date) {
    return 'Expired $date';
  }

  @override
  String passesEndedAt(String date) {
    return 'Ended $date';
  }

  @override
  String get passesJustPaidHint =>
      'Just paid? It can take a minute to appear. Pull down to refresh.';

  @override
  String durationDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String sizeMegabytes(String amount) {
    return '$amount MB';
  }

  @override
  String sizeGigabytes(String amount) {
    return '$amount GB';
  }

  @override
  String get dashboardTopUp => 'Top up';

  @override
  String get dashboardUpgrade => 'Upgrade';

  @override
  String get dashboardReportIssue => 'Report issue';
}
