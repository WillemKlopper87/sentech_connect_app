import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  /// Sends a one-time code by SMS to a South African mobile number (any
  /// common format; normalised to E.164 first).
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber});

  /// Exchanges the code for a session. The platform creates the account on
  /// first sign-in, so this is registration too (new customers have an
  /// empty `fullName` until they complete their profile).
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code});

  /// Re-opens the session stored on this device. Callers must have passed a
  /// biometric check first (spec §6: biometrics only unlock a session).
  Future<Either<Failure, User>> resumeSession();

  /// Revokes the session server-side (best effort: bounded in time, skipped
  /// when the server cannot be reached, so an offline logout leaves the
  /// refresh family valid until the server expires it) and ALWAYS forgets the
  /// tokens on this device. Network failures never throw; only a failure to
  /// clear the device's own storage does, so the caller knows tokens may
  /// remain.
  Future<void> logOut();

  /// Whether the tokens held on this device belong to [user] and to
  /// [tenantSlug] (a missing, other-tenant or other-customer session is not a
  /// match). No network.
  Future<bool> sessionMatches({required String tenantSlug, required User user});

  /// Forgets the tokens on this device without contacting the server.
  Future<void> discardLocalSession();
}
