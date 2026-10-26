import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// Something failed on the server side. [requestId] (from the problem body
/// or the `X-Request-ID` header) lets support find the server log line.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end.', this.requestId]);

  final String? requestId;

  @override
  List<Object?> get props => [message, requestId];
}

class NotCoveredFailure extends Failure {
  const NotCoveredFailure([super.message = 'This address is not yet in our coverage area.']);
}

/// The request was understood but refused (4xx). [code] is the API's
/// machine-readable problem code (e.g. `otp_invalid`), or a local code for
/// checks done before calling the API (e.g. `invalid_phone`).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [this.code, this.messageIsDetail = true]);

  final String? code;

  /// False when [message] is only the problem's short `title` (e.g.
  /// "Conflict"), which is not fit to show a customer on its own.
  final bool messageIsDetail;

  @override
  List<Object?> get props => [message, code, messageIsDetail];
}

/// The one-time code was accepted (and is spent) but the session could not be
/// set up on this device; the customer must request a new code.
class SessionSetupFailure extends Failure {
  const SessionSetupFailure([super.message = 'We could not finish signing you in. Please try again.']);
}

/// No valid session: the customer must sign in again.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Your session has ended. Sign in again.']);
}

/// The customer's provider (tenant) is suspended (403 `tenant_suspended`):
/// nothing will work until it is reinstated, so the session is ended with a
/// "provider unavailable" notice instead of failing every call.
class ProviderUnavailableFailure extends Failure {
  const ProviderUnavailableFailure([super.message = 'This provider is currently unavailable.']);
}

/// The provider does not offer this module (403 `module_not_enabled`). [module]
/// is the key the server named, when it sent a valid one.
class ModuleDisabledFailure extends Failure {
  const ModuleDisabledFailure([this.module, super.message = 'This is not offered by your provider.']);

  final String? module;

  @override
  List<Object?> get props => [message, module];
}

/// The provider collects payment itself (409 `collection_external`): the app
/// must not offer a way to pay. Not retryable; show who to contact instead.
class CollectionExternalFailure extends Failure {
  const CollectionExternalFailure([super.message = 'Buy this from your provider directly.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'We could not find that.']);
}

class RateLimitedFailure extends Failure {
  const RateLimitedFailure([super.message = 'Too many attempts. Please wait and try again.', this.retryAfter]);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, retryAfter];
}

// Typed refusals the platform sends with a stable problem `code`. Each carries
// its own default English text (the "owned" source text localised by
// `lib/l10n/failure_copy.dart`); the server's own wording is not shown for
// these, so the copy is the same in every language.

/// 422 `binding_required`: staging and prod want the sign-in binding. The app
/// always sends one, so seeing this means an old or altered build.
class BindingRequiredFailure extends ValidationFailure {
  const BindingRequiredFailure()
      : super('Sign-in could not be completed. Please update the app and try again.', 'binding_required', false);
}

/// 403 `human_verification_failed`: the human check token was missing, wrong
/// or expired. (The app has no way to produce one yet; see docs/BACKEND_CONTRACT_SYNC.md.)
class HumanVerificationFailedFailure extends Failure {
  const HumanVerificationFailedFailure([super.message = 'We could not confirm that you are a person. Please try again.']);
}

/// 503 `human_verification_unavailable`: the check provider is down. Retry
/// later; [retryAfter] is the server's `Retry-After`, when it sent one.
class HumanVerificationUnavailableFailure extends Failure {
  const HumanVerificationUnavailableFailure([this.retryAfter, super.message = 'The security check is not available right now. Please try again in a moment.']);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, retryAfter];
}

/// The customer closed the human check (Quick check sheet) without finishing
/// it. Nothing was sent. The screens return to where they were and show no
/// error. The default text reuses the localised "The request was cancelled."
class HumanCheckCancelledFailure extends Failure {
  const HumanCheckCancelledFailure([super.message = 'The request was cancelled.']);
}

/// 403 `reauth_required`: the fresh code for a sensitive action (deleting the
/// account) was missing, wrong, used or expired. Nothing was changed.
class ReauthRequiredFailure extends Failure {
  const ReauthRequiredFailure([super.message = 'That code did not work. Check it and try again.']);
}

/// 503 `sms_unavailable`: the code could not be sent by SMS right now.
class SmsUnavailableFailure extends Failure {
  const SmsUnavailableFailure([this.retryAfter, super.message = 'We could not send the SMS. Please try again in a moment.']);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, retryAfter];
}

/// 422 `consent_version_outdated`: the terms or privacy version the app sent
/// is no longer current; reload the legal documents and ask again.
class ConsentVersionOutdatedFailure extends ValidationFailure {
  const ConsentVersionOutdatedFailure()
      : super('The terms were updated. Please review and accept the latest version.', 'consent_version_outdated', false);
}

/// 404 `subscriber_not_found`: this customer has no subscriber record with
/// the provider (they have not signed up for a service).
class SubscriberNotFoundFailure extends NotFoundFailure {
  const SubscriberNotFoundFailure([super.message = 'We could not find a service account for you with this provider.']);
}

/// 409 `active_service_exists`: refused because the customer still has an
/// active service (for example deleting the account, or signing up twice).
class ActiveServiceExistsFailure extends ValidationFailure {
  const ActiveServiceExistsFailure()
      : super('You still have an active service. Cancel it first, or contact your provider.', 'active_service_exists', false);
}

/// 409 `order_not_payable`: the order is no longer payable (paid, expired,
/// cancelled or replaced). Keeps the server's customer-facing detail when it
/// sent one; still a [ValidationFailure] with code `order_not_payable`.
class OrderNotPayableFailure extends ValidationFailure {
  const OrderNotPayableFailure([String message = 'This order can no longer be paid.', bool messageIsDetail = false])
      : super(message, 'order_not_payable', messageIsDetail);
}

/// `POST /v1/me/delete-challenge` answered 401: the account has no phone
/// number to send the re-check code to (or no longer exists). The customer is
/// NOT signed out; they are told to contact support to delete the account.
class DeleteCodeUnavailableFailure extends Failure {
  const DeleteCodeUnavailableFailure([super.message = 'We cannot send a code to this account. Contact support to delete your account.']);
}
