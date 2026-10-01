// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Zulu (`zu`).
class AppLocalizationsZu extends AppLocalizations {
  AppLocalizationsZu([String locale = 'zu']) : super(locale);

  @override
  String get commonCancel => 'Khansela';

  @override
  String get commonContinue => 'Qhubeka';

  @override
  String get commonRetry => 'Zama futhi';

  @override
  String get commonDone => 'Kwenziwe';

  @override
  String get loginWelcomeBack => 'Siyakwamukela futhi';

  @override
  String get loginSubtitle => 'Ngena ukuze uphathe uxhumo lwakho';

  @override
  String get loginUseBiometrics => 'Sebenzisa i-biometrics';

  @override
  String get loginOr => 'noma';

  @override
  String get loginMobileHint => 'Inombolo yocingo';

  @override
  String get biometricPromptReason =>
      'Qinisekisa ukuthi ungowakho ukuze ungene ku-Sentech Connect';

  @override
  String get biometricNotEnrolled =>
      'Akukho isigxivizo somunwe noma ubuso obusethiwe kule foni. Engeza okukodwa kumasethingi esistimu.';

  @override
  String get biometricUnavailable => 'I-biometrics ayitholakali okwamanje.';

  @override
  String get biometricLockedOut =>
      'Imizamo eminingi kakhulu. Linda isikhashana bese uzama futhi.';

  @override
  String get biometricPermanentlyLockedOut =>
      'I-biometrics ikhiyiwe. Vula ifoni yakho kuqala nge-PIN noma iphethini.';

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
      'Ukuhlolwa kwe-biometric kuhlulekile. Zama futhi.';

  @override
  String get registerTitle => 'Dala i-akhawunti';

  @override
  String get registerPersonalDetails => 'IMINININGWANE YAKHO';

  @override
  String get registerFullName => 'Igama eligcwele';

  @override
  String get registerEmail => 'Ikheli le-imeyili';

  @override
  String get registerMobile => 'Inombolo yocingo';

  @override
  String get registerInstallationAddress => 'IKHELI LOKUFAKA';

  @override
  String get registerAddressHint => 'Ikheli lomgwaqo, indawo, idolobha';

  @override
  String get registerLocationCaptured => 'Indawo ithatshiwe';

  @override
  String get registerUseLocation => 'Sebenzisa indawo yami yamanje';

  @override
  String get registerLocationHelp =>
      'Kwenza ukuhlolwa kwakho kokufinyelela kube ngokuqondile endaweni yakho — usengakwazi ukuhlela ikheli elingenhla.';

  @override
  String get registerContactHeading => 'SINGAKUCONGA KANJANI?';

  @override
  String get registerMarketingHeading => 'IZINKETHO ZOKUSHISEKELA';

  @override
  String get registerMarketingEmail => 'Ngithumelele iziphakamiso nge-imeyili';

  @override
  String get registerMarketingSms => 'Ngithumelele iziphakamiso nge-SMS';

  @override
  String get registerMarketingPush => 'Ngithumelele izaziso';

  @override
  String get registerCreateAccount => 'Dala i-akhawunti';

  @override
  String get registerSaveFailed =>
      'Ayikwazanga ukulondoloza imininingwane yakho — sicela uzame futhi.';

  @override
  String get registerLocationDenied =>
      'Imvume yendawo enqatshiwe — faka ikheli lakho ngesandla.';

  @override
  String get registerLocationFailed =>
      'Ayikwazanga ukuthola indawo yakho — qinisekisa ukuthi amasevisi endawo avuliwe.';

  @override
  String get accountTitle => 'I-akhawunti';

  @override
  String get accountNotLoggedIn => 'Awungenile';

  @override
  String get accountAppearance => 'ISIMO SOKUBONAKALA';

  @override
  String get accountThemeSystem => 'Landela isethingi yedivayisi';

  @override
  String get accountThemeLight => 'Okukhanyayo';

  @override
  String get accountThemeDark => 'Okumnyama';

  @override
  String get accountLanguage => 'ULIMI';

  @override
  String get accountLanguageSystem => 'Landela ulimi lwedivayisi';

  @override
  String get accountLogOut => 'Phuma';

  @override
  String get accountLogOutTitle => 'Uyaphuma?';

  @override
  String get accountLogOutBody => 'Ungangena futhi noma inini.';

  @override
  String get accountNotifications => 'IZAZISO';

  @override
  String get accountPushTitle => 'Izaziso ze-push';

  @override
  String get accountPushOn =>
      'Kuvuliwe — izixwayiso zokusetshenziswa, ukucishwa kanye nezibuyekezo zama-oda';

  @override
  String get accountPushOff =>
      'Kuvaliwe — vula ukuze uthole izixwayiso zokusetshenziswa, ukucishwa kanye nezibuyekezo zama-oda';

  @override
  String get accountPushBlocked =>
      'Kuvinjiwe — shintsha lokhu kumasethingi esistimu';

  @override
  String get accountPushTurnOn => 'Vula';

  @override
  String get accountPushOpenSettings => 'Vula amasethingi';

  @override
  String get accountPrivacy => 'UKUZIBOPHA NEDATHA';

  @override
  String get accountPrivacyPolicy => 'Inqubomgomo yobumfihlo';

  @override
  String get accountDownloadData => 'Landa idatha yami';

  @override
  String get accountDownloadDataDone =>
      'Isicelo samukelwe. Sizothumela idatha yakho ku-imeyili yakho uma isilungile.';

  @override
  String get accountDeleteData => 'Susa i-akhawunti nedatha yami';

  @override
  String get accountDeleteTitle => 'Susa i-akhawunti yakho?';

  @override
  String get accountDeleteBody =>
      'Lokhu kususa unomphela i-akhawunti yakho ye-Sentech nayo yonke idatha yakho yomuntu siqu ekule foni. Akukwazi ukuphindwa.';

  @override
  String get accountDeleteConfirm => 'Susa konke';

  @override
  String get accountRequestFailed =>
      'Asikwazanga ukuqedela lesi sicelo. Sicela uzame futhi.';

  @override
  String get accountLinkFailed => 'Ayikwazanga ukuvula isixhumanisi.';

  @override
  String get supportTitle => 'Usizo nokwesekwa';

  @override
  String get supportSearchHint => 'Sesha imibuzo evame ukubuzwa';

  @override
  String supportNoResults(String query) {
    return 'Ayikho imiphumela ye-\"$query\"';
  }

  @override
  String get supportStillStuck => 'USAHLALELE?';

  @override
  String get supportWhatsApp => 'WhatsApp';

  @override
  String get supportSubmitTicket => 'Thumela ithikithi';

  @override
  String get supportTicketCategory => 'Isigaba';

  @override
  String get supportTicketDescribe => 'Chaza inkinga';

  @override
  String get supportCategoryBilling => 'Ukufakelwa kwamabhili';

  @override
  String get supportCategoryTechnical => 'Obuchwepheshe';

  @override
  String get supportCategoryOther => 'Okunye';

  @override
  String get supportWhatsAppFailed =>
      'Ayikwazanga ukuvula i-WhatsApp — ingabe ifakiwe?';

  @override
  String get supportTicketOpened =>
      'Ithikithi livulwe ku-app yakho ye-imeyili — lithumele ukuze ulithumele.';

  @override
  String get supportTicketNoEmail =>
      'Ayikwazanga ukuvula i-app ye-imeyili kule divayisi.';

  @override
  String get consentTitle => 'Ubumfihlo bakho';

  @override
  String get consentLocationBody =>
      'Sisebenzisa indawo yefoni yakho kanye kuphela ukuhlola ukufinyeleleka kwe-5G ekhelini lakho. Ayigcinwa efonini yakho noma ngemva kokuhlolwa.';

  @override
  String get consentRicaBody =>
      'Umthetho waseNingizimu Afrika (i-RICA) udinga ukuthi siqinisekise ubunikazi bakho. Sizocubungula ubuso bakho nolwazi lwe-ID ukuze siqinisekise kuphela, ngokwe-POPIA.';

  @override
  String get consentLegalBody =>
      'To use the app you need to accept the Terms of Service and the Privacy notice.';

  @override
  String get dataExportTitle => 'Your data';

  @override
  String get dataExportBody =>
      'This is the personal information we hold about you. Keep it private.';

  @override
  String get consentPolicyLink => 'Funda inqubomgomo yethu yobumfihlo';

  @override
  String get consentAgree => 'Ngiyavuma';

  @override
  String get consentDecline => 'Hhayi manje';

  @override
  String get notifRationaleTitle => 'Hlala wazi';

  @override
  String get notifRationaleBody =>
      'Vumela izaziso ukuze sikwazi ukukutshela uma idatha yakho iphela, uma kukhona ukucishwa endaweni yakho, nalapho i-oda lakho liqhubeka. Ungazivala noma inini.';

  @override
  String get notifRationaleAllow => 'Vumela izaziso';

  @override
  String get notifRationaleLater => 'Hhayi manje';

  @override
  String get a11yCart => 'Ikalishi lokuthenga';

  @override
  String get a11yDecreaseQuantity => 'Nciphisa inani';

  @override
  String get a11yIncreaseQuantity => 'Khulisa inani';

  @override
  String get a11yToggleTorch => 'Vula noma uvale ithoshi';

  @override
  String get a11yEnterCode => 'Faka ikhodi ngesandla';

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
