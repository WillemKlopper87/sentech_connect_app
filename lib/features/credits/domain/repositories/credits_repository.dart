import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

/// The customer's credits (rewards): wallet, history, redeeming a pack for a
/// hotspot pass, the daily check-in, missions and badges. No ads, referrals or
/// offers. Where the provider has the feature off, or the server is older than
/// the routes, every call fails with [CreditsNotAvailableFailure] and the
/// screens hide the feature. The server decides everything (the Johannesburg
/// day, progress, caps); the app shows it.
abstract class CreditsRepository {
  Future<Either<Failure, CreditsSummary>> summary();

  /// Newest first; pass the previous page's `nextCursor` for the next page.
  Future<Either<Failure, LedgerPage>> ledger({String? cursor});

  /// Spends [credits] (one of `rates.packSizes`) and returns the new pass.
  /// Reusing [idempotencyKey] after a lost response returns the same pass and
  /// never spends twice.
  Future<Either<Failure, Pass>> redeem({required int credits, required String idempotencyKey});

  Future<Either<Failure, StreakState>> streak();

  /// Today's check-in. Reusing [idempotencyKey], or claiming again the same
  /// day, returns the first answer and never pays twice.
  Future<Either<Failure, ClaimResult>> claimToday({required String idempotencyKey});

  Future<Either<Failure, List<Mission>>> missions();

  Future<Either<Failure, List<CreditBadge>>> badges();
}
