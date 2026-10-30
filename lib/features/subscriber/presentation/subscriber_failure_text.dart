import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';

/// Customer text for a failed subscriber action: offline wording for
/// [NetworkFailure], the typed copy for a known refusal, else the localised
/// owned message.
String subscriberFailureText(AppLocalizations l10n, Failure failure) {
  if (failure is NetworkFailure) return l10n.failureYouReOfflineCheckYourConnection;
  return typedFailureText(l10n, failure) ?? localizedFailureText(l10n, failure.message);
}
