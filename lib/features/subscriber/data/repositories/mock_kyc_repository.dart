import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';

/// Demo flavor only: starts with no check; a submission is pending and turns
/// verified after [verifyAfter] (the real platform has staff decide by hand).
/// Keeps only the last four characters of the ID number, in memory.
class MockKycRepository implements KycRepository {
  MockKycRepository({DateTime Function()? now, this.verifyAfter = const Duration(seconds: 5)})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration verifyAfter;

  KycIdType? _idType;
  String? _last4;
  String? _consentVersion;
  DateTime? _submittedAt;

  @override
  Future<Either<Failure, KycRecord?>> getStatus() async {
    final submittedAt = _submittedAt;
    if (submittedAt == null) return const Right(null);
    final verified = !_now().isBefore(submittedAt.add(verifyAfter));
    return Right(_record(verified ? KycStatus.verified : KycStatus.pending, submittedAt));
  }

  @override
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey}) async {
    final number = submission.idNumber;
    _idType = submission.idType;
    _last4 = number.length <= 4 ? number : number.substring(number.length - 4);
    _consentVersion = submission.consentVersion;
    _submittedAt = _now().toUtc();
    return Right(_record(KycStatus.pending, _submittedAt!));
  }

  KycRecord _record(KycStatus status, DateTime submittedAt) => KycRecord(
    status: status,
    idType: _idType!,
    idNumberLast4: _last4!,
    consentVersion: _consentVersion!,
    consentAt: submittedAt,
    verifiedAt: status == KycStatus.verified ? submittedAt.add(verifyAfter) : null,
  );
}
