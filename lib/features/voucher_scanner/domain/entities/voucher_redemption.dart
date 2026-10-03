import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

enum VoucherOutcome { redeemed, invalid, alreadyUsed, expired }

/// Server verdict for one redemption attempt. Transport problems are not
/// outcomes — they come back as a `Failure` from the repository instead.
class VoucherRedemption extends Equatable {
  const VoucherRedemption(
    this.outcome, {
    this.dataMb,
    this.productName,
    this.pass,
  });

  final VoucherOutcome outcome;

  /// Data credited, only for [VoucherOutcome.redeemed] (null: uncapped or
  /// unknown).
  final int? dataMb;

  /// The product the voucher was for, e.g. "Day Pass" (server only).
  final String? productName;

  /// The pass the voucher created (server only).
  final Pass? pass;

  @override
  List<Object?> get props => [outcome, dataMb, productName, pass];
}
