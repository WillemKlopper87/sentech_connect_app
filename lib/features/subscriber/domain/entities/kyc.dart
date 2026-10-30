import 'package:equatable/equatable.dart';

/// The identity document types the platform accepts (`id_type`).
enum KycIdType {
  saId('sa_id'),
  passport('passport'),
  companyReg('company_reg');

  const KycIdType(this.api);

  /// The value sent in `id_type`.
  final String api;
}

/// Decision state of the customer's ID check. "No check yet" (`none`) and a
/// check the platform has erased are both `null` where a [KycRecord] is
/// optional, never a status here.
enum KycStatus { pending, verified, rejected }

/// `SubscriberKycOut`: what the platform exposes about the customer's latest
/// check. The ID number is never returned, only its last four characters; no
/// rejection reason is exposed (platform item P7).
class KycRecord extends Equatable {
  const KycRecord({
    required this.status,
    required this.idType,
    required this.idNumberLast4,
    required this.consentVersion,
    required this.consentAt,
    this.verifiedAt,
  });

  final KycStatus status;
  final KycIdType idType;
  final String idNumberLast4;
  final String consentVersion;
  final DateTime consentAt;
  final DateTime? verifiedAt;

  @override
  List<Object?> get props => [status, idType, idNumberLast4, consentVersion, consentAt, verifiedAt];
}

/// One ID check submission (`SubscriberKycIn`). Holds personal data, so it is
/// never printed ([toString] is redacted) and lives only as long as the submit
/// call. [idNumber] and [addressText] are already normalised (see
/// `KycValidators`); [documentBase64] is the encoded JPEG, or null for none.
class KycSubmission {
  const KycSubmission({
    required this.idType,
    required this.idNumber,
    required this.addressText,
    required this.consentVersion,
    this.documentBase64,
  });

  final KycIdType idType;
  final String idNumber;
  final String addressText;

  /// `YYYY-MM-DD` privacy notice version the customer agreed to.
  final String consentVersion;
  final String? documentBase64;

  /// The request body. `consent_via` is always `app`; `document` is left out
  /// when there is none (the API treats it as optional).
  Map<String, Object?> toJson() => {
    'id_type': idType.api,
    'id_number': idNumber,
    'address_text': addressText,
    'consent_version': consentVersion,
    'consent_via': 'app',
    'document': ?documentBase64,
  };

  @override
  String toString() => 'KycSubmission(<redacted>)';
}
