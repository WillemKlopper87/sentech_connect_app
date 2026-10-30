import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';

KycIdType kycIdTypeFromApi(Object? value) => switch (value) {
  'sa_id' => KycIdType.saId,
  'passport' => KycIdType.passport,
  'company_reg' => KycIdType.companyReg,
  final other => throw FormatException('Unknown ID type $other'),
};

/// `SubscriberKycOut` -> [KycRecord]; `{status: none}` and `erased` -> null.
/// An unknown status fails loudly (the contract test lists every value).
KycRecord? kycRecordFromJson(Map<String, Object?> json) {
  final status = switch (json['status']) {
    'none' || 'erased' => null,
    'pending' => KycStatus.pending,
    'verified' => KycStatus.verified,
    'rejected' => KycStatus.rejected,
    final other => throw FormatException('Unknown KYC status $other'),
  };
  if (status == null) return null;
  final verifiedAt = json['verified_at'];
  return KycRecord(
    status: status,
    idType: kycIdTypeFromApi(json['id_type']),
    idNumberLast4: json['id_number_last4']! as String,
    consentVersion: json['consent_version']! as String,
    consentAt: DateTime.parse(json['consent_at']! as String).toUtc(),
    verifiedAt: verifiedAt == null ? null : DateTime.parse(verifiedAt as String).toUtc(),
  );
}

/// `GET` and `POST /v1/me/subscriber/kyc`. The POST body can hold a base64
/// photo of up to ~5 MB, so it gets a long timeout; nothing from the body is
/// logged or kept here.
class HttpKycRepository implements KycRepository {
  HttpKycRepository(this._api);

  static const submitTimeout = Duration(seconds: 60);

  final ApiClient _api;

  @override
  Future<Either<Failure, KycRecord?>> getStatus() async => _api.get<KycRecord?>(
    '/v1/me/subscriber/kyc',
    scope: await _api.captureScope(),
    decode: (data) => kycRecordFromJson(Map<String, Object?>.from(data! as Map)),
  );

  @override
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey}) async =>
      _api.post<KycRecord>(
        '/v1/me/subscriber/kyc',
        scope: await _api.captureScope(),
        idempotencyKey: idempotencyKey,
        timeout: submitTimeout,
        body: submission.toJson(),
        decode: (data) =>
            kycRecordFromJson(Map<String, Object?>.from(data! as Map)) ?? (throw const FormatException('Unexpected KYC status')),
      );
}
