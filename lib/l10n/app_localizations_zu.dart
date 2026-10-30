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
  String get accountAppearance => 'Isimo sokubonakala';

  @override
  String get accountDataSaver => 'Data saver: fewer pictures and no animations';

  @override
  String get accountDataSaverSaveFailed =>
      'Could not save Data saver. Try again.';

  @override
  String get accountThemeSystem => 'Landela isethingi yedivayisi';

  @override
  String get accountThemeLight => 'Okukhanyayo';

  @override
  String get accountThemeDark => 'Okumnyama';

  @override
  String get accountLanguage => 'Ulimi';

  @override
  String get accountLanguageSystem => 'Landela ulimi lwedivayisi';

  @override
  String get accountLogOut => 'Phuma';

  @override
  String get accountLogOutTitle => 'Uyaphuma?';

  @override
  String get accountLogOutBody => 'Ungangena futhi noma inini.';

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
  String get supportComposeTitle => 'Thumela umlayezo osizweni';

  @override
  String get supportTopicLabel => 'Isihloko';

  @override
  String get supportTopicConnecting => 'Ukuxhuma ku-Wi-Fi';

  @override
  String get supportTopicPayment => 'Inkokhelo';

  @override
  String get supportTopicPass => 'Ipasi lami';

  @override
  String get supportTopicAccount => 'I-akhawunti yami';

  @override
  String get supportTopicOther => 'Okunye';

  @override
  String get supportContactKindEmail => 'I-imeyili';

  @override
  String get supportContactKindPhone => 'Iselula';

  @override
  String get supportContactEmailLabel => 'Ikheli lakho le-imeyili';

  @override
  String get supportContactPhoneLabel => 'Inombolo yakho yeselula';

  @override
  String get supportMessageLabel => 'Umlayezo wakho';

  @override
  String get supportOrderRefLabel => 'Inkomba ye-oda (akuphoqelekile)';

  @override
  String get supportSendMessage => 'Thumela umlayezo';

  @override
  String get supportSentTitle => 'Umlayezo uthunyelwe';

  @override
  String get supportSentBody =>
      'Silutholile umlayezo wakho. Sebenzisa le nkomba uma uphinda uxhumana nosizo.';

  @override
  String supportSentReference(String reference) {
    return 'Inkomba: $reference';
  }

  @override
  String get supportDone => 'Kwenziwe';

  @override
  String get supportIssueMessageTooShort =>
      'Bhala okungenani izinhlamvu eziyi-10.';

  @override
  String get supportIssueMessageTooLong =>
      'Gcina umlayezo wakho ungaphansi kwezinhlamvu ezi-2000.';

  @override
  String get supportIssueOrderRef =>
      'Inkomba ye-oda inamagama, izinombolo namadashi kuphela (4 kuya ku-40).';

  @override
  String get supportEmailInstead => 'Sithumelele i-imeyili esikhundleni';

  @override
  String get consentTitle => 'Ubumfihlo bakho';

  @override
  String get consentLocationBody =>
      'Sisebenzisa indawo yefoni yakho kanye kuphela ukuhlola ukufinyeleleka kwe-5G ekhelini lakho. Ayigcinwa efonini yakho noma ngemva kokuhlolwa.';

  @override
  String get consentLocationMapService =>
      'To turn your location into an address, your phone\'s map service (Google or Apple) looks it up.';

  @override
  String get coverageAddressLookupNotice =>
      'Your phone\'s map service (Google or Apple) finds the address you type.';

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
  String get accountSwitchProvider => 'Switch WiFi provider';

  @override
  String get servicesHomeInternetHeading => 'Iintanethi yasekhaya';

  @override
  String get servicesTitle => 'Amasevisi ami';

  @override
  String get servicesEmpty => 'Awunayo isevisi yeintanethi yasekhaya okwamanje';

  @override
  String get servicesPastTitle => 'Amasevisi adlule';

  @override
  String get serviceDetailTitle => 'Imininingwane yesevisi';

  @override
  String get serviceStatusPending => 'Iyaqala';

  @override
  String get serviceStatusActive => 'Iyasebenza';

  @override
  String get serviceStatusSuspended => 'Imisiwe';

  @override
  String get serviceStatusCancelled => 'Iphelile';

  @override
  String get serviceKindHotspot => 'I-hotspot yasekhaya';

  @override
  String get serviceKindFixedWireless => 'I-fixed wireless';

  @override
  String servicePricePerMonth(String price) {
    return '$price ngenyanga';
  }

  @override
  String serviceSpeeds(String down, String up) {
    return 'Phansi $down Mbps, phezulu $up Mbps';
  }

  @override
  String serviceNumber(String number) {
    return 'Isevisi $number';
  }

  @override
  String servicePaidUntil(String date) {
    return 'Ikhokhelwe kuze kube yilo $date';
  }

  @override
  String serviceEndsOn(String date) {
    return 'Iphela ngo-$date';
  }

  @override
  String serviceEndedOn(String date) {
    return 'Iphele ngo-$date';
  }

  @override
  String get serviceCancelScheduledTitle => 'Ukukhansela kuhlelwe';

  @override
  String servicePlanChangeOn(String plan, String date) {
    return 'Ukushintsha uhlelo kuye ku-$plan ngo-$date';
  }

  @override
  String servicePlanChangeScheduled(String date) {
    return 'Ukushintsha uhlelo kuhlelwe ngo-$date';
  }

  @override
  String get serviceFactPlan => 'Uhlelo';

  @override
  String get serviceFactType => 'Uhlobo';

  @override
  String get serviceFactPrice => 'Intengo';

  @override
  String get serviceFactSpeed => 'Isivinini';

  @override
  String get serviceFactNumber => 'Inombolo yesevisi';

  @override
  String get serviceFactPaidThrough => 'Ikhokhelwe kuze kube';

  @override
  String get serviceBannerFirstInvoiceUnpaid =>
      'Khokha i-invoyisi yakho yokuqala ukuze uqale';

  @override
  String get serviceBannerKycRequired => 'Sidinga ukuhlola i-ID yakho';

  @override
  String get serviceBannerAwaitingInstallation =>
      'Kulindwe ukufakwa umhlinzeki wakho';

  @override
  String get serviceBannerCustomerLinkRequired =>
      'I-akhawunti yakho ayixhunyiwe nomhlinzeki wakho. Xhumana nomhlinzeki wakho.';

  @override
  String get serviceBannerContractRequired =>
      'Inkontileka yakho yesevisi ayisayinwanga. Xhumana nomhlinzeki wakho.';

  @override
  String get serviceBannerActivating =>
      'Iyasebenza, lokhu kungathatha amaminithi ambalwa. Donsa ukuvuselela.';

  @override
  String get serviceBannerProviderSettingUp => 'Umhlinzeki wakho uyakumisa';

  @override
  String get serviceBannerSuspendedNonPayment =>
      'Khokha i-invoyisi yakho evuliwe ukuze isevisi ibuyiselwe';

  @override
  String get serviceBannerSuspendedKyc =>
      'Sidinga ukuhlola i-ID yakho ngaphambi kokuthi isevisi iqhubeke';

  @override
  String get serviceBannerSuspendedProvider =>
      'Imiswe umhlinzeki wakho. Xhumana nosizo.';

  @override
  String get serviceActionViewInvoices => 'Buka ama-invoyisi';

  @override
  String get serviceActionIdCheck => 'Qala ukuhlola i-ID';

  @override
  String get serviceChangePlanAction => 'Shintsha uhlelo';

  @override
  String get serviceChangePlanBlockedCancelling =>
      'Akutholakali ngenkathi ukukhansela kuhleliwe.';

  @override
  String get serviceChangePlanBlockedInactive =>
      'Kutholakala uma isevisi yakho isisebenza.';

  @override
  String get serviceCancelAction => 'Khansela isevisi';

  @override
  String get serviceCancelPendingContact =>
      'Xhumana nosizo ukuze ukhansele isevisi engakaqali.';

  @override
  String get serviceCancelNoUndo =>
      'Ukukhansela okuhleliwe akukwazi ukuhlehliswa kuhlelo lokusebenza. Xhumana nomhlinzeki wakho uma ushintshe umqondo.';

  @override
  String get changePlanTitle => 'Shintsha uhlelo';

  @override
  String changePlanCurrent(String plan) {
    return 'Uhlelo lwakho: $plan';
  }

  @override
  String get changePlanChoose => 'Khetha uhlelo olusha';

  @override
  String get changePlanEmpty =>
      'Azikho ezinye izinhlelo ongashintshela kuzo njengamanje.';

  @override
  String get changePlanIdCheckNeeded => 'Kudingeka ukuhlolwa kwe-ID';

  @override
  String changeConfirmTitle(String plan) {
    return 'Shintshela ku-$plan?';
  }

  @override
  String get changeConfirmHigher =>
      'Kushintsha manje. Uzothola i-invoyisi yomehluko wesikhathi esisele salokhu inyanga.';

  @override
  String changeConfirmLower(String date) {
    return 'Kuqala ukusebenza ngo-$date. Kuze kube yileso sikhathi ugcina uhlelo lwakho lwamanje.';
  }

  @override
  String get changeConfirmUnknown =>
      'Umhlinzeki wakho unquma ukuthi kuqala nini ukusebenza.';

  @override
  String get changeConfirmButton => 'Shintsha uhlelo';

  @override
  String get changeSubmitting => 'Iyashintsha uhlelo…';

  @override
  String get changeResultAppliedTitle => 'Uhlelo lushintshiwe';

  @override
  String changeResultAppliedBody(String plan) {
    return 'Manje usohlelweni lwe-$plan.';
  }

  @override
  String get changeResultScheduledTitle => 'Ushintsho loluhlelo luhleliwe';

  @override
  String changeResultScheduledBody(String date) {
    return 'Kuhlelelwe ngo-$date. Kuze kube yileso sikhathi ugcina uhlelo lwakho lwamanje.';
  }

  @override
  String get changeResultViewInvoice => 'Buka i-invoyisi';

  @override
  String get cancelDialogTitle => 'Khansela le sevisi?';

  @override
  String cancelDialogBody(String date) {
    return 'Isevisi yakho ihlala isebenza kuze kube ngu-$date. Ngemva kwalokho iyama futhi ngeke usatshaji futhi.';
  }

  @override
  String get cancelDialogNoUndo =>
      'Lokhu akukwazi ukuhlehliswa kuhlelo lokusebenza.';

  @override
  String get cancelReasonLabel => 'Kungani uhamba?';

  @override
  String get cancelReasonMoving => 'Ngiyathuthuka';

  @override
  String get cancelReasonExpensive => 'Kubiza kakhulu';

  @override
  String get cancelReasonUnreliable => 'Akwethembeki ngokwanele';

  @override
  String get cancelReasonOther => 'Okunye';

  @override
  String get cancelReasonDetailLabel => 'Sitshele okwengeziwe (akuphoqelekile)';

  @override
  String get cancelReasonRequired => 'Khetha isizathu.';

  @override
  String get cancelKeep => 'Gcina isevisi';

  @override
  String get cancelConfirm => 'Khansela isevisi';

  @override
  String get cancelSubmitting => 'Iyakhansela…';

  @override
  String cancelDone(String date) {
    return 'Ukukhansela kuhlelelwe ngo-$date';
  }

  @override
  String get failureCancellationScheduled =>
      'Le sevisi isivele ihlelelwe ukuphela.';

  @override
  String get failurePlanChangeBilled =>
      'Isikhathi sakho esilandelayo sesivele sitshajiwe. Zama futhi ngemva kokuthi siqale.';

  @override
  String get failurePendingCancel =>
      'Xhumana nosizo ukuze ukhansele isevisi engakaqali.';

  @override
  String accountContactProvider(String provider) {
    return 'Contact $provider';
  }

  @override
  String get passesTitle => 'My passes';

  @override
  String get passEnded => 'Pass ended';

  @override
  String passEndsIn(String date, String time) {
    return 'ends $date (in $time)';
  }

  @override
  String passOfCap(String cap) {
    return 'of $cap';
  }

  @override
  String passesUpdated(String ago) {
    return 'Updated $ago ago';
  }

  @override
  String get accountUsageAlerts => 'Usage alerts';

  @override
  String get accountUsageAlertsUnavailable =>
      'Usage alerts are not available yet.';

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

  @override
  String get navHome => 'Home';

  @override
  String get navShop => 'Shop';

  @override
  String get navScan => 'Scan';

  @override
  String get navHelp => 'Help';

  @override
  String get navAccount => 'Account';

  @override
  String get homeTitle => 'Home';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String priceInclVat(String price) {
    return '$price incl. VAT';
  }

  @override
  String homeFinishOrder(String number) {
    return 'Finish your order #$number';
  }

  @override
  String homeDataUsed(String used, String total) {
    return '$used GB of $total GB';
  }

  @override
  String homePlanRenews(String plan, String date) {
    return '$plan · renews $date';
  }

  @override
  String homeRouterAddress(String suffix) {
    return 'MAC •• •• $suffix';
  }

  @override
  String get homeVerifyYourIdentityToContinue =>
      'Verify your identity to continue';

  @override
  String get homeYourLastPaymentDidNotGo =>
      'Your last payment did not go through. Try again.';

  @override
  String get homeCompleteYourPayment => 'Complete your payment';

  @override
  String get homeUsed => 'USED';

  @override
  String get shopTitle => 'Buy';

  @override
  String shopAddedToCart(String name) {
    return '$name added to cart';
  }

  @override
  String get planBadgeOurPick => 'Our pick';

  @override
  String get pricePerMonth => '/month';

  @override
  String shopPlanSpeed(String data, String speed) {
    return '$data · up to $speed Mbps';
  }

  @override
  String get shopAddToCart => 'Add to cart';

  @override
  String cartPriceEach(String price) {
    return '$price each';
  }

  @override
  String get cartYourCart => 'Your cart';

  @override
  String get cartYourCartIsEmpty => 'Your cart is empty';

  @override
  String get cartTotal => 'Total';

  @override
  String get cartCheckout => 'Checkout';

  @override
  String get checkoutCheckout => 'Checkout';

  @override
  String get checkoutToPay => 'To pay';

  @override
  String get checkoutTotalDue => 'Total due';

  @override
  String get checkoutVerifyIdentityToContinue => 'Verify identity to continue';

  @override
  String get checkoutContinueToPayment => 'Continue to payment';

  @override
  String orderExpiredBeforePayment(String number) {
    return 'Order #$number expired before payment was confirmed.';
  }

  @override
  String orderCancelled(String number) {
    return 'Order #$number was cancelled.';
  }

  @override
  String orderNotComplete(String number) {
    return 'Order #$number is not complete yet.';
  }

  @override
  String orderNumberLabel(String number) {
    return 'Order #$number';
  }

  @override
  String get confirmationOrder => 'Order';

  @override
  String get confirmationBackToHome => 'Back to Home';

  @override
  String get confirmationContinueYourOrder => 'Continue your order';

  @override
  String get confirmationTrackMyInstallation => 'Track my installation';

  @override
  String get confirmationCourierDispatched => 'Courier dispatched';

  @override
  String get confirmationRouterKitOnItsWay => 'Router kit on its way';

  @override
  String get confirmationSelfInstall => 'Self-install';

  @override
  String get confirmationFollowTheSetupGuideInThe =>
      'Follow the setup guide in the app';

  @override
  String get confirmationActivation => 'Activation';

  @override
  String get confirmationSignalConfirmedServiceLive =>
      'Signal confirmed, service live';

  @override
  String paymentPaySecurely(String price) {
    return 'Pay $price securely';
  }

  @override
  String get paymentPayment => 'Payment';

  @override
  String get paymentConfirmingYourPaymentThisCanTake =>
      'Confirming your payment. This can take a minute. Your order stays saved if you leave this screen.';

  @override
  String get paymentChooseHowToPayOnThe =>
      'Choose how to pay on the secure payment page.';

  @override
  String get paymentPayOnASecurePaymentPage =>
      'Pay on a secure payment page. We never see or store your card details.';

  @override
  String get paymentIdentityVerified => 'Identity verified';

  @override
  String get paymentWifiPassOrder => 'WiFi pass order';

  @override
  String get paymentYourOrder => 'Your order';

  @override
  String voucherProductReady(String product) {
    return '$product is ready';
  }

  @override
  String voucherDataAdded(String amount) {
    return '$amount GB has been added to your account.';
  }

  @override
  String get voucherTooManyTries => 'Too many tries';

  @override
  String get voucherWaitAFewMinutesThenTry =>
      'Wait a few minutes, then try again.';

  @override
  String get voucherYouReOffline => 'You\'re offline';

  @override
  String get voucherSomethingWentWrong => 'Something went wrong';

  @override
  String get voucherCheckYourConnectionAndTryAgain =>
      'Check your connection and try again. We could not confirm whether this voucher was used.';

  @override
  String get voucherWeCouldNotCheckThisVoucher =>
      'We could not check this voucher. Please try again.';

  @override
  String get voucherVoucherRedeemed => 'Voucher redeemed';

  @override
  String get voucherDataHasBeenAddedToYour =>
      'Data has been added to your account.';

  @override
  String get voucherYourPassIsOnYourAccount =>
      'Your pass is on your account. Find it under My passes.';

  @override
  String get voucherAlreadyUsed => 'Already used';

  @override
  String get voucherThisVoucherHasAlreadyBeenRedeemed =>
      'This voucher has already been redeemed.';

  @override
  String get voucherVoucherExpired => 'Voucher expired';

  @override
  String get voucherThisVoucherIsNoLongerValid =>
      'This voucher is no longer valid.';

  @override
  String get voucherOneCharacterLooksWrong => 'One character looks wrong';

  @override
  String get voucherCompareTheCodeWithYourVoucher =>
      'Compare the code with your voucher card, then try again.';

  @override
  String get voucherCheckTheCode => 'Check the code';

  @override
  String get voucherVoucherCodesNeverUse01 =>
      'Voucher codes never use 0, 1, I, L, O or U. Check those characters.';

  @override
  String get voucherVoucherCodesHave12LettersAnd =>
      'Voucher codes have 12 letters and numbers.';

  @override
  String get voucherNotAVoucherCode => 'Not a voucher code';

  @override
  String get voucherCheckTheCodeOnYourVoucher =>
      'Check the code on your voucher card and try again.';

  @override
  String get voucherThatCodeDidnTWork => 'That code didn\'t work';

  @override
  String get voucherItMayBeMistypedAlreadyUsed =>
      'It may be mistyped, already used or not active yet. Check it, or ask the shop.';

  @override
  String get scanScanVoucher => 'Scan voucher';

  @override
  String get scanAlignTheVoucherSQrCode =>
      'Align the voucher\'s QR code within the frame';

  @override
  String get scanTypeTheCodeInstead => 'Type the code instead';

  @override
  String get scanEnterVoucherCode => 'Enter voucher code';

  @override
  String get scanEGAbcd2345Efgh => 'e.g. ABCD-2345-EFGH';

  @override
  String get scan12LettersAndNumbersOnYour =>
      '12 letters and numbers, on your voucher card';

  @override
  String get scanPaste => 'Paste';

  @override
  String get scanRedeem => 'Redeem';

  @override
  String get scanEnableTheCameraInSystemSettings =>
      'Enable the camera in system settings, or type the code below.';

  @override
  String get scanCameraUnavailablePleaseTypeTheCode =>
      'Camera unavailable. Please type the code below.';

  @override
  String freeWifiAdOffer(String remaining) {
    return 'Watch an ad for 45 minutes of free WiFi. $remaining of 3 free views left today.';
  }

  @override
  String freeWifiTimeRemaining(String minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get freeWifiFreeWifi => 'Free WiFi';

  @override
  String get freeWifiWatchAd => 'Watch ad';

  @override
  String get freeWifiHotspots => 'Hotspots';

  @override
  String get freeWifiFreeWifiActive => 'Free WiFi active';

  @override
  String get freeWifiTimeLeft => 'TIME LEFT';

  @override
  String get freeWifiDataLeft => 'DATA LEFT';

  @override
  String get freeWifiFindHotspotsNearMe => 'Find hotspots near me';

  @override
  String get freeWifiYouVeUsedAll3Free =>
      'You\'ve used all 3 free WiFi ads today. Come back tomorrow.';

  @override
  String get freeWifiUpdatesFromYourAccountAsYou =>
      'Updates from your account as you use it.';

  @override
  String get freeWifiYourFreeWifiAdIsPlaying => 'Your free WiFi ad is playing…';

  @override
  String get freeWifiSimulatedNoSkipUntilItFinishes =>
      '(simulated — no skip until it finishes)';

  @override
  String get hotspotsWifiHotspotsNearYou => 'WiFi hotspots near you';

  @override
  String get hotspotsEnableLocationToSeeWhichHotspot =>
      'Enable location to see which hotspot is closest to you.';

  @override
  String get hotspotsClosest => 'CLOSEST';

  @override
  String coverageCurrentLocation(String latitude, String longitude) {
    return 'Current location ($latitude, $longitude)';
  }

  @override
  String coverageEstimatedSpeed(String speed) {
    return 'Estimated speed: up to $speed Mbps';
  }

  @override
  String get coverageTurnOnLocationServicesToUse =>
      'Turn on location services to use this.';

  @override
  String get coverageLocationPermissionDeniedEnterYourAddress =>
      'Location permission denied — enter your address manually.';

  @override
  String get coverageCouldNotGetYourLocationCheck =>
      'Could not get your location — check that location services are on.';

  @override
  String get coverageCoverageCheck => 'Coverage check';

  @override
  String get coverageAddress => 'Address';

  @override
  String get coverageUseMyCurrentLocation => 'Use my current location';

  @override
  String get coverageViewPlansForThisAddress => 'View plans for this address';

  @override
  String get coverageCheckADifferentAddress => 'Check a different address';

  @override
  String get coverageCheckThisAddress => 'Check this address';

  @override
  String get coverageNotYetCovered => 'Not yet covered';

  @override
  String get coverageHomeInternetIsAvailableHere =>
      'Home internet is available here';

  @override
  String get ricaPrivacyNotice =>
      'Your face and ID information are used for verification only, under POPIA. You will be asked to confirm your consent before the check starts.';

  @override
  String get ricaVerifyYourIdentity => 'Verify your identity';

  @override
  String get ricaLookAtTheCameraAndBlink =>
      'Look at the camera and blink slowly…';

  @override
  String get ricaReadyToVerifyWhenYouAre => 'Ready to verify when you are.';

  @override
  String get ricaWeCouldnTReachOurServers =>
      'We couldn\'t reach our servers. Check your connection and try again.';

  @override
  String get ricaWeCouldnTUpdateYourOrder =>
      'We couldn\'t update your order. Try again in a moment.';

  @override
  String get ricaWeCouldnTVerifyYourIdentity =>
      'We couldn\'t verify your identity. Keep your face well lit and fully in the frame. Please try again. You haven\'t been charged.';

  @override
  String promotionsPoints(String count) {
    return '$count points';
  }

  @override
  String promotionsExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get promotionsPromotionsLoyalty => 'Promotions & loyalty';

  @override
  String get promotionsYourSentechLoyaltyBalance =>
      'Your Sentech loyalty balance';

  @override
  String get promotionsCurrentOffers => 'CURRENT OFFERS';

  @override
  String get routerPageNotFound => 'Page not found';

  @override
  String get routerBackToHome => 'Back to Home';

  @override
  String mapDataAttribution(String attribution) {
    return 'Map data $attribution';
  }

  @override
  String get paymentClosePayment => 'Close payment';

  @override
  String get paymentSecurePayment => 'Secure payment';

  @override
  String paymentTestExplanation(String price) {
    return 'No money moves. This simulates payment for $price.';
  }

  @override
  String get paymentTestPaymentLocalStack => 'Test payment (local stack)';

  @override
  String get paymentApproveTestPayment => 'Approve test payment';

  @override
  String get paymentDeclineTestPayment => 'Decline test payment';

  @override
  String get bootSentechConnectIsStarting => 'Sentech Connect is starting';

  @override
  String get bootSkipIntro => 'Skip intro';

  @override
  String get bootSkip => 'Skip';

  @override
  String get failureYouReOfflineCheckYourConnection =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get failureSomethingWentWrongPleaseTryAgain =>
      'Something went wrong. Please try again.';

  @override
  String get productCategoryHome5g => 'Home 5G';

  @override
  String get productCategoryMifi => 'MiFi';

  @override
  String get productCategoryVoucher => 'Vouchers';

  @override
  String get productCategoryHotspotPass => 'WiFi passes';

  @override
  String get startupErrorMessage =>
      'App configuration error — please reinstall or contact support';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageZulu => 'isiZulu';

  @override
  String get languageAfrikaans => 'Afrikaans';

  @override
  String hotspotMetersAway(String distance) {
    return '$distance m away';
  }

  @override
  String hotspotKilometersAway(String distance) {
    return '$distance km away';
  }

  @override
  String get demoFaq1Question => 'Why is my speed slower than expected?';

  @override
  String get demoFaq1Answer =>
      'Speed may drop from 6–10pm, when more people use the network. Thick walls and nearby electronics can also slow your connection. Move your router to an open, central spot. If that does not help, report the issue below.';

  @override
  String get demoFaq2Question => 'How do I top up my data?';

  @override
  String get demoFaq2Answer =>
      'Open Shop and choose a top-up or voucher. Pay by card, Ozow, or PayShap. Top-ups reach your account within a few minutes.';

  @override
  String get demoFaq3Question => 'My router lights are red';

  @override
  String get demoFaq3Answer =>
      'A solid red light usually means a signal or power problem. Check that the power cable is firmly plugged in. Wait 2 minutes for your router to reconnect. If it stays red, report the issue below.';

  @override
  String get demoPromotion1Title => 'Upgrade and save';

  @override
  String get demoPromotion1Description =>
      'Switch to Home 100 this month. Get 20% off your first month.';

  @override
  String get demoPromotion1Badge => '20% OFF';

  @override
  String get demoPromotion2Title => 'Refer a friend';

  @override
  String get demoPromotion2Description =>
      'Give a friend a free installation — you both get 10GB bonus data.';

  @override
  String get demoPromotion2Badge => 'REFERRAL';

  @override
  String get demoPromotion3Title => 'Loyalty reward';

  @override
  String get demoPromotion3Description =>
      'You\'ve earned enough points for a free Wi-Fi voucher. Redeem it in Vouchers.';

  @override
  String get demoPromotion3Badge => 'LOYALTY';

  @override
  String get supportChatGreeting => 'Hi Sentech, I need help with my account.';

  @override
  String supportEmailSubject(String category) {
    return '[$category] Support request';
  }

  @override
  String get homePromotionsLabel => 'See current offers';

  @override
  String get checkoutIdentityNotice =>
      'Next we verify your identity (required by RICA). You are only charged after that succeeds.';

  @override
  String get checkoutPaymentNotice =>
      'Pay on a secure payment page. Your pass starts when payment is confirmed.';

  @override
  String get ricaLawNotice =>
      'Required by South African law (RICA) before we can activate your service.';

  @override
  String get confirmationReady => 'You\'re all set!';

  @override
  String get confirmationPassPaid => 'Your WiFi pass is paid';

  @override
  String get confirmationConnectHint =>
      'You\'re all set. Connect at a WiFi hotspot to start.';

  @override
  String get mapUnavailable => 'Map not available.';

  @override
  String get offlineBanner =>
      'You\'re offline. Some things won\'t work until you reconnect.';

  @override
  String get failureNoInternetConnection => 'No internet connection.';

  @override
  String get failureSomethingWentWrongOnOurEnd =>
      'Something went wrong on our end.';

  @override
  String get failureThisAddressIsNotYetInOur =>
      'This address is not yet in our coverage area.';

  @override
  String get failureWeCouldNotFinishSigningYouIn =>
      'We could not finish signing you in. Please try again.';

  @override
  String get failureYourSessionHasEndedSignInAgain =>
      'Your session has ended. Sign in again.';

  @override
  String get failureThisProviderIsCurrentlyUnavailable =>
      'Your internet service is currently unavailable.';

  @override
  String get failureNotOfferedByProvider =>
      'This is not offered by your provider.';

  @override
  String get failureBuyFromProviderDirectly =>
      'Buy this from your provider directly.';

  @override
  String paymentBuyFromProvider(String provider) {
    return 'Buy this from $provider directly.';
  }

  @override
  String paymentContactProvider(String provider) {
    return 'Contact $provider.';
  }

  @override
  String get failureWeCouldNotFindThat => 'We could not find that.';

  @override
  String get failureTooManyAttemptsPleaseWaitAndTry =>
      'Too many attempts. Please wait and try again.';

  @override
  String get failureWeReceivedAnUnexpectedResponsePleaseTry =>
      'We received an unexpected response. Please try again.';

  @override
  String get failureTheRequestWasCancelled => 'The request was cancelled.';

  @override
  String get failureWeCouldNotMakeASecureConnection =>
      'We could not make a secure connection. Check your network and try again.';

  @override
  String get failureBlockedARequestToAnUnexpectedAddress =>
      'Blocked a request to an unexpected address.';

  @override
  String get failureEnterAValidSouthAfricanMobileNumber =>
      'Enter a valid South African mobile number.';

  @override
  String get failureEnterThe6DigitCode => 'Enter the 6-digit code.';

  @override
  String get failureCouldNotSaveYourDetailsOnThis =>
      'Could not save your details on this device.';

  @override
  String get failureCouldNotReadYourSavedDetails =>
      'Could not read your saved details.';

  @override
  String get failureTheCodeIsInvalidOrHasExpired =>
      'The code is invalid or has expired.';

  @override
  String get failureYourSessionCouldNotBeVerifiedSign =>
      'Your session could not be verified. Sign in again.';

  @override
  String get failureWeCouldNotLoadTheCompleteCatalogue =>
      'We could not load the complete catalogue. Please try again.';

  @override
  String get failureYourCartIsEmpty => 'Your cart is empty.';

  @override
  String get failureWeCouldNotLoadYourOpenOrder =>
      'We could not load your open order. Please try again.';

  @override
  String get failureIdentityChecksAreNotNeededForThis =>
      'Identity checks are not needed for this order.';

  @override
  String get failureWeCouldNotFindThatOrder => 'We could not find that order.';

  @override
  String get failureThisOrderWasReplacedByANewer =>
      'A newer order replaced this one. You can no longer pay for this order.';

  @override
  String get failureThisOrderCanNoLongerBePaid =>
      'This order can no longer be paid.';

  @override
  String get failureVerifyYourIdentityBeforePaying =>
      'Verify your identity before paying.';

  @override
  String get failureThePaymentWasNotCompletedYouHave =>
      'The payment was not completed. You have not been charged.';

  @override
  String get failureWeCouldNotOpenThePaymentPage =>
      'We could not open the payment page safely.';

  @override
  String get failureWeCouldNotLoadAllOfYour =>
      'We could not load all of your passes. Please try again.';

  @override
  String get failureWeCouldNotLoadTheLegalDocuments =>
      'We could not load the legal documents. Try again.';

  @override
  String get failureCouldNotSaveYourConsentOnThis =>
      'Could not save your consent on this device.';

  @override
  String get failureCouldNotSaveYourChoiceOnThis =>
      'Could not save your choice on this device.';

  @override
  String get failureUnknownProvider =>
      'We could not find your internet service.';

  @override
  String get failureYourPhoneSDateOrTimeLooks =>
      'Your phone\'s date or time looks wrong. Set it to automatic and try again.';

  @override
  String get failureYouAlreadyHaveAFreeWifiSession =>
      'You already have a free WiFi session running.';

  @override
  String get failureYouVeReachedTodaySFreeWifi =>
      'You\'ve reached today\'s free WiFi limit.';

  @override
  String get failureNotAllowed => 'You are not allowed to do that.';

  @override
  String get contactMethodEmail => 'Email';

  @override
  String get contactMethodSms => 'SMS';

  @override
  String get mapUnavailableNearestSpots =>
      'Map not available. Here are the nearest spots.';

  @override
  String get mapUnavailableWifiSpots =>
      'Map not available. Here are the WiFi spots.';

  @override
  String get hotspotsStatusMaintenance => 'Ilungiswa';

  @override
  String get hotspotsEmpty =>
      'Awekho ama-hotspot abhaliwe okwamanje. Buyela maduze.';

  @override
  String get orderCancelAction => 'Khansela i-oda';

  @override
  String get orderCancelConfirmTitle => 'Khansela leli oda?';

  @override
  String get orderCancelConfirmBody =>
      'Leli oda lizovalwa. Ungenza i-oda elisha noma nini.';

  @override
  String get orderCancelKeep => 'Gcina i-oda';

  @override
  String get invoicesTitle => 'Odinga';

  @override
  String get invoicesEmptyTitle => 'Awukabi nama-invoyisi';

  @override
  String get invoicesEmptyBody =>
      'Odinga bensizakalo yakho ye-inthanethi yasekhaya buzovela lapha.';

  @override
  String get invoicesOpenSection => 'Okufanele kukhokhwe';

  @override
  String get invoicesEarlierSection => 'Odinga bangaphambilini';

  @override
  String get invoiceStatusOpen => 'Kufanele kukhokhwe';

  @override
  String get invoiceStatusPaid => 'Kukhokhiwe';

  @override
  String get invoiceStatusVoid => 'Kukhanselwe';

  @override
  String get invoiceStatusWrittenOff => 'Kushiyiwe';

  @override
  String get invoiceKindInitial => 'I-invoyisi yokuqala';

  @override
  String get invoiceKindRecurring => 'I-invoyisi yenyanga';

  @override
  String get invoiceKindProration => 'Ushintsho lohlelo';

  @override
  String get invoiceKindReactivation => 'Ukuvuselelwa';

  @override
  String get invoiceKindAdjustment => 'Ukulungiswa';

  @override
  String get invoiceKindOther => 'I-invoyisi';

  @override
  String invoiceDueOn(String date) {
    return 'Kufanele kukhokhwe ngo-$date';
  }

  @override
  String invoiceIssuedOn(String date) {
    return 'Kukhishwe ngo-$date';
  }

  @override
  String invoicePaidOn(String date) {
    return 'Kukhokhwe ngo-$date';
  }

  @override
  String get invoiceDetailTitle => 'I-invoyisi';

  @override
  String invoicePeriod(String start, String end) {
    return 'Isikhathi: $start kuya ku-$end';
  }

  @override
  String get invoiceLinesHeading => 'Okukhokhelayo';

  @override
  String invoiceLineQuantity(String quantity, String price) {
    return '$quantity x $price';
  }

  @override
  String get invoiceTotal => 'Isamba';

  @override
  String invoiceIncludesVat(String amount) {
    return 'Kubandakanya i-VAT ye-$amount';
  }

  @override
  String get invoiceAmountPaid => 'Okukhokhiwe kuze kube manje';

  @override
  String get invoicePartPaid =>
      'Ingxenye yale invoyisi isikhokhiwe. Xhumana nosizo ukuze uphothule okusele.';

  @override
  String get invoiceVoidNote =>
      'Le nvoyisi ikhanseliwe. Akukho okufanele kukhokhwe.';

  @override
  String get invoiceWrittenOffNote =>
      'Le nvoyisi ishiyiwe. Akukho okufanele kukhokhwe.';

  @override
  String invoicePayNow(String amount) {
    return 'Khokha $amount';
  }

  @override
  String get invoicePayOnSecurePage =>
      'Ukhokha ekhasini eligcinekile lomhlinzeki wenkokhelo yakho.';

  @override
  String get invoiceConfirming =>
      'Siqinisekisa inkokhelo yakho. Lokhu kungathatha isikhashana.';

  @override
  String get invoiceStillPending =>
      'Asikezwa lutho kumhlinzeki wenkokhelo. Uma usukhokhile, le nvoyisi izobuyekezwa maduze.';

  @override
  String get invoicePaidTitle => 'Inkokhelo emukelwe';

  @override
  String get invoicePaidThanks => 'Siyabonga. Le nvoyisi ikhokhiwe.';

  @override
  String get invoicePaidKyc =>
      'Kudingeka sihlole i-ID yakho ngaphambi kokuthi isevisi yakho iqale.';

  @override
  String get invoicePaidInstallation =>
      'Silindele ukufakwa ngumhlinzeki wakho.';

  @override
  String get invoicePaidContactProvider =>
      'Isevisi yakho ayikwazi ukuqala okwamanje. Xhumana nomhlinzeki wakho.';

  @override
  String get invoicePaidActivating =>
      'Isevisi yakho iyaqala. Lokhu kungathatha amaminithi ambalwa. Donsa ukuze uvuselele.';

  @override
  String get invoicePaidSettingUp => 'Umhlinzeki wakho ulungisa isevisi yakho.';

  @override
  String get invoiceCollectionExternal =>
      'Umhlinzeki wakho uqoqa inkokhelo yale nvoyisi ngokwakhe.';

  @override
  String get invoiceBackToInvoices => 'Buyela kuma-invoyisi';

  @override
  String get loginTitleNew => 'Hello!';

  @override
  String get otpPasteCode => 'Paste code';

  @override
  String get otpPasteOnlyCode => 'Paste only the 6-digit code.';

  @override
  String get legalBodyLanguageNote => 'This text is only in English for now.';

  @override
  String get consentTermsLink => 'Read the Terms';

  @override
  String get consentTermsUnavailable =>
      'Terms link is unavailable. Please try again later.';

  @override
  String get legalLinkOpenFailed =>
      'Could not open the link. Please try again.';

  @override
  String get legalComplaints => 'Complaints';

  @override
  String get legalPaia => 'PAIA manual';

  @override
  String get legalCoolingOff => 'Cooling-off rights';

  @override
  String get legalServiceCharter => 'Service charter';

  @override
  String get loginEnterPhone => 'Enter your phone number';

  @override
  String passReadyTitle(String plan) {
    return '$plan is ready';
  }

  @override
  String get passReadyConnect => 'Connect to WiFi';

  @override
  String passReadyConnectNamed(String network) {
    return 'Connect to $network';
  }

  @override
  String get passReadyTurnOnWifi => 'Turn on WiFi';

  @override
  String get passReadyChooseNetwork => 'Choose the hotspot WiFi network';

  @override
  String passReadyChooseNamed(String network) {
    return 'Choose $network';
  }

  @override
  String get passReadySignInStep =>
      'The sign-in page opens. If not, open any website.';

  @override
  String get passReadyDone => 'Done';

  @override
  String get passReadyFindWifi => 'Find WiFi near me';

  @override
  String passReadyOrderDetail(String price, String orderNumber) {
    return '$price incl. VAT · Order #$orderNumber';
  }

  @override
  String get commonCheckCode => 'Check the code';

  @override
  String get scanVoucherCodeHelper =>
      'Enter the code printed on your voucher card.';

  @override
  String get voucherUncappedData => 'Uncapped data';

  @override
  String voucherDataMb(int amount) {
    return '$amount MB';
  }

  @override
  String voucherPassDetail(String data, int minutes, int devices) {
    return '$data · $minutes min · Devices: $devices';
  }

  @override
  String get promotionsTitle => 'Offers';

  @override
  String get promotionsEmpty => 'No offers right now';

  @override
  String get promotionsUnavailable =>
      'Offers are unavailable. Try again later.';

  @override
  String get promotionsOngoing => 'Ongoing';

  @override
  String get hotspotFaq1Question => 'I can\'t connect to the WiFi';

  @override
  String get hotspotFaq1Answer =>
      'Connect to the hotspot. Open a website starting with http://. This opens the sign-in page. If needed, turn off your VPN or private DNS. Try again.';

  @override
  String get hotspotFaq2Question => 'I paid but have no pass';

  @override
  String get hotspotFaq2Answer =>
      'Wait 1 minute for payment confirmation. Check your orders and receipts. If money left your account, contact support with your order reference.';

  @override
  String get hotspotFaq3Question => 'My hotspot connection is slow';

  @override
  String get hotspotFaq3Answer =>
      'Move closer to the hotspot. Disconnect and reconnect to WiFi. If it stays slow, contact support.';

  @override
  String get buyNow => 'Buy now';

  @override
  String get buyNowTryAgain => 'Try again';

  @override
  String get buyNowCreatingOrder => 'Creating order';

  @override
  String get buyNowWhatYouGet => 'What you get';

  @override
  String buyNowSpeed(String speed) {
    return 'Up to $speed Mbps';
  }

  @override
  String buyNowPay(String price) {
    return 'Pay $price';
  }

  @override
  String get paymentMethodsHeading => 'Ways to pay';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodInstantEft => 'Instant EFT';

  @override
  String get paymentMethodCashVoucher => 'Cash voucher';

  @override
  String get planBadgeOurPickHint => 'Selected by us for you';

  @override
  String get passesStatusSuspended => 'Isevisi imisiwe';

  @override
  String otpUseSmsReference(String reference) {
    return 'Sebenzisa i-SMS ekhombisa inkomba $reference.';
  }

  @override
  String get failureBindingRequired =>
      'Ukungena akukwazanga ukuqedwa. Sicela ubuyekeze uhlelo lokusebenza bese uyazama futhi.';

  @override
  String get failureHumanVerificationFailed =>
      'Asikwazanga ukuqinisekisa ukuthi ungumuntu. Sicela uzame futhi.';

  @override
  String get failureHumanVerificationUnavailable =>
      'Ukuhlolwa kokuphepha akutholakali manje. Sicela uzame futhi ngemva kwesikhashana.';

  @override
  String failureHumanVerificationUnavailableSeconds(int seconds) {
    return 'Ukuhlolwa kokuphepha akutholakali manje. Sicela uzame futhi ngemva kwemizuzwana engu-$seconds.';
  }

  @override
  String failureHumanVerificationUnavailableMinutes(int minutes) {
    return 'Ukuhlolwa kokuphepha akutholakali manje. Sicela uzame futhi ngemva kwemizuzu engu-$minutes.';
  }

  @override
  String get failureReauthRequired =>
      'Leyo khodi ayisebenzanga. Yihlole bese uyazama futhi.';

  @override
  String get failureSmsUnavailable =>
      'Asikwazanga ukuthumela i-SMS. Sicela uzame futhi ngemva kwesikhashana.';

  @override
  String get failureConsentVersionOutdated =>
      'Imigomo ibuyekeziwe. Sicela ubuyekeze futhi wamukele inguqulo yamuva.';

  @override
  String get failureSubscriberNotFound =>
      'Asikwazanga ukuthola i-akhawunti yesevisi yakho kulo muntu onikezayo.';

  @override
  String get failureActiveServiceExists =>
      'Usenayo isevisi esebenzayo. Qala ngokuyiklomelisa, noma uxhumane nomuntu onikezayo.';

  @override
  String get failureDeleteContactSupport =>
      'Asikwazi ukuthumela ikhodi kule akhawunti. Xhumana nosekelo ukuze isuswe i-akhawunti yakho.';

  @override
  String get accountDeleteSendCode => 'Ngithumelele ikhodi';

  @override
  String get accountDeleteCodeTitle => 'Faka ikhodi esikuthumelele yona';

  @override
  String get accountDeleteCodeBody =>
      'Ukuze uphephe sithumele ikhodi enezinombolo ezi-6 nge-SMS enombolweni ku-akhawunti yakho. Yifake ukuze usule i-akhawunti yakho nayo yonke idatha. Lokhu akunakuhlehliswa.';

  @override
  String get accountDeleteClose => 'Vala';

  @override
  String get passesSuspendedNote =>
      'Umhlinzeki wakho umise le sevisi. Xhumana naye ukuze ibuyiswe.';

  @override
  String get humanCheckTitle =>
      'Ukuhlola okusheshayo: qinisekisa ukuthi ungumuntu';

  @override
  String get humanCheckBody =>
      'Lokhu kugcina ukubhaliswa okuzenzakalelayo kuphume. Ngokuvamile kuthatha isekhondi kuphela.';

  @override
  String get humanCheckLoading => 'Iyalayisha ukuhlola…';

  @override
  String get humanCheckChallenge => 'Sicela ugcwalise ukuhlola ngezansi.';

  @override
  String get humanCheckFailedNetwork =>
      'Asikwazanga ukulayisha ukuhlola. Hlola uxhumo lwakho bese uyazama futhi.';

  @override
  String get humanCheckFailedWidget =>
      'Ukuhlola akusebenzanga kulokhu. Sicela uzame futhi.';

  @override
  String get humanCheckFailedTimeout =>
      'Ukuhlola kuthathe isikhathi eside kakhulu. Sicela uzame futhi.';

  @override
  String get humanCheckRetry => 'Zama futhi';

  @override
  String get humanCheckCancel => 'Khansela';

  @override
  String get humanCheckWidgetLabel => 'Ukuhlola ukuphepha';

  @override
  String get humanCheckHelp =>
      'Usabambekile? Khansela bese ungena kuwebhusayithi, noma uxhumane nosekelo.';

  @override
  String get failureFeatureDisabled => 'Lokhu akutholakali kumuntu onikezayo.';

  @override
  String get failureOrderNotCancellable =>
      'I-oda leli alisakwazi ukukhanselwa.';

  @override
  String get failureOrderCancelled => 'I-oda leli likhanseliwe.';

  @override
  String get failureSupportUnavailable =>
      'Imiyalezo yosizo ayitholakali okwamanje. Sicela uzame futhi kamuva.';

  @override
  String get failureSupportContactNotConfigured =>
      'Umuntu onikezayo akakawumisi umyalezo wosizo.';

  @override
  String get failureInvalidMessage => 'Hlola umyalezo wakho bese uzame futhi.';

  @override
  String get failureInvalidContact =>
      'Hlola imininingwane yakho yokuxhumana bese uzame futhi.';

  @override
  String get failureInvoiceNotPayable => 'I-invoyisi le ayisakwazi ukukhokhwa.';

  @override
  String get failureCustomerLinkRequired =>
      'I-akhawunti yakho ayikaxhunyaniswa nomuntu onikezayo. Xhumana nomuntu onikezayo.';

  @override
  String get failureAccountProblem =>
      'Kunenkinga ne-akhawunti yakho. Xhumana nomhlinzeki wakho.';

  @override
  String get kycTitle => 'Ukuhlolwa kwe-ID';

  @override
  String get kycRowSubtitle => 'Kudingeka kwezinye izinhlelo zenyanga';

  @override
  String get kycNoAccount =>
      'Awunayo i-akhawunti ye-inthanethi yasekhaya okwamanje, ngakho akukho ukuhlolwa kwe-ID okufanele kwenziwe.';

  @override
  String get kycNoneTitle => 'Sidinga ukuhlola i-ID yakho';

  @override
  String get kycNoneBody =>
      'Ezinye izinhlelo zenyanga zidinga ukuthi i-ID yakho ihlolwe ngaphambi kokuqala. Thumela imininingwane ye-ID yakho nesithombe esisodwa sedokhumenti ye-ID. Umhlinzeki wakho uyihlola ngesandla.';

  @override
  String get kycStart => 'Qala ukuhlolwa kwe-ID';

  @override
  String get kycPendingTitle => 'Siyayihlola i-ID yakho';

  @override
  String get kycPendingBody =>
      'Umhlinzeki wakho uyahlola lokho okuthumele. Sizokwazisa uma sekunesinqumo.';

  @override
  String get kycVerifiedTitle => 'I-ID yakho iqinisekisiwe';

  @override
  String get kycVerifiedBody =>
      'Akukho okunye okufanele ukwenze. Ukuhlolwa kwe-ID yakho kuqediwe.';

  @override
  String kycVerifiedOn(String date) {
    return 'Iqinisekiswe ngomhla ka-$date';
  }

  @override
  String kycSentOn(String date) {
    return 'Kuthunyelwe ngomhla ka-$date';
  }

  @override
  String get kycRejectedTitle =>
      'Asikwazanga ukwamukela ukuhlolwa kwe-ID yakho';

  @override
  String get kycRejectedBody =>
      'Sicela uhlole imininingwane yakho bese uyithumela futhi. Umhlinzeki wakho angakutshela okwengeziwe.';

  @override
  String get kycSubmitAgain => 'Thumela futhi';

  @override
  String get kycIdTypeSaId => 'Inombolo ye-ID yaseNingizimu Afrika';

  @override
  String get kycIdTypePassport => 'Inombolo yephasipoti';

  @override
  String get kycIdTypeCompanyReg => 'Inombolo yokubhaliswa kwenkampani';

  @override
  String kycEndingIn(String type, String last4) {
    return '$type equkela ku-$last4';
  }

  @override
  String get kycFormIntro =>
      'Faka imininingwane ngqo njengoba ivela kudokhumenti yakho ye-ID.';

  @override
  String get kycFieldIdType => 'Uhlobo lwe-ID';

  @override
  String get kycHintSaId => 'Izinombolo eziyi-13';

  @override
  String get kycHintPassport => 'Amalungu angu-6 kuya ku-12 noma izinombolo';

  @override
  String get kycHintCompanyReg => 'Ifomethi 1234/123456/12';

  @override
  String get kycFieldAddress => 'Ikheli lasekhaya';

  @override
  String get kycFieldAddressHint =>
      'Isitaladi, indawo, idolobha nekhodi yeposi';

  @override
  String get kycPhotoTitle => 'Isithombe sedokhumenti yakho ye-ID';

  @override
  String get kycPhotoHelp =>
      'Thatha isithombe esicacile ekukhanyeni okuhle, onxande abane bonke nombhalo wonke ufundeka.';

  @override
  String get kycTakePhoto => 'Thatha isithombe';

  @override
  String get kycChoosePhoto => 'Khetha kugalari';

  @override
  String get kycReplacePhoto => 'Shintsha isithombe';

  @override
  String get kycRemovePhoto => 'Susa isithombe';

  @override
  String get kycPhotoPreview =>
      'Ukubuka kuqala isithombe sedokhumenti yakho ye-ID';

  @override
  String get kycPhotoPreparing => 'Silungisa isithombe sakho…';

  @override
  String get kycPhotoDenied =>
      'Asikwazi ukuvula ikhamera noma izithombe zakho. Khetha enye indlela, noma uvumele ukufinyelela Kumasethingi.';

  @override
  String get kycOpenSettings => 'Vula Amasethingi';

  @override
  String get kycPhotoUnreadable =>
      'Asikwazanga ukufunda lesi sithombe. Khetha esinye.';

  @override
  String get kycPhotoTooLarge =>
      'Lesi sithombe sikhulu kakhulu ukuthi singathunyelwa. Khetha esincane.';

  @override
  String get kycPhotoFailed =>
      'Asikwazanga ukuthola isithombe. Sicela uzame futhi.';

  @override
  String get kycPhotoRequired => 'Engeza isithombe sedokhumenti yakho ye-ID.';

  @override
  String get kycConsentLabel =>
      'Ngiyavuma ukuthi umhlinzeki wami angasebenzisa le mininingwane nesi sithombe ukuhlola ubunikazi bami, njengoba kuchaziwe esitatimendeni sobumfihlo.';

  @override
  String get kycConsentRequired => 'Sicela uvume ukuze uqhubeke.';

  @override
  String get kycPrivacyLink => 'Funda isitatimende sobumfihlo';

  @override
  String get kycSendNote =>
      'Uhlelo lokusebenza alugcini inombolo ye-ID yakho noma isithombe ngemva kokuthi usithumele.';

  @override
  String get kycSubmit => 'Thumela ukuze kuhlolwe';

  @override
  String get kycSubmitting => 'Iyathumela…';

  @override
  String get kycSuccessTitle => 'Ukuhlolwa kwe-ID yakho kuthunyelwe';

  @override
  String get kycSuccessBody =>
      'Umhlinzeki wakho uzokuhlola. Sizokwazisa uma sekunesinqumo.';

  @override
  String get kycSuccessDone => 'Buka isimo';

  @override
  String get failureKycInvalidId => 'Hlola inombolo yakho ye-ID.';

  @override
  String get failureKycInvalidAddress => 'Hlola ikheli lakho.';

  @override
  String get failureKycDocumentRejected =>
      'Sebenzisa isithombe esicacile se-JPEG noma se-PNG esingaphansi kuka-5 MB.';

  @override
  String get failureKycUploadFailed =>
      'Asikwazanga ukulayisha idokhumenti yakho. Zama futhi.';

  @override
  String get failureKycRequired => 'Kudingeka ukuthi uqale ngokuhlolwa kwe-ID.';

  @override
  String get failureSubscriberProfileInvalid =>
      'Buyekeza imininingwane yakho yokuxhumana ngaphambi kokubhalisa.';

  @override
  String get failurePlanUnavailable => 'Lolu hlelo alisatholakali.';

  @override
  String get failureServiceState =>
      'Le sevisi ayikwazi ukushintshwa okwamanje.';

  @override
  String get failureNoActiveEntitlement =>
      'Udinga ipasi elisebenzayo ukuze uxhume ku-inthanethi.';

  @override
  String get failureMacInvalid =>
      'Asikwazanga ukuhlonza le divayisi. Xhuma ngekhasi lokungena le-Wi-Fi esikhundleni.';

  @override
  String get failureNasUnavailable =>
      'Le hotspot ayitholakali okwamanje. Zama enye.';

  @override
  String get failureLoginUrlInvalid =>
      'Ukungena kwale hotspot akukwazanga ukuvulwa. Xhuma ngekhasi lokungena le-Wi-Fi esikhundleni.';

  @override
  String get failureControllerNotSupported =>
      'Ukungena ngokuthinta kanye akuxhaswa kule hotspot. Xhuma ngekhasi lokungena le-Wi-Fi esikhundleni.';

  @override
  String get homeSubscriberHeading => 'I-inthanethi yakho yasekhaya';

  @override
  String homeInvoiceDue(String amount, String date) {
    return '$amount kufanele kukhokhwe ngo-$date';
  }

  @override
  String get homeInvoicePay => 'Khokha';

  @override
  String get homeInvoicesViewAll => 'Buka bonke odinga';

  @override
  String get plansTitle => 'Amaphakheji ngenyanga';

  @override
  String get plansShopCardSubtitle =>
      'I-inthanethi yasekhaya yomuzi wakho, ikhokhelwa ngenyanga';

  @override
  String get plansEmpty => 'Awekho amaphakheji atholakalayo okwamanje';

  @override
  String get planIdCheckChip => 'Kudingeka ukuhlolwa kwe-ID';

  @override
  String planSetupFee(String price) {
    return 'Imali yokusetha $price';
  }

  @override
  String planDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kufika kumadivayisi angu-$count',
      one: 'idivayisi eyi-1',
    );
    return '$_temp0';
  }

  @override
  String planFairUse(String amount) {
    return 'Ukusetshenziswa okufanele: $amount ngenyanga';
  }

  @override
  String planFairUseThrottle(String down, String up) {
    return 'Ngemva kwalokho, isivinini sehla siye ku-$down / $up Mbps';
  }

  @override
  String get planFairUseReduced =>
      'Ngemva kwalokho, isivinini sakho siyehliswa';

  @override
  String planGigabytes(String amount) {
    return '$amount GB';
  }

  @override
  String planBurst(String down, String up, int seconds) {
    return 'Ukuqhuma kuze kube ngu-$down / $up Mbps amasekhondi angu-$seconds';
  }

  @override
  String get planDetailTitle => 'Imininingwane yephakheji';

  @override
  String get planChoose => 'Khetha leli phakheji';

  @override
  String get planBackToPlans => 'Buyela emaphakhejini';

  @override
  String get servicesSeePlans => 'Buka amaphakheji';

  @override
  String get signupTitle => 'Qinisekisa ukubhalisa';

  @override
  String get signupFirstInvoiceNote =>
      'Inxephezelo yakho yokuqala ihlanganisa inyanga esele, kanye nanoma iyiphi imali yokusetha. Uyabona inani eliphelele ngaphambi kokuba ukhokhe.';

  @override
  String get signupAvailabilityNote =>
      'Umhlinzeki wakho uqinisekisa ukutholakala ekhelini lakho.';

  @override
  String get signupAddressLabel => 'Ikheli lokufakwa';

  @override
  String get signupAddressRequired => 'Faka ikheli lokufakwa.';

  @override
  String get signupTermsLabel => 'Ngiyayamukela imigomo nezimo';

  @override
  String get signupTermsRequired => 'Yamukela imigomo ukuze uqhubeke.';

  @override
  String get signupSubmit => 'Bhalisa';

  @override
  String get signupSubmitting => 'Iyabhalisa…';

  @override
  String get signupDoneTitle => 'Usubhalisiwe';

  @override
  String signupDoneInvoice(String number, String amount, String date) {
    return 'Inxephezelo yokuqala $number: $amount, kufanele ikhokhwe ngo-$date';
  }

  @override
  String get signupPayNow => 'Khokha manje';

  @override
  String get signupPayLater => 'Khokha kamuva';

  @override
  String get signupInstallationNote =>
      'Ngemva kokuthi ukhokhe, umhlinzeki wakho uzohlela ukufakwa nawe.';

  @override
  String get signupIdCheckNote =>
      'Leli phakheji lidinga ukuhlolwa kwe-ID ngaphambi kokuthi liqale.';

  @override
  String get signupAccountClosed =>
      'I-akhawunti yakho ivaliwe. Xhumana nomhlinzeki wakho.';

  @override
  String get failureProfileInvalid =>
      'Eminye imininingwane yakho yokuxhumana ayivumelekile. Yihlole bese uyazama futhi.';

  @override
  String get subscriberProfileTitle => 'Imininingwane yokuxhumana';

  @override
  String subscriberProfileAccountNo(String number) {
    return 'Inombolo ye-akhawunti $number';
  }

  @override
  String get subscriberProfileNameLabel => 'Igama ku-akhawunti yakho';

  @override
  String get subscriberProfileEmailLabel => 'I-imeyili';

  @override
  String get subscriberProfilePhoneLabel => 'Inombolo yeselula';

  @override
  String get subscriberProfileLanguageLabel => 'Ulimi lwezimiso';

  @override
  String get subscriberProfileNameInvalid =>
      'Faka igama lakho (kufika kuzinhlamvu ezingu-120).';

  @override
  String get subscriberProfileLoginNameInvalid =>
      'Faka igama lakho (kufika kuzinhlamvu ezingu-80).';

  @override
  String get subscriberProfileEmailInvalid =>
      'Faka ikheli le-imeyili elivumelekile.';

  @override
  String get subscriberProfilePhoneInvalid =>
      'Faka inombolo yeselula yaseNingizimu Afrika evumelekile.';

  @override
  String get subscriberProfileContactRequired =>
      'Gcina okungenani inombolo yeselula noma i-imeyili.';

  @override
  String get subscriberProfileFieldRejected => 'Hlola leli gama.';

  @override
  String get subscriberProfileLoginNote =>
      'Lena yimininingwane esiyisebenzisayo uma ubhalisa. Inombolo yakho yokungena ayinakushintshwa lapha.';

  @override
  String get subscriberProfileSave => 'Gcina izinguquko';

  @override
  String get subscriberProfileSaving => 'Iyagcina…';

  @override
  String get subscriberProfileSaved => 'Imininingwane yakho igcinwe.';

  @override
  String get signupUpdateContactDetails =>
      'Buyekeza imininingwane yakho yokuxhumana';

  @override
  String get serviceBannerKycChecking =>
      'Siyahlola i-ID yakho. Isevisi yakho ingaqala uma ukuhlolwa sekuqediwe.';

  @override
  String get hotspotLoginTitle => 'Xhumeka manje';

  @override
  String get hotspotLoginIntro =>
      'Qala uxhume kunethiwekhi ye-Wi-Fi yomhlinzeki wakho. Bese uthola imininingwane yakho yokungena lapha uyifake ekhasini lokungena le-Wi-Fi.';

  @override
  String get hotspotLoginGetDetails => 'Thola imininingwane yokungena';

  @override
  String get hotspotLoginUsername => 'Igama lomsebenzisi';

  @override
  String get hotspotLoginPassword => 'Iphasiwedi';

  @override
  String get hotspotLoginShowPassword => 'Bonisa iphasiwedi';

  @override
  String get hotspotLoginHidePassword => 'Fihla iphasiwedi';

  @override
  String get hotspotLoginCopyUsername => 'Kopisha igama lomsebenzisi';

  @override
  String get hotspotLoginCopyPassword => 'Kopisha iphasiwedi';

  @override
  String get hotspotLoginCopied =>
      'Kukopishiwe. Siyikhipha ku-clipboard yakho ngemuva komzuzu.';

  @override
  String hotspotLoginValidFor(String time) {
    return 'Isikhathi esisele: $time';
  }

  @override
  String get hotspotLoginExpired =>
      'Le mininingwane yokungena iphelelwe isikhathi.';

  @override
  String get hotspotLoginGetNew => 'Thola imininingwane emisha yokungena';

  @override
  String get hotspotLoginOpenPortal => 'Vula ikhasi lokungena le-Wi-Fi';

  @override
  String get hotspotLoginOpenPortalFailed =>
      'Asikwazanga ukuvula isiphequluli sakho.';

  @override
  String get hotspotLoginUseOnce =>
      'Sebenzisa le mininingwane kule foni kuphela. Isebenza kanye.';
}
