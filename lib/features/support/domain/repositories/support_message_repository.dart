import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';

/// Sends a message to the provider's support team (`POST /v1/support/messages`).
abstract class SupportMessageRepository {
  /// [idempotencyKey] identifies ONE submission: the caller reuses it for every
  /// retry of the same draft, so the server answers a replay with the stored
  /// reference instead of sending a second message.
  Future<Either<Failure, SupportReceipt>> send(
    SupportMessageDraft draft, {
    required String idempotencyKey,
  });
}
