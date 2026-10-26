import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

/// Demo flavor: any valid SA mobile gets a code; any 6-digit code except
/// [rejectedDemoCode] signs in (so the wrong-code path can be demoed).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 400)});

  static const rejectedDemoCode = '000000';
  static const demoReference = 'AB23';
  static const _demoUser = User(id: 'usr_001', fullName: 'Lindiwe Khumalo', mobileNumber: '081 000 0000');

  final Duration latency;

  /// A zero latency really is instant (no timer), so widget tests can drive
  /// the flow with plain `pump()` calls.
  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber, required String binding}) async {
    await _simulateLatency();
    final phone = normaliseZaMobile(phoneNumber);
    if (phone == null) {
      return const Left(ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'));
    }
    return Right(
      OtpChallenge(
        id: 'demo-challenge',
        phoneE164: phone,
        expiresIn: const Duration(minutes: 5),
        binding: binding,
        reference: demoReference,
      ),
    );
  }

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async {
    await _simulateLatency();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return const Left(ValidationFailure('Enter the 6-digit code.', 'invalid_code'));
    if (code == rejectedDemoCode) return const Left(ValidationFailure('The code is invalid or has expired.', 'otp_invalid'));
    return Right(User(id: _demoUser.id, fullName: _demoUser.fullName, mobileNumber: challenge.phoneE164));
  }

  @override
  Future<Either<Failure, User>> resumeSession() async {
    await _simulateLatency();
    return const Right(_demoUser);
  }

  @override
  Future<void> logOut() async {}

  /// The demo flavor has no tokens: a stored demo session always matches.
  @override
  Future<bool> sessionMatches({required String tenantSlug, required User user}) async => true;

  @override
  Future<void> discardLocalSession() async {}
}
