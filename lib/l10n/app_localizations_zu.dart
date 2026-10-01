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
      'Akukho isigxivizo somunwe noma ubuso obusethiwe kule foni. Engeza okukodwa kumasethingi esistimu, noma ungene ngephasiwedi yakho.';

  @override
  String get biometricUnavailable =>
      'I-biometrics ayitholakali okwamanje. Ngena ngephasiwedi yakho.';

  @override
  String get biometricLockedOut =>
      'Imizamo eminingi kakhulu. Linda isikhashana bese uzama futhi, noma ungene ngephasiwedi yakho.';

  @override
  String get biometricPermanentlyLockedOut =>
      'I-biometrics ikhiyiwe. Vula ifoni yakho kuqala nge-PIN noma iphethini, noma ungene ngephasiwedi yakho.';

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
  String get otpDemoHint => 'Demo mode: any 6-digit code except 000000 works.';

  @override
  String get otpTermsRequired =>
      'To sign in you need to accept the Terms of Service. Please try again.';

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
      'Ukuhlolwa kwe-biometric kuhlulekile. Zama futhi noma ungene ngephasiwedi yakho.';

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
  String get accountProvider => 'PROVIDER';

  @override
  String get accountChangeProvider => 'Change provider';
}
