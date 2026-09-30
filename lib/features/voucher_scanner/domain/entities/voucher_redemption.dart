import 'package:equatable/equatable.dart';

enum VoucherOutcome { redeemed, invalid, alreadyUsed, expired }

/// Server verdict for one redemption attempt. Transport problems are not
/// outcomes — they come back as a `Failure` from the repository instead.
class VoucherRedemption extends Equatable {
  const VoucherRedemption(this.outcome, {this.dataMb});

  final VoucherOutcome outcome;

  /// Data credited, only for [VoucherOutcome.redeemed].
  final int? dataMb;

  @override
  List<Object?> get props => [outcome, dataMb];
}
