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

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'We could not find that.']);
}

class RateLimitedFailure extends Failure {
  const RateLimitedFailure([super.message = 'Too many attempts. Please wait and try again.', this.retryAfter]);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, retryAfter];
}
