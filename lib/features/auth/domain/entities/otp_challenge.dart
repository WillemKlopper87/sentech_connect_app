import 'package:equatable/equatable.dart';

/// A one-time code sent by SMS (`POST /v1/auth/otp/request`).
class OtpChallenge extends Equatable {
  const OtpChallenge({required this.id, required this.phoneE164, required this.expiresIn});

  final String id;
  final String phoneE164;
  final Duration expiresIn;

  @override
  List<Object?> get props => [id, phoneE164, expiresIn];
}
