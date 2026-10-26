import 'package:equatable/equatable.dart';

/// A one-time code sent by SMS (`POST /v1/auth/otp/request`, and
/// `POST /v1/me/delete-challenge` for the delete-account re-check).
class OtpChallenge extends Equatable {
  const OtpChallenge({
    required this.id,
    required this.phoneE164,
    required this.expiresIn,
    required this.binding,
    this.reference,
  });

  final String id;
  final String phoneE164;
  final Duration expiresIn;

  /// The secret this sign-in attempt sent with the request and must send again
  /// with the verify call. In memory only: never log it or write it to disk.
  final String binding;

  /// Four characters the SMS shows as `Code ref AB12`; shown to the customer
  /// so they pick the right SMS when several codes are live for one number.
  /// Null when an older server did not send it.
  final String? reference;

  @override
  List<Object?> get props => [id, phoneE164, expiresIn, binding, reference];

  /// Never prints the binding or the phone number.
  @override
  String toString() => 'OtpChallenge(id: $id, reference: $reference)';
}
