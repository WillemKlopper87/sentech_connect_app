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
  String get demoPromotion1Expiry => '31 Aug';

  @override
  String get demoPromotion2Title => 'Refer a friend';

  @override
  String get demoPromotion2Description =>
      'Give a friend a free installation — you both get 10GB bonus data.';

  @override
  String get demoPromotion2Badge => 'REFERRAL';

  @override
  String get demoPromotion2Expiry => 'Ongoing';

  @override
  String get demoPromotion3Title => 'Loyalty reward';

  @override
  String get demoPromotion3Description =>
      'You\'ve earned enough points for a free Wi-Fi voucher. Redeem it in Vouchers.';

  @override
  String get demoPromotion3Badge => 'LOYALTY';

  @override
  String get demoPromotion3Expiry => '15 Sep';

  @override
  String get supportChatGreeting => 'Hi Sentech, I need help with my account.';

  @override
  String supportEmailSubject(String category) {
    return '[$category] Support request';
  }

  @override
  String get homePromotionsLabel =>
      'Promotions & loyalty — see what\'s on offer';

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
}
