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

/// The fresh re-check of an account deletion: a code was sent by SMS to the
/// phone number on the account (`POST /v1/me/delete-challenge`).
class DeleteChallenge extends Equatable {
  const DeleteChallenge({required this.challengeId, required this.expiresIn, this.reference});

  final String challengeId;
  final Duration expiresIn;

  /// Four characters the SMS shows as `Code ref AB12`.
  final String? reference;

  @override
  List<Object?> get props => [challengeId, expiresIn, reference];
}

/// Real implementation calls the backend (which deletes/exports server-side
/// data and cascades to the BSS/CRM, payment provider and KYC vendor). The
/// app only wipes local data AFTER the server accepted the deletion request.
abstract class PrivacyRepository {
  /// Step 1 of deleting the account: the platform sends a code to the phone on
  /// the account. A 401 (no phone number to send to) is a
  /// [DeleteCodeUnavailableFailure] and does NOT end the session.
  Future<Either<Failure, DeleteChallenge>> requestDeleteChallenge();

  /// Step 2: permanently deletes the account and its personal data, once
  /// [code] (from the SMS of [challengeId]) proves the customer still holds
  /// the phone. A wrong, used or expired code is a [ReauthRequiredFailure] and
  /// nothing is deleted.
  Future<Either<Failure, PrivacyRequestReceipt>> deleteAccount({required String challengeId, required String code});

  /// Asks the server to prepare an export of the customer's data, delivered
  /// to their verified email.
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport();
}
