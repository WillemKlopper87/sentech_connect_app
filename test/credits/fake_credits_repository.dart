import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/data/credits_json.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

import '../helpers/fixtures.dart';

CreditsSummary summaryFixture([String name = 'credits_summary.json']) => creditsSummaryFromJson(fixtureMap(name));

StreakState streakFixture([String name = 'credits_streak.json']) => streakStateFromJson(fixtureMap(name));

ClaimResult claimFixture(String name) => claimResultFromJson(fixtureMap(name));

Pass redeemedPassFixture() => passFromJson(fixtureMap('credits_redeem_pass.json'));

/// A scriptable [CreditsRepository]: every call is recorded, and an answer is
/// either immediate or held on a [Completer] so a test can act while a request
/// is in flight.
class FakeCreditsRepository implements CreditsRepository {
  Either<Failure, CreditsSummary> summaryResult = Right(summaryFixture());
  Either<Failure, StreakState> streakResult = Right(streakFixture());
  Either<Failure, List<Mission>> missionsResult = const Right([]);
  Either<Failure, List<CreditBadge>> badgesResult = const Right([]);
  final ledgerPages = <String?, Either<Failure, LedgerPage>>{};

  /// Answers to successive redeem and claim calls; the last one repeats.
  final redeemResults = <Either<Failure, Pass>>[];
  final claimResults = <Either<Failure, ClaimResult>>[];

  /// When set, the next redeem or claim waits for it.
  Completer<void>? gate;

  /// When set, the next streak read waits for it.
  Completer<void>? streakGate;

  final redeemCalls = <({int credits, String key})>[];
  final claimKeys = <String>[];
  final ledgerCursors = <String?>[];
  int summaryCalls = 0;

  @override
  Future<Either<Failure, CreditsSummary>> summary() async {
    summaryCalls++;
    return summaryResult;
  }

  @override
  Future<Either<Failure, LedgerPage>> ledger({String? cursor}) async {
    ledgerCursors.add(cursor);
    await gate?.future;
    return ledgerPages[cursor] ?? const Right(LedgerPage(items: []));
  }

  @override
  Future<Either<Failure, Pass>> redeem({required int credits, required String idempotencyKey}) async {
    redeemCalls.add((credits: credits, key: idempotencyKey));
    await gate?.future;
    final index = redeemCalls.length - 1;
    return redeemResults.isEmpty
        ? Right(redeemedPassFixture())
        : redeemResults[index < redeemResults.length ? index : redeemResults.length - 1];
  }

  @override
  Future<Either<Failure, StreakState>> streak() async {
    await streakGate?.future;
    return streakResult;
  }

  @override
  Future<Either<Failure, ClaimResult>> claimToday({required String idempotencyKey}) async {
    claimKeys.add(idempotencyKey);
    await gate?.future;
    final index = claimKeys.length - 1;
    return claimResults.isEmpty
        ? Right(claimFixture('streak_claim_paid.json'))
        : claimResults[index < claimResults.length ? index : claimResults.length - 1];
  }

  @override
  Future<Either<Failure, List<Mission>>> missions() async => missionsResult;

  @override
  Future<Either<Failure, List<CreditBadge>>> badges() async => badgesResult;
}
