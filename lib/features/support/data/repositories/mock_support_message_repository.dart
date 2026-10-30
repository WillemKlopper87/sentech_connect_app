import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';

/// Demo flavor only: nothing is sent. The reference is labelled DEMO so it
/// cannot be mistaken for a real one.
class MockSupportMessageRepository implements SupportMessageRepository {
  final _byKey = <String, SupportReceipt>{};

  @override
  Future<Either<Failure, SupportReceipt>> send(
    SupportMessageDraft draft, {
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return Right(
      _byKey.putIfAbsent(
        idempotencyKey,
        () => SupportReceipt(
          'DEMO-${(_byKey.length + 1).toString().padLeft(4, '0')}',
        ),
      ),
    );
  }
}
