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
  String get loginPasswordHint => 'Wagwoord';

  @override
  String get loginButton => 'Teken in';

  @override
  String get loginCreateAccount => 'Nuut by Sentech? Skep \'n rekening';

  @override
  String get biometricPromptReason =>
      'Bevestig dat dit jy is om by Sentech Connect in te teken';

  @override
  String get biometricNotEnrolled =>
      'Geen vingerafdruk of gesig is op hierdie foon opgestel nie. Voeg een in die stelselinstellings by, of teken met jou wagwoord in.';

  @override
  String get biometricUnavailable =>
      'Biometrie is tans nie beskikbaar nie. Teken met jou wagwoord in.';

  @override
  String get biometricLockedOut =>
      'Te veel pogings. Wag \'n oomblik en probeer weer, of teken met jou wagwoord in.';

  @override
  String get biometricPermanentlyLockedOut =>
      'Biometrie is gesluit. Ontsluit eers jou foon met jou PIN of patroon, of teken met jou wagwoord in.';

  @override
  String get biometricFailed =>
      'Biometriese kontrole het misluk. Probeer weer of teken met jou wagwoord in.';

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
  String get accountProvider => 'PROVIDER';

  @override
  String get accountChangeProvider => 'Change provider';
}
