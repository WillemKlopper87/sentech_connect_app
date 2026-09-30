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

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestAccountDeletion() => _accept('DEL');

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport() => _accept('EXP');
}
