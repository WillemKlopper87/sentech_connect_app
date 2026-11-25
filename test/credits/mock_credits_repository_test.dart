import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/data/mock_credits_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

MockCreditsRepository _repo([CreditsScenario scenario = CreditsScenario.normal, DateTime? now]) =>
    MockCreditsRepository(scenario: scenario, latency: Duration.zero, now: () => now ?? DateTime.utc(2026, 11, 25, 10));

void main() {
  test('the demo wallet is believable: separate available and pending, a streak, three missions, two badges', () async {
    final repo = _repo();
    final summary = _ok(await repo.summary());
    expect(summary.available, 150);
    expect(summary.pending, 25);
    expect(summary.balance, summary.available + summary.pending);
    expect(summary.rates.packSizes, [50, 100, 250]);
    expect(_ok(await repo.missions()), hasLength(3));
    expect(_ok(await repo.badges()), hasLength(2));
  });

  test('a redeem spends once per key and only for the rates pack sizes', () async {
    final repo = _repo();
    final first = _ok(await repo.redeem(credits: 50, idempotencyKey: 'key-aaaaaaaa'));
    final again = _ok(await repo.redeem(credits: 50, idempotencyKey: 'key-aaaaaaaa'));
    expect(again, first);
    expect(_ok(await repo.summary()).available, 100);
    expect(_failure(await repo.redeem(credits: 51, idempotencyKey: 'key-bbbbbbbb')), isA<PackNotOfferedFailure>());
    expect(_failure(await repo.redeem(credits: 250, idempotencyKey: 'key-cccccccc')), isA<InsufficientCreditsFailure>());
  });

  test('the Johannesburg day decides: 23:30 UTC is already the next day in South Africa', () async {
    final repo = _repo(CreditsScenario.normal, DateTime.utc(2026, 11, 25, 23, 30));
    expect(_ok(await repo.streak()).day, '2026-11-26');
  });

  test('a second check-in the same day answers claimed false and pays nothing more', () async {
    final repo = _repo();
    final first = _ok(await repo.claimToday(idempotencyKey: 'key-aaaaaaaa'));
    final second = _ok(await repo.claimToday(idempotencyKey: 'key-bbbbbbbb'));
    final replay = _ok(await repo.claimToday(idempotencyKey: 'key-aaaaaaaa'));
    expect(first.claimed, isTrue);
    expect(second.claimed, isFalse);
    expect(replay, first);
    expect(_ok(await repo.summary()).available, 150 + first.credits + first.bonusCredits);
  });

  test('the frozen, paused, capped and unavailable scenarios answer like the server', () async {
    expect(_ok(await _repo(CreditsScenario.frozen).summary()).frozen, isTrue);
    expect(_failure(await _repo(CreditsScenario.frozen).claimToday(idempotencyKey: 'key-aaaaaaaa')), isA<WalletFrozenFailure>());
    expect(_failure(await _repo(CreditsScenario.paused).redeem(credits: 50, idempotencyKey: 'key-aaaaaaaa')), isA<CreditsPausedFailure>());
    expect(_ok(await _repo(CreditsScenario.paused).summary()).available, 150, reason: 'reads work while paused');
    final capped = _ok(await _repo(CreditsScenario.capped).claimToday(idempotencyKey: 'key-aaaaaaaa'));
    expect(capped.cappedBy, 'overall_monthly');
    expect(capped.credits, 0);
    expect(_failure(await _repo(CreditsScenario.notAvailable).summary()), isA<CreditsNotAvailableFailure>());
  });

  test('the redeemed pass appears in the demo passes list, and a reset (sign-out) takes it and the spend away', () async {
    final repo = _repo();
    final passes = MockPassesRepository(extraPasses: () => repo.redeemedPasses);
    expect(_ok(await passes.getPasses()), hasLength(1));
    final pass = _ok(await repo.redeem(credits: 50, idempotencyKey: 'key-aaaaaaaa'));
    final listed = _ok(await passes.getPasses());
    expect(listed.map((p) => p.id), contains(pass.id));
    expect(listed, hasLength(2));
    await repo.claimToday(idempotencyKey: 'key-bbbbbbbb');
    repo.reset();
    expect(_ok(await repo.summary()).available, 150);
    expect(_ok(await repo.streak()).claimedToday, isFalse);
    expect(_ok(await passes.getPasses()), hasLength(1));
    // A key used before the reset is not remembered: it spends again, as a fresh account would.
    _ok(await repo.redeem(credits: 50, idempotencyKey: 'key-aaaaaaaa'));
    expect(_ok(await repo.summary()).available, 100);
  });
}
