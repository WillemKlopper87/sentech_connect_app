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
  String get signedOutProviderUnavailable =>
      'Your provider is currently unavailable, so you have been signed out. Please try again later.';

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
  String get accountAppearance => 'Appearance';

  @override
  String get accountDataSaver => 'Data saver: fewer pictures and no animations';

  @override
  String get accountDataSaverSaveFailed =>
      'Could not save Data saver. Try again.';

  @override
  String get accountThemeSystem => 'Match device setting';

  @override
  String get accountThemeLight => 'Light';

  @override
  String get accountThemeDark => 'Dark';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountLanguageSystem => 'Match device language';

  @override
  String get accountLogOut => 'Log out';

  @override
  String get accountLogOutTitle => 'Log out?';

  @override
  String get accountLogOutBody => 'You can log back in at any time.';

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
  String get supportComposeTitle => 'Message support';

  @override
  String get supportTopicLabel => 'Topic';

  @override
  String get supportTopicConnecting => 'Connecting to Wi-Fi';

  @override
  String get supportTopicPayment => 'Payment';

  @override
  String get supportTopicPass => 'My pass';

  @override
  String get supportTopicAccount => 'My account';

  @override
  String get supportTopicOther => 'Other';

  @override
  String get supportContactKindEmail => 'Email';

  @override
  String get supportContactKindPhone => 'Mobile';

  @override
  String get supportContactEmailLabel => 'Your email address';

  @override
  String get supportContactPhoneLabel => 'Your mobile number';

  @override
  String get supportMessageLabel => 'Your message';

  @override
  String get supportOrderRefLabel => 'Order reference (optional)';

  @override
  String get supportSendMessage => 'Send message';

  @override
  String get supportSentTitle => 'Message sent';

  @override
  String get supportSentBody =>
      'We have your message. Quote this reference if you contact support again.';

  @override
  String supportSentReference(String reference) {
    return 'Reference: $reference';
  }

  @override
  String get supportDone => 'Done';

  @override
  String get supportIssueMessageTooShort => 'Write at least 10 characters.';

  @override
  String get supportIssueMessageTooLong =>
      'Keep your message under 2000 characters.';

  @override
  String get supportIssueOrderRef =>
      'An order reference has letters, numbers and dashes only (4 to 40).';

  @override
  String get supportEmailInstead => 'Email us instead';

  @override
  String get consentTitle => 'Your privacy';

  @override
  String get consentLocationBody =>
      'We use your phone\'s location once to check 5G coverage at your address. It is not stored on your phone or kept after the check.';

  @override
  String get consentLocationMapService =>
      'To turn your location into an address, your phone\'s map service (Google or Apple) looks it up.';

  @override
  String get coverageAddressLookupNotice =>
      'Your phone\'s map service (Google or Apple) finds the address you type.';

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
  String get paymentBackToDashboard => 'Back to Home';

  @override
  String get accountSwitchProvider => 'Switch WiFi provider';

  @override
  String get servicesHomeInternetHeading => 'Home internet';

  @override
  String get servicesTitle => 'My services';

  @override
  String get servicesEmpty => 'You have no home internet service yet';

  @override
  String get servicesPastTitle => 'Past services';

  @override
  String get serviceDetailTitle => 'Service details';

  @override
  String get serviceStatusPending => 'Starting';

  @override
  String get serviceStatusActive => 'Active';

  @override
  String get serviceStatusSuspended => 'Suspended';

  @override
  String get serviceStatusCancelled => 'Ended';

  @override
  String get serviceKindHotspot => 'Home hotspot';

  @override
  String get serviceKindFixedWireless => 'Fixed wireless';

  @override
  String servicePricePerMonth(String price) {
    return '$price a month';
  }

  @override
  String serviceSpeeds(String down, String up) {
    return 'Down $down Mbps, up $up Mbps';
  }

  @override
  String serviceNumber(String number) {
    return 'Service $number';
  }

  @override
  String servicePaidUntil(String date) {
    return 'Paid until $date';
  }

  @override
  String serviceEndsOn(String date) {
    return 'Ends on $date';
  }

  @override
  String serviceEndedOn(String date) {
    return 'Ended on $date';
  }

  @override
  String get serviceCancelScheduledTitle => 'Cancellation scheduled';

  @override
  String servicePlanChangeOn(String plan, String date) {
    return 'Plan change to $plan on $date';
  }

  @override
  String servicePlanChangeScheduled(String date) {
    return 'A plan change is scheduled for $date';
  }

  @override
  String get serviceFactPlan => 'Plan';

  @override
  String get serviceFactType => 'Type';

  @override
  String get serviceFactPrice => 'Price';

  @override
  String get serviceFactSpeed => 'Speed';

  @override
  String get serviceFactNumber => 'Service number';

  @override
  String get serviceFactPaidThrough => 'Paid until';

  @override
  String get serviceBannerFirstInvoiceUnpaid =>
      'Pay your first invoice to start';

  @override
  String get serviceBannerKycRequired => 'We need to check your ID';

  @override
  String get serviceBannerAwaitingInstallation =>
      'Waiting for installation by your provider';

  @override
  String get serviceBannerCustomerLinkRequired =>
      'Your account is not linked to your provider yet. Contact your provider.';

  @override
  String get serviceBannerContractRequired =>
      'Your service contract is not signed yet. Contact your provider.';

  @override
  String get serviceBannerActivating =>
      'Activating, this can take a few minutes. Pull to refresh.';

  @override
  String get serviceBannerProviderSettingUp =>
      'Your provider is setting this up';

  @override
  String get serviceBannerSuspendedNonPayment =>
      'Pay your open invoice to restore service';

  @override
  String get serviceBannerSuspendedKyc =>
      'We need to check your ID before service can resume';

  @override
  String get serviceBannerSuspendedProvider =>
      'Paused by your provider. Contact support.';

  @override
  String get serviceActionViewInvoices => 'View invoices';

  @override
  String get serviceActionIdCheck => 'Start ID check';

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
  String get hotspotsStatusMaintenance => 'Under maintenance';

  @override
  String get hotspotsEmpty => 'No hotspots are listed yet. Check back soon.';

  @override
  String get orderCancelAction => 'Cancel order';

  @override
  String get orderCancelConfirmTitle => 'Cancel this order?';

  @override
  String get orderCancelConfirmBody =>
      'This order will be closed. You can place a new order any time.';

  @override
  String get orderCancelKeep => 'Keep order';

  @override
  String get invoicesTitle => 'Invoices';

  @override
  String get invoicesEmptyTitle => 'No invoices yet';

  @override
  String get invoicesEmptyBody =>
      'Invoices for your home internet service will show here.';

  @override
  String get invoicesOpenSection => 'To pay';

  @override
  String get invoicesEarlierSection => 'Earlier invoices';

  @override
  String get invoiceStatusOpen => 'Due';

  @override
  String get invoiceStatusPaid => 'Paid';

  @override
  String get invoiceStatusVoid => 'Cancelled';

  @override
  String get invoiceStatusWrittenOff => 'Written off';

  @override
  String get invoiceKindInitial => 'First invoice';

  @override
  String get invoiceKindRecurring => 'Monthly invoice';

  @override
  String get invoiceKindProration => 'Plan change';

  @override
  String get invoiceKindReactivation => 'Reactivation';

  @override
  String get invoiceKindAdjustment => 'Adjustment';

  @override
  String get invoiceKindOther => 'Invoice';

  @override
  String invoiceDueOn(String date) {
    return 'Due $date';
  }

  @override
  String invoiceIssuedOn(String date) {
    return 'Issued $date';
  }

  @override
  String invoicePaidOn(String date) {
    return 'Paid $date';
  }

  @override
  String get invoiceDetailTitle => 'Invoice';

  @override
  String invoicePeriod(String start, String end) {
    return 'Period: $start to $end';
  }

  @override
  String get invoiceLinesHeading => 'What you are paying for';

  @override
  String invoiceLineQuantity(String quantity, String price) {
    return '$quantity x $price';
  }

  @override
  String get invoiceTotal => 'Total';

  @override
  String invoiceIncludesVat(String amount) {
    return 'Includes VAT of $amount';
  }

  @override
  String get invoiceAmountPaid => 'Paid so far';

  @override
  String get invoicePartPaid =>
      'Part of this invoice is already paid. Contact support to settle the rest.';

  @override
  String get invoiceVoidNote => 'This invoice was cancelled. Nothing is due.';

  @override
  String get invoiceWrittenOffNote =>
      'This invoice was written off. Nothing is due.';

  @override
  String invoicePayNow(String amount) {
    return 'Pay $amount';
  }

  @override
  String get invoicePayOnSecurePage =>
      'You pay on your payment provider\'s secure page.';

  @override
  String get invoiceConfirming =>
      'Confirming your payment. This can take a moment.';

  @override
  String get invoiceStillPending =>
      'We have not heard back from the payment provider yet. If you paid, this invoice will update soon.';

  @override
  String get invoicePaidTitle => 'Payment received';

  @override
  String get invoicePaidThanks => 'Thank you. This invoice is paid.';

  @override
  String get invoicePaidKyc =>
      'We need to check your ID before your service starts.';

  @override
  String get invoicePaidInstallation =>
      'Waiting for installation by your provider.';

  @override
  String get invoicePaidContactProvider =>
      'Your service cannot start yet. Contact your provider.';

  @override
  String get invoicePaidActivating =>
      'Your service is starting. This can take a few minutes. Pull to refresh.';

  @override
  String get invoicePaidSettingUp =>
      'Your provider is setting up your service.';

  @override
  String get invoiceCollectionExternal =>
      'Your provider collects payment for this invoice directly.';

  @override
  String get invoiceBackToInvoices => 'Back to invoices';

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
  String get passesStatusSuspended => 'Service suspended';

  @override
  String otpUseSmsReference(String reference) {
    return 'Use the SMS that shows reference $reference.';
  }

  @override
  String get failureBindingRequired =>
      'Sign-in could not be completed. Please update the app and try again.';

  @override
  String get failureHumanVerificationFailed =>
      'We could not confirm that you are a person. Please try again.';

  @override
  String get failureHumanVerificationUnavailable =>
      'The security check is not available right now. Please try again in a moment.';

  @override
  String failureHumanVerificationUnavailableSeconds(int seconds) {
    return 'The security check is not available right now. Please try again in $seconds seconds.';
  }

  @override
  String failureHumanVerificationUnavailableMinutes(int minutes) {
    return 'The security check is not available right now. Please try again in $minutes minutes.';
  }

  @override
  String get failureReauthRequired =>
      'That code did not work. Check it and try again.';

  @override
  String get failureSmsUnavailable =>
      'We could not send the SMS. Please try again in a moment.';

  @override
  String get failureConsentVersionOutdated =>
      'The terms were updated. Please review and accept the latest version.';

  @override
  String get failureSubscriberNotFound =>
      'We could not find a service account for you with this provider.';

  @override
  String get failureActiveServiceExists =>
      'You still have an active service. Cancel it first, or contact your provider.';

  @override
  String get failureDeleteContactSupport =>
      'We cannot send a code to this account. Contact support to delete your account.';

  @override
  String get accountDeleteSendCode => 'Send me a code';

  @override
  String get accountDeleteCodeTitle => 'Enter the code we sent you';

  @override
  String get accountDeleteCodeBody =>
      'For your safety we sent a 6-digit code by SMS to the number on your account. Enter it to delete your account and all your data. This cannot be undone.';

  @override
  String get accountDeleteClose => 'Close';

  @override
  String get passesSuspendedNote =>
      'Your provider has paused this service. Contact them to get it back.';

  @override
  String get humanCheckTitle => 'Quick check: confirm you are a person';

  @override
  String get humanCheckBody =>
      'This keeps automated sign-ups out. It usually takes a second.';

  @override
  String get humanCheckLoading => 'Loading the check…';

  @override
  String get humanCheckChallenge => 'Please complete the check below.';

  @override
  String get humanCheckFailedNetwork =>
      'We could not load the check. Check your connection and try again.';

  @override
  String get humanCheckFailedWidget =>
      'The check did not work this time. Please try again.';

  @override
  String get humanCheckFailedTimeout =>
      'The check took too long. Please try again.';

  @override
  String get humanCheckRetry => 'Try again';

  @override
  String get humanCheckCancel => 'Cancel';

  @override
  String get humanCheckWidgetLabel => 'Security check';

  @override
  String get humanCheckHelp =>
      'Still stuck? Cancel and sign in on the website, or contact support.';

  @override
  String get failureFeatureDisabled =>
      'This is not available from your provider.';

  @override
  String get failureOrderNotCancellable =>
      'This order can no longer be cancelled.';

  @override
  String get failureOrderCancelled => 'This order was cancelled.';

  @override
  String get failureSupportUnavailable =>
      'Support messages are not available right now. Please try again later.';

  @override
  String get failureSupportContactNotConfigured =>
      'Your provider has not set up support messages yet.';

  @override
  String get failureInvalidMessage => 'Check your message and try again.';

  @override
  String get failureInvalidContact =>
      'Check your contact details and try again.';

  @override
  String get failureInvoiceNotPayable => 'This invoice can no longer be paid.';

  @override
  String get failureCustomerLinkRequired =>
      'Your account is not linked to your provider yet. Contact your provider.';

  @override
  String get failureAccountProblem =>
      'There is a problem with your account. Contact your provider.';

  @override
  String get failureSubscriberProfileInvalid =>
      'Update your contact details before signing up.';

  @override
  String get failurePlanUnavailable => 'This plan is no longer available.';

  @override
  String get failureServiceState => 'This service can\'t be changed right now.';

  @override
  String get failureNoActiveEntitlement =>
      'You need an active pass to get online.';

  @override
  String get failureMacInvalid =>
      'We could not identify this device. Connect from the Wi-Fi login page instead.';

  @override
  String get failureNasUnavailable =>
      'This hotspot is not available right now. Try another one.';

  @override
  String get failureLoginUrlInvalid =>
      'This hotspot login could not be opened. Connect from the Wi-Fi login page instead.';

  @override
  String get failureControllerNotSupported =>
      'One-tap login is not supported at this hotspot. Connect from the Wi-Fi login page instead.';
}
