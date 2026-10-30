import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_profile_edit.dart';

/// Contact details: the account's billing contact (`PATCH /v1/me/subscriber`)
/// and, for a customer who has no account yet, the sign-in profile the
/// sign-up copies (`/v1/me/profile`).
abstract class SubscriberProfileRepository {
  /// Changes the account profile and answers the account as it now is. One
  /// [idempotencyKey] per attempt; a retry with the same key gets the same answer.
  Future<Either<Failure, SubscriberAccount>> patchProfile(SubscriberProfilePatch patch, {required String idempotencyKey});

  Future<Either<Failure, LoginContact>> getLoginContact();

  /// Changes the sign-in profile's name and/or email (`null` leaves a field
  /// alone; [clearEmail] removes the email).
  Future<Either<Failure, LoginContact>> patchLoginContact({String? displayName, String? email, bool clearEmail = false});
}
