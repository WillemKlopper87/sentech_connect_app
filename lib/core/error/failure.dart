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
  const ValidationFailure(super.message, [this.code]);

  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// No valid session: the customer must sign in again.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Your session has ended. Sign in again.']);
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
