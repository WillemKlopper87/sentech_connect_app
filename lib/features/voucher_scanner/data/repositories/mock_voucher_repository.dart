import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';

/// Mock voucher service with the same contract a server would honour:
/// typed outcomes and per-code idempotency (a code redeems once, ever).
///
/// Demo codes: `SEN-EXPx-xxxx` is expired, `SEN-USEx-xxxx` was already used,
/// `SEN-INVx-xxxx` is unknown; any other well-formed code redeems once.
class MockVoucherRepository implements VoucherRepository {
  MockVoucherRepository(this._store, {SimulatedNetwork? network, this._latency = const Duration(milliseconds: 500)})
      : _network = network ?? SimulatedNetwork();

  static const _redeemedKey = 'redeemed_vouchers';

  final SecureStore _store;
  final SimulatedNetwork _network;
  final Duration _latency;

  @override
  Future<Either<Failure, VoucherRedemption>> redeem(VoucherCode code) async {
    await Future.delayed(_latency);
    if (_network.failure case final failure?) return Left(failure);

    final body = code.value.substring(4); // after "SEN-"
    if (body.startsWith('EXP')) return const Right(VoucherRedemption(VoucherOutcome.expired));
    if (body.startsWith('USE')) return const Right(VoucherRedemption(VoucherOutcome.alreadyUsed));
    if (body.startsWith('INV')) return const Right(VoucherRedemption(VoucherOutcome.invalid));

    final redeemed = await _loadRedeemed();
    if (redeemed.contains(code.value)) {
      return const Right(VoucherRedemption(VoucherOutcome.alreadyUsed));
    }
    await _store.write(_redeemedKey, jsonEncode([...redeemed, code.value]));
    return const Right(VoucherRedemption(VoucherOutcome.redeemed, dataMb: 5120));
  }

  Future<Set<String>> _loadRedeemed() async {
    final raw = await _store.read(_redeemedKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }
}
