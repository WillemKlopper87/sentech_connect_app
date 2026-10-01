import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';

/// Versioned, timestamped consent records (POPIA). Stored locally today; the
/// real implementation also POSTs each record to the backend so Sentech holds
/// the authoritative audit trail — [unsyncedRecords]/[markSynced] are the
/// hooks for that sync.
abstract class ConsentRepository {
  /// The customer's consent for [purpose] if it was given for the CURRENT
  /// policy version, otherwise null (never asked, or the text changed).
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose);

  /// Records consent now, against the current policy version.
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose);

  /// Records that the customer withdrew [purpose] (POPIA: as easy to withdraw
  /// as to give). Succeeds when nothing was granted.
  Future<Either<Failure, Unit>> withdraw(ConsentPurpose purpose);

  /// Records not yet delivered to the backend.
  Future<List<ConsentRecord>> unsyncedRecords();

  Future<void> markSynced(Iterable<ConsentRecord> records);

  /// Removes all locally held consent records (account deletion).
  Future<void> clear();
}
