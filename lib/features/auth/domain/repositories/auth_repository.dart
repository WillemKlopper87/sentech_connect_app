import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> logIn({
    required String mobileNumber,
    required String password,
  });

  /// Re-establishes a session from the credential saved by a previous login
  /// (see `SessionStore.loadBiometricCredential`). The caller must already
  /// have passed a biometric check — this only exchanges the credential.
  Future<Either<Failure, User>> logInWithStoredCredential(String credential);
}
