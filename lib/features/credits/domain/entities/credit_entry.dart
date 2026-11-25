import 'package:equatable/equatable.dart';

/// `CreditEntryOut.kind`.
enum CreditEntryKind { earn, spend, expire, clawback, forfeit }

/// One line of the credits history. [credits] is signed: positive for earns,
/// negative for spends, expiries, clawbacks and forfeits.
class CreditEntry extends Equatable {
  const CreditEntry({
    required this.id,
    required this.kind,
    required this.credits,
    required this.source,
    required this.createdAt,
  });

  final int id;
  final CreditEntryKind kind;
  final int credits;

  /// The server's source label (`streak`, `mission`, `pack_redemption`, ...).
  /// An unknown value is shown by kind only.
  final String source;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, kind, credits, source, createdAt];
}

/// One page of the history, newest first. [nextCursor] is null on the last page.
class LedgerPage extends Equatable {
  const LedgerPage({required this.items, this.nextCursor});

  final List<CreditEntry> items;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}
