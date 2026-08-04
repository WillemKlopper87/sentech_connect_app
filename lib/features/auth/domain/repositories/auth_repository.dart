import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> logIn({
    required String mobileNumber,
    required String password,
  });

  Future<Either<Failure, User>> logInWithBiometrics();
}
