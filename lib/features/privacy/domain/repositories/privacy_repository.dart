import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// Acknowledgement of a data-subject request (POPIA sections 23/24 access and
/// deletion; also the Google Play account-deletion requirement).
class PrivacyRequestReceipt extends Equatable {
  const PrivacyRequestReceipt({required this.reference, required this.requestedAt, this.exportJson});

  final String reference;
  final DateTime requestedAt;

  /// The export itself, when the server returns it immediately
  /// (`GET /v1/me/export`); null when it is delivered another way.
  final String? exportJson;

  @override
  List<Object?> get props => [reference, requestedAt, exportJson];
}

/// Real implementation calls the backend (which deletes/exports server-side
/// data and cascades to the BSS/CRM, payment provider and KYC vendor). The
/// app only wipes local data AFTER the server accepted the deletion request.
abstract class PrivacyRepository {
  /// Asks the server to permanently delete the account and its personal data.
  Future<Either<Failure, PrivacyRequestReceipt>> requestAccountDeletion();

  /// Asks the server to prepare an export of the customer's data, delivered
  /// to their verified email.
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport();
}
