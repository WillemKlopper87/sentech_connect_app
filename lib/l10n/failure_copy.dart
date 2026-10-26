import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

/// Stable source/default text identifies owned failures at the UI boundary.
/// Lookup keys follow the producers, independently of ARB display wording.
/// Unrecognized server/user text remains external data.
String localizedFailureText(AppLocalizations l10n, String message) {
  final owned = <String, String>{
    "You are not allowed to do that.": l10n.failureNotAllowed,
    "No internet connection.": l10n.failureNoInternetConnection,
    "Something went wrong on our end.": l10n.failureSomethingWentWrongOnOurEnd,
    "This address is not yet in our coverage area.":
        l10n.failureThisAddressIsNotYetInOur,
    "We could not finish signing you in. Please try again.":
        l10n.failureWeCouldNotFinishSigningYouIn,
    "Your session has ended. Sign in again.":
        l10n.failureYourSessionHasEndedSignInAgain,
    "This provider is currently unavailable.":
        l10n.failureThisProviderIsCurrentlyUnavailable,
    "This is not offered by your provider.":
        l10n.failureNotOfferedByProvider,
    "Buy this from your provider directly.":
        l10n.failureBuyFromProviderDirectly,
    "We could not find that.": l10n.failureWeCouldNotFindThat,
    "Too many attempts. Please wait and try again.":
        l10n.failureTooManyAttemptsPleaseWaitAndTry,
    "We received an unexpected response. Please try again.":
        l10n.failureWeReceivedAnUnexpectedResponsePleaseTry,
    "The request was cancelled.": l10n.failureTheRequestWasCancelled,
    "We could not make a secure connection. Check your network and try again.":
        l10n.failureWeCouldNotMakeASecureConnection,
    "Blocked a request to an unexpected address.":
        l10n.failureBlockedARequestToAnUnexpectedAddress,
    "Enter a valid South African mobile number.":
        l10n.failureEnterAValidSouthAfricanMobileNumber,
    "Enter the 6-digit code.": l10n.failureEnterThe6DigitCode,
    "Could not save your details on this device.":
        l10n.failureCouldNotSaveYourDetailsOnThis,
    "Could not read your saved details.":
        l10n.failureCouldNotReadYourSavedDetails,
    "The code is invalid or has expired.":
        l10n.failureTheCodeIsInvalidOrHasExpired,
    "Your session could not be verified. Sign in again.":
        l10n.failureYourSessionCouldNotBeVerifiedSign,
    "We could not load the complete catalogue. Please try again.":
        l10n.failureWeCouldNotLoadTheCompleteCatalogue,
    "Your cart is empty.": l10n.failureYourCartIsEmpty,
    "We could not load your open order. Please try again.":
        l10n.failureWeCouldNotLoadYourOpenOrder,
    "Identity checks are not needed for this order.":
        l10n.failureIdentityChecksAreNotNeededForThis,
    "We could not find that order.": l10n.failureWeCouldNotFindThatOrder,
    "This order was replaced by a newer one and can no longer be paid.":
        l10n.failureThisOrderWasReplacedByANewer,
    "This order can no longer be paid.": l10n.failureThisOrderCanNoLongerBePaid,
    "Verify your identity before paying.":
        l10n.failureVerifyYourIdentityBeforePaying,
    "The payment was not completed. You have not been charged.":
        l10n.failureThePaymentWasNotCompletedYouHave,
    "We could not open the payment page safely.":
        l10n.failureWeCouldNotOpenThePaymentPage,
    "We could not load all of your passes. Please try again.":
        l10n.failureWeCouldNotLoadAllOfYour,
    "We could not load the legal documents. Try again.":
        l10n.failureWeCouldNotLoadTheLegalDocuments,
    "Could not save your consent on this device.":
        l10n.failureCouldNotSaveYourConsentOnThis,
    "Could not save your choice on this device.":
        l10n.failureCouldNotSaveYourChoiceOnThis,
    "Unknown provider.": l10n.failureUnknownProvider,
    "Something went wrong. Please try again.":
        l10n.failureSomethingWentWrongPleaseTryAgain,
    "Your phone's date or time looks wrong. Set it to automatic and try again.":
        l10n.failureYourPhoneSDateOrTimeLooks,
    "You already have a free WiFi session running.":
        l10n.failureYouAlreadyHaveAFreeWifiSession,
    "You've reached today's free WiFi limit.":
        l10n.failureYouVeReachedTodaySFreeWifi,
    ...typedFailureTexts(l10n),
  };
  return owned[message] ?? message;
}

/// The platform's typed refusals (`binding_required`, `reauth_required`, ...)
/// keyed by their fixed English default text, so the message-only path
/// ([localizedFailureText]) localises them too.
Map<String, String> typedFailureTexts(AppLocalizations l10n) => {
  const BindingRequiredFailure().message: l10n.failureBindingRequired,
  const HumanVerificationFailedFailure().message:
      l10n.failureHumanVerificationFailed,
  const HumanVerificationUnavailableFailure().message:
      l10n.failureHumanVerificationUnavailable,
  const ReauthRequiredFailure().message: l10n.failureReauthRequired,
  const SmsUnavailableFailure().message: l10n.failureSmsUnavailable,
  const ConsentVersionOutdatedFailure().message:
      l10n.failureConsentVersionOutdated,
  const SubscriberNotFoundFailure().message: l10n.failureSubscriberNotFound,
  const ActiveServiceExistsFailure().message: l10n.failureActiveServiceExists,
};

/// Customer text for a typed refusal, or null when [failure] is not one (the
/// caller then uses its own mapping). Knows the `Retry-After` hint of
/// `human_verification_unavailable`.
String? typedFailureText(AppLocalizations l10n, Failure? failure) {
  switch (failure) {
    case BindingRequiredFailure():
      return l10n.failureBindingRequired;
    case HumanVerificationFailedFailure():
      return l10n.failureHumanVerificationFailed;
    case HumanVerificationUnavailableFailure(:final retryAfter):
      if (retryAfter == null || retryAfter <= Duration.zero) {
        return l10n.failureHumanVerificationUnavailable;
      }
      return retryAfter.inSeconds < 120
          ? l10n.failureHumanVerificationUnavailableSeconds(retryAfter.inSeconds)
          : l10n.failureHumanVerificationUnavailableMinutes(
              (retryAfter.inSeconds / 60).ceil(),
            );
    case ReauthRequiredFailure():
      return l10n.failureReauthRequired;
    case SmsUnavailableFailure():
      return l10n.failureSmsUnavailable;
    case ConsentVersionOutdatedFailure():
      return l10n.failureConsentVersionOutdated;
    case SubscriberNotFoundFailure():
      return l10n.failureSubscriberNotFound;
    case ActiveServiceExistsFailure():
      return l10n.failureActiveServiceExists;
    default:
      return null;
  }
}
