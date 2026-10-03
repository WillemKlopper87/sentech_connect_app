import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';

/// Internal const failure text is mapped to owned ARB copy at the UI boundary.
/// Unrecognized server/user text remains external data.
String localizedFailureText(AppLocalizations l10n, String message) {
  final english = AppLocalizationsEn();
  final owned = <String, String>{
    english.failureNotAllowed: l10n.failureNotAllowed,
    english.failureNoInternetConnection: l10n.failureNoInternetConnection,
    english.failureSomethingWentWrongOnOurEnd:
        l10n.failureSomethingWentWrongOnOurEnd,
    english.failureThisAddressIsNotYetInOur:
        l10n.failureThisAddressIsNotYetInOur,
    english.failureWeCouldNotFinishSigningYouIn:
        l10n.failureWeCouldNotFinishSigningYouIn,
    english.failureYourSessionHasEndedSignInAgain:
        l10n.failureYourSessionHasEndedSignInAgain,
    english.failureThisProviderIsCurrentlyUnavailable:
        l10n.failureThisProviderIsCurrentlyUnavailable,
    english.failureWeCouldNotFindThat: l10n.failureWeCouldNotFindThat,
    english.failureTooManyAttemptsPleaseWaitAndTry:
        l10n.failureTooManyAttemptsPleaseWaitAndTry,
    english.failureWeReceivedAnUnexpectedResponsePleaseTry:
        l10n.failureWeReceivedAnUnexpectedResponsePleaseTry,
    english.failureTheRequestWasCancelled: l10n.failureTheRequestWasCancelled,
    english.failureWeCouldNotMakeASecureConnection:
        l10n.failureWeCouldNotMakeASecureConnection,
    english.failureBlockedARequestToAnUnexpectedAddress:
        l10n.failureBlockedARequestToAnUnexpectedAddress,
    english.failureEnterAValidSouthAfricanMobileNumber:
        l10n.failureEnterAValidSouthAfricanMobileNumber,
    english.failureEnterThe6DigitCode: l10n.failureEnterThe6DigitCode,
    english.failureCouldNotSaveYourDetailsOnThis:
        l10n.failureCouldNotSaveYourDetailsOnThis,
    english.failureCouldNotReadYourSavedDetails:
        l10n.failureCouldNotReadYourSavedDetails,
    english.failureTheCodeIsInvalidOrHasExpired:
        l10n.failureTheCodeIsInvalidOrHasExpired,
    english.failureYourSessionCouldNotBeVerifiedSign:
        l10n.failureYourSessionCouldNotBeVerifiedSign,
    english.failureWeCouldNotLoadTheCompleteCatalogue:
        l10n.failureWeCouldNotLoadTheCompleteCatalogue,
    english.failureYourCartIsEmpty: l10n.failureYourCartIsEmpty,
    english.failureWeCouldNotLoadYourOpenOrder:
        l10n.failureWeCouldNotLoadYourOpenOrder,
    english.failureIdentityChecksAreNotNeededForThis:
        l10n.failureIdentityChecksAreNotNeededForThis,
    english.failureWeCouldNotFindThatOrder: l10n.failureWeCouldNotFindThatOrder,
    english.failureThisOrderWasReplacedByANewer:
        l10n.failureThisOrderWasReplacedByANewer,
    english.failureThisOrderCanNoLongerBePaid:
        l10n.failureThisOrderCanNoLongerBePaid,
    english.failureVerifyYourIdentityBeforePaying:
        l10n.failureVerifyYourIdentityBeforePaying,
    english.failureThePaymentWasNotCompletedYouHave:
        l10n.failureThePaymentWasNotCompletedYouHave,
    english.failureWeCouldNotOpenThePaymentPage:
        l10n.failureWeCouldNotOpenThePaymentPage,
    english.failureWeCouldNotLoadAllOfYour: l10n.failureWeCouldNotLoadAllOfYour,
    english.failureWeCouldNotLoadTheLegalDocuments:
        l10n.failureWeCouldNotLoadTheLegalDocuments,
    english.failureCouldNotSaveYourConsentOnThis:
        l10n.failureCouldNotSaveYourConsentOnThis,
    english.failureCouldNotSaveYourChoiceOnThis:
        l10n.failureCouldNotSaveYourChoiceOnThis,
    english.failureUnknownProvider: l10n.failureUnknownProvider,
    english.failureSomethingWentWrongPleaseTryAgain:
        l10n.failureSomethingWentWrongPleaseTryAgain,
    english.failureYourPhoneSDateOrTimeLooks:
        l10n.failureYourPhoneSDateOrTimeLooks,
    english.failureYouAlreadyHaveAFreeWifiSession:
        l10n.failureYouAlreadyHaveAFreeWifiSession,
    english.failureYouVeReachedTodaySFreeWifi:
        l10n.failureYouVeReachedTodaySFreeWifi,
  };
  return owned[message] ?? message;
}
