import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';

/// Real implementation calls an idempotent server endpoint (the code, or a
/// client-generated idempotency key, is the dedupe key) and returns exactly
/// what the server decided. The client never decides a voucher is valid.
abstract class VoucherRepository {
  /// Redeeming the same code again must never credit twice: later calls
  /// return [VoucherOutcome.alreadyUsed].
  Future<Either<Failure, VoucherRedemption>> redeem(VoucherCode code);
}
