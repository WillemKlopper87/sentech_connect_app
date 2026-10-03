import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';

/// `POST /v1/me/vouchers/redeem` (platform M2; the web /redeem uses the same
/// endpoint). The server answers every reason a code cannot be redeemed with
/// the same 422 `voucher_invalid`, on purpose, so the app cannot (and does
/// not) tell expired, used and unknown codes apart.
class HttpVoucherRepository implements VoucherRepository {
  HttpVoucherRepository(this._api);

  static const path = '/v1/me/vouchers/redeem';

  final ApiClient _api;

  // One idempotency key per logical redemption: "Try again" after a lost
  // response repeats the same code with the same key, so the server replays
  // its answer instead of judging a second attempt. Kept in memory only.
  String? _lastCode;
  String? _lastKey;

  @override
  Future<Either<Failure, VoucherRedemption>> redeem(VoucherCode code) async {
    if (code.value != _lastCode) {
      _lastCode = code.value;
      _lastKey = newIdempotencyKey();
    }
    final result = await _api.post<VoucherRedemption>(
      path,
      body: {'code': code.value},
      idempotencyKey: _lastKey,
      decode: (data) {
        final map = Map<String, Object?>.from(data! as Map);
        final pass = passFromJson(
          Map<String, Object?>.from(map['entitlement']! as Map),
        );
        return VoucherRedemption(
          VoucherOutcome.redeemed,
          productName: map['product_name']! as String,
          pass: pass,
          dataMb: pass.dataMb,
        );
      },
    );
    return switch (result) {
      // A refusal of the code itself (422 voucher_invalid, or another 4xx
      // problem) is an answer about the voucher, not a transport failure.
      Left(value: ValidationFailure() || NotFoundFailure()) => const Right(
        VoucherRedemption(VoucherOutcome.invalid),
      ),
      _ => result,
    };
  }
}
