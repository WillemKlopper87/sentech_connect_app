import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/data/credits_json.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/credits_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/ledger_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/missions_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/redeem_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/streak_cubit.dart';

import '../helpers/fixtures.dart';
import 'fake_credits_repository.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

String Function() _keys() {
  var n = 0;
  return () => 'key-${++n}-0000000';
}

void main() {
  late FakeCreditsRepository repo;

  setUp(() => repo = FakeCreditsRepository());

  group('CreditsCubit', () {
    test('loads the wallet', () async {
      final cubit = CreditsCubit(repo);
      await _settle();
      expect(cubit.state.status, CreditsStatus.ready);
      expect(cubit.state.summary!.available, 150);
      await cubit.close();
    });

    test('feature unavailable (older server, flag or module off) is its own state, not an error', () async {
      repo.summaryResult = const Left(CreditsNotAvailableFailure());
      final cubit = CreditsCubit(repo);
      await _settle();
      expect(cubit.state.status, CreditsStatus.unavailable);
      await cubit.close();
    });

    test('a failed refresh keeps the wallet on screen', () async {
      final cubit = CreditsCubit(repo);
      await _settle();
      repo.summaryResult = const Left(NetworkFailure());
      await cubit.refresh();
      expect(cubit.state.status, CreditsStatus.ready);
      expect(cubit.state.summary, isNotNull);
      await cubit.close();
    });

    test('a first load that fails is an error with the failure', () async {
      repo.summaryResult = const Left(ServerFailure());
      final cubit = CreditsCubit(repo);
      await _settle();
      expect(cubit.state.status, CreditsStatus.error);
      expect(cubit.state.failure, isA<ServerFailure>());
      await cubit.close();
    });
  });

  group('RedeemCubit', () {
    test('a_double_tap_sends_one_request', () async {
      repo.gate = Completer<void>();
      final cubit = RedeemCubit(repo, newKey: _keys());
      unawaited(cubit.redeem(50));
      unawaited(cubit.redeem(50));
      unawaited(cubit.redeem(100));
      await _settle();
      repo.gate!.complete();
      await _settle();
      expect(repo.redeemCalls, hasLength(1));
      expect(cubit.state.status, RedeemStatus.done);
      expect(cubit.state.pass, isNotNull);
      await cubit.close();
    });

    test('a_retry_after_failure_reuses_the_same_key', () async {
      repo.redeemResults.addAll([const Left(NetworkFailure()), Right(redeemedPassFixture())]);
      final cubit = RedeemCubit(repo, newKey: _keys());
      await cubit.redeem(50);
      expect(cubit.state.status, RedeemStatus.failed);
      await cubit.redeem(50);
      expect(cubit.state.status, RedeemStatus.done);
      expect(repo.redeemCalls.map((c) => c.key).toSet(), hasLength(1));
      await cubit.close();
    });

    test('a different pack after a failure starts a new key (the server refuses one key for two requests)', () async {
      repo.redeemResults.addAll([const Left(NetworkFailure()), Right(redeemedPassFixture())]);
      final cubit = RedeemCubit(repo, newKey: _keys());
      await cubit.redeem(50);
      await cubit.redeem(100);
      expect(repo.redeemCalls.map((c) => c.key).toSet(), hasLength(2));
      await cubit.close();
    });

    test('a new attempt after success gets a new key', () async {
      final cubit = RedeemCubit(repo, newKey: _keys());
      await cubit.redeem(50);
      cubit.dismiss();
      await cubit.redeem(50);
      expect(repo.redeemCalls.map((c) => c.key).toSet(), hasLength(2));
      await cubit.close();
    });

    test('a final refusal from the server starts afresh next time, an unfinished request does not', () async {
      repo.redeemResults.addAll([
        const Left(InsufficientCreditsFailure()),
        const Left(IdempotencyInProgressFailure()),
        Right(redeemedPassFixture()),
      ]);
      final cubit = RedeemCubit(repo, newKey: _keys());
      await cubit.redeem(50);
      await cubit.redeem(50);
      await cubit.redeem(50);
      final keys = repo.redeemCalls.map((c) => c.key).toList();
      expect(keys[0], isNot(keys[1]));
      expect(keys[1], keys[2]);
      await cubit.close();
    });

    test('closing_the_page_mid_request_does_not_emit_after_close', () async {
      repo.gate = Completer<void>();
      final cubit = RedeemCubit(repo, newKey: _keys());
      final states = <RedeemStatus>[];
      final sub = cubit.stream.listen((s) => states.add(s.status));
      unawaited(cubit.redeem(50));
      await _settle();
      await cubit.close();
      repo.gate!.complete();
      await _settle();
      expect(states, [RedeemStatus.submitting]);
      await sub.cancel();
    });

    test('a frozen wallet, a pause and an inactive account block every pack', () async {
      for (final failure in <Failure>[
        const WalletFrozenFailure(),
        const CreditsPausedFailure(),
        const CustomerInactiveFailure(),
      ]) {
        repo.redeemResults
          ..clear()
          ..add(Left(failure));
        final cubit = RedeemCubit(repo, newKey: _keys());
        await cubit.redeem(50);
        expect(cubit.state.blocksActions, isTrue, reason: '$failure');
        await cubit.close();
      }
      repo.redeemResults
        ..clear()
        ..add(const Left(InsufficientCreditsFailure()));
      final cubit = RedeemCubit(repo, newKey: _keys());
      await cubit.redeem(50);
      expect(cubit.state.blocksActions, isFalse);
      await cubit.close();
    });
  });

  group('StreakCubit', () {
    test('loads the streak the server sent, with the server day', () async {
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      expect(cubit.state.status, StreakStatus.ready);
      expect(cubit.state.streak!.day, '2026-11-25');
      await cubit.close();
    });

    test('claim_twice_in_a_row_shows_already_claimed_not_an_error', () async {
      repo.claimResults.addAll([Right(claimFixture('streak_claim_paid.json')), Right(claimFixture('streak_claim_repeat.json'))]);
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      await cubit.claim();
      expect(cubit.state.claimStatus, ClaimStatus.done);
      expect(cubit.state.claim!.claimed, isTrue);
      expect(cubit.state.streak!.claimedToday, isTrue);
      await cubit.claim();
      expect(cubit.state.claimStatus, ClaimStatus.done);
      expect(cubit.state.claim!.claimed, isFalse);
      expect(cubit.state.claimFailure, isNull);
      await cubit.close();
    });

    test('a double tap sends one claim', () async {
      repo.gate = Completer<void>();
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      unawaited(cubit.claim());
      unawaited(cubit.claim());
      await _settle();
      repo.gate!.complete();
      await _settle();
      expect(repo.claimKeys, hasLength(1));
      await cubit.close();
    });

    test('a retry after a lost response reuses the key; a final answer starts afresh', () async {
      repo.claimResults.addAll([
        const Left(NetworkFailure()),
        const Left(EarnRefusedFailure()),
        Right(claimFixture('streak_claim_paid.json')),
      ]);
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      await cubit.claim();
      await cubit.claim();
      await cubit.claim();
      expect(repo.claimKeys[0], repo.claimKeys[1]);
      expect(repo.claimKeys[2], isNot(repo.claimKeys[1]));
      await cubit.close();
    });

    test('a frozen wallet is explained and blocks the claim button', () async {
      repo.claimResults.add(const Left(WalletFrozenFailure()));
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      await cubit.claim();
      expect(cubit.state.claimStatus, ClaimStatus.failed);
      expect(cubit.state.claimBlocked, isTrue);
      await cubit.close();
    });

    test('a capped claim keeps the server cap name', () async {
      repo.claimResults.add(Right(claimFixture('streak_claim_capped.json')));
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      await cubit.claim();
      expect(cubit.state.claim!.cappedBy, 'overall_monthly');
      expect(cubit.state.claim!.credits, 0);
      await cubit.close();
    });

    test('closing the page mid-claim emits nothing after close', () async {
      repo.gate = Completer<void>();
      final cubit = StreakCubit(repo, newKey: _keys());
      await _settle();
      final states = <ClaimStatus>[];
      final sub = cubit.stream.listen((s) => states.add(s.claimStatus));
      unawaited(cubit.claim());
      await _settle();
      await cubit.close();
      repo.gate!.complete();
      await _settle();
      expect(states, [ClaimStatus.claiming]);
      await sub.cancel();
    });
  });

  group('LedgerCubit', () {
    void pages() {
      repo.ledgerPages[null] = Right(ledgerPageFromJson(fixtureMap('credits_ledger_page_1.json')));
      final next = ledgerPageFromJson(fixtureMap('credits_ledger_page_1.json')).nextCursor;
      repo.ledgerPages[next] = Right(ledgerPageFromJson(fixtureMap('credits_ledger_page_2.json')));
    }

    test('loads the first page then follows the cursor', () async {
      pages();
      final cubit = LedgerCubit(repo);
      await _settle();
      expect(cubit.state.items, hasLength(2));
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore();
      expect(cubit.state.items, hasLength(4));
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.items.last.kind, CreditEntryKind.expire);
      await cubit.close();
    });

    test('loading more twice at once fetches one page', () async {
      pages();
      final cubit = LedgerCubit(repo);
      await _settle();
      repo.gate = Completer<void>();
      unawaited(cubit.loadMore());
      unawaited(cubit.loadMore());
      await _settle();
      repo.gate!.complete();
      await _settle();
      expect(repo.ledgerCursors.where((c) => c != null), hasLength(1));
      expect(cubit.state.items, hasLength(4));
      await cubit.close();
    });

    test('a failed next page keeps the pages already loaded', () async {
      pages();
      final cubit = LedgerCubit(repo);
      await _settle();
      repo.ledgerPages[cubit.state.nextCursor] = const Left(NetworkFailure());
      await cubit.loadMore();
      expect(cubit.state.items, hasLength(2));
      expect(cubit.state.moreFailure, isA<NetworkFailure>());
      expect(cubit.state.hasMore, isTrue);
      await cubit.close();
    });

    test('unavailable is its own state', () async {
      repo.ledgerPages[null] = const Left(CreditsNotAvailableFailure());
      final cubit = LedgerCubit(repo);
      await _settle();
      expect(cubit.state.status, LedgerStatus.unavailable);
      await cubit.close();
    });
  });

  group('MissionsCubit and BadgesCubit', () {
    test('missions come through exactly as the server sent them', () async {
      final fixtureMissions = [
        for (final item in fixtureMap('credits_missions.json')['items']! as List)
          missionFromJson(Map<String, Object?>.from(item as Map)),
      ];
      repo.missionsResult = Right(fixtureMissions);
      final cubit = MissionsCubit(repo);
      await _settle();
      expect(cubit.state.status, ListStatus.ready);
      expect(cubit.state.missions, fixtureMissions);
      await cubit.close();
    });

    test('badges and unavailable', () async {
      repo.badgesResult = const Left(CreditsNotAvailableFailure());
      final cubit = BadgesCubit(repo);
      await _settle();
      expect(cubit.state.status, ListStatus.unavailable);
      await cubit.close();
    });
  });
}
