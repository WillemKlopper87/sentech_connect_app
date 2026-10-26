import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';

/// Accepts every request (unless the simulated network is down). A backend
/// implementation replaces it; nothing above the repository changes.
class MockPrivacyRepository implements PrivacyRepository {
  MockPrivacyRepository([SimulatedNetwork? network]) : _network = network ?? SimulatedNetwork();

  final SimulatedNetwork _network;

  Future<Either<Failure, PrivacyRequestReceipt>> _accept(String prefix) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_network.failure case final failure?) return Left(failure);
    final now = DateTime.now();
    return Right(PrivacyRequestReceipt(reference: '$prefix-${now.millisecondsSinceEpoch}', requestedAt: now));
  }

  /// Demo: any 6-digit code deletes, except [rejectedDemoCode].
  static const rejectedDemoCode = '000000';
  static const demoReference = 'AB23';

  @override
  Future<Either<Failure, DeleteChallenge>> requestDeleteChallenge() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_network.failure case final failure?) return Left(failure);
    return const Right(DeleteChallenge(challengeId: 'demo-delete-challenge', expiresIn: Duration(minutes: 5), reference: demoReference));
  }

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> deleteAccount({required String challengeId, required String code}) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return const Left(ValidationFailure('Enter the 6-digit code.', 'invalid_code'));
    if (code == rejectedDemoCode) return const Left(ReauthRequiredFailure());
    return _accept('DEL');
  }

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport() => _accept('EXP');
}
