import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

/// The generic [ServerFailure] texts the API client uses when the response had
/// no customer-facing detail (a 5xx, a body it could not read). They are not
/// shown; the localised generic message is.
const _genericServerTexts = {
  'Something went wrong on our end.',
  'We received an unexpected response. Please try again.',
};

/// Customer-facing text for a failed delete/export request.
///
/// The API writes the `detail` of its 4xx problem responses for customers
/// (e.g. why a deletion is refused with 409/422, or a 403), and the API client
/// carries it in the failure: that detail is shown. Everything else (offline,
/// rate limits, 5xx, anything unknown) gets a localised message.
String privacyFailureMessage(AppLocalizations l10n, Failure? failure) {
  return switch (failure) {
    NetworkFailure() => l10n.accountRequestOffline,
    RateLimitedFailure() => l10n.accountRequestRateLimited,
    ValidationFailure(:final message, :final messageIsDetail) when messageIsDetail && message.trim().isNotEmpty => message,
    ServerFailure(:final message) when message.trim().isNotEmpty && !_genericServerTexts.contains(message) => message,
    _ => l10n.accountRequestFailed,
  };
}
