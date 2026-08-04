import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

/// Mock-backed implementation used during the UI/demo phase.
/// Satisfies [AuthRepository] so a real Dio-backed OIDC implementation
/// (via flutter_appauth, per the reconciled spec) is a drop-in replacement.
class MockAuthRepository implements AuthRepository {
  static const _demoUser = User(
    id: 'usr_001',
    fullName: 'Lindiwe Khumalo',
    mobileNumber: '081 000 0000',
  );

  @override
  Future<Either<Failure, User>> logIn({
    required String mobileNumber,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mobileNumber.isEmpty || password.isEmpty) {
      return const Left(ValidationFailure('Enter your mobile number and password.'));
    }
    return const Right(_demoUser);
  }

  @override
  Future<Either<Failure, User>> logInWithBiometrics() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const Right(_demoUser);
  }
}
