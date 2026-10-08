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
  String get accountDataSaver => 'Data saver: fewer pictures and no animations';

  @override
  String get accountDataSaverSaveFailed =>
      'Could not save Data saver. Try again.';

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
}
