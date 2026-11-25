import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/data/http_credits_repository.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

import '../helpers/api_harness.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

void main() {
  late ApiHarness h;
  late HttpCreditsRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpCreditsRepository(h.api);
  });

  group('summary', () {
    test('parses the wallet with a tier and a streak, from the server numbers only', () async {
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply(200, fixture('credits_summary.json')));
      final summary = _ok(await repo.summary());
      expect(summary.balance, 175);
      expect(summary.available, 150);
      expect(summary.pending, 25);
      expect(summary.expiring30d, 30);
      expect(summary.tier, CreditTier.silver);
      expect(summary.streak, 6);
      expect(summary.rates.packSizes, [50, 100, 250]);
      expect(summary.rates.expiryDays, 90);
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('parses_summary_with_null_tier_and_streak', () async {
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply(200, fixture('credits_summary_frozen.json')));
      final summary = _ok(await repo.summary());
      expect(summary.frozen, isTrue);
      expect(summary.tier, isNull);
      expect(summary.streak, isNull);
      expect(summary.rates.packSizes, [100, 500]);
    });

    test('an unfamiliar tier shows no tier instead of failing the wallet', () async {
      final body = {...fixtureMap('credits_summary.json'), 'tier': 'platinum'};
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply(200, body));
      expect(_ok(await repo.summary()).tier, isNull);
    });

    test('an older server without the route maps to feature unavailable, not a crash', () async {
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply.problem(404, 'not_found', title: 'Not Found'));
      expect(_failure(await repo.summary()), isA<CreditsNotAvailableFailure>());
    });

    test('the flag off (409 feature_disabled) and the module off (403 module_not_enabled) are feature unavailable', () async {
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply.problem(409, 'feature_disabled'));
      expect(_failure(await repo.summary()), isA<CreditsNotAvailableFailure>());
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply.problem(403, 'module_not_enabled'));
      expect(_failure(await repo.summary()), isA<CreditsNotAvailableFailure>());
    });

    test('a 409 feature_disabled tells the app to hide the credits module at once; a 404 does not', () async {
      final refused = <String>[];
      final withHook = HttpCreditsRepository(h.api, onModuleRefused: refused.add);
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply.problem(409, 'feature_disabled'));
      expect(_failure(await withHook.summary()), isA<CreditsNotAvailableFailure>());
      expect(refused, ['credits']);
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply.problem(404, 'not_found'));
      await withHook.summary();
      expect(refused, ['credits'], reason: 'an older server is not a switched-off provider');
    });

    test('a server error stays a server failure, not a hidden feature', () async {
      h.adapter.on('GET', HttpCreditsRepository.creditsPath, (_) => FakeReply.problem(500, 'internal'));
      expect(_failure(await repo.summary()), isA<ServerFailure>());
    });

    test('a body with an unknown entry kind still loads: the line is kept as unknown, not a failure', () async {
      h.adapter.on('GET', HttpCreditsRepository.ledgerPath, (_) {
        final page = fixtureMap('credits_ledger_page_1.json');
        final items = [...(page['items']! as List)];
        items[0] = {...Map<String, Object?>.from(items[0] as Map), 'kind': 'gift'};
        return FakeReply(200, {...page, 'items': items});
      });
      final page = _ok(await repo.ledger());
      expect(page.items.first.kind, CreditEntryKind.unknown);
      expect(page.items.first.source, 'streak');
      expect(page.items, hasLength(2));
    });

    test('an unknown streak tier and an unknown mission status load as unknown members', () async {
      h.adapter.on('GET', HttpCreditsRepository.streakPath, (_) => FakeReply(200, {...fixtureMap('credits_streak.json'), 'tier': 'platinum'}));
      expect(_ok(await repo.streak()).tier, CreditTier.unknown);
      h.adapter.on('GET', HttpCreditsRepository.missionsPath, (_) {
        final item = {...Map<String, Object?>.from((fixtureMap('credits_missions.json')['items']! as List).first as Map), 'status': 'paused'};
        return FakeReply(200, {'items': [item]});
      });
      expect(_ok(await repo.missions()).single.status, MissionStatus.unknown);
    });
  });

  group('ledger', () {
    test('ledger_follows_next_cursor', () async {
      h.adapter.on('GET', HttpCreditsRepository.ledgerPath, (request) {
        final cursor = request.queryParameters['cursor'];
        return FakeReply(200, fixture(cursor == null ? 'credits_ledger_page_1.json' : 'credits_ledger_page_2.json'));
      });
      final first = _ok(await repo.ledger());
      expect(first.items.first.kind, CreditEntryKind.earn);
      expect(first.items[1].credits, -50);
      expect(first.nextCursor, isNotNull);
      final second = _ok(await repo.ledger(cursor: first.nextCursor));
      expect(second.items.last.kind, CreditEntryKind.expire);
      expect(second.nextCursor, isNull);
      final requests = h.adapter.requestsTo('GET', HttpCreditsRepository.ledgerPath);
      expect(requests.first.queryParameters.containsKey('cursor'), isFalse);
      expect(requests.last.queryParameters['cursor'], first.nextCursor);
    });
  });

  group('redeem', () {
    test('redeem_sends_the_idempotency_key_header and returns the new pass', () async {
      h.adapter.on('POST', HttpCreditsRepository.redeemPath, (_) => FakeReply(201, fixture('credits_redeem_pass.json')));
      final pass = _ok(await repo.redeem(credits: 50, idempotencyKey: 'app-key-0000001'));
      expect(pass.origin, PassOrigin.credits);
      expect(pass.dataMb, 50);
      final request = h.adapter.requestsTo('POST', HttpCreditsRepository.redeemPath).single;
      expect(request.data, {'credits': 50});
      expect(request.headers['Idempotency-Key'], 'app-key-0000001');
      expect(request.headers['Authorization'], 'Bearer access-1');
    });

    test('maps_wallet_frozen_to_a_typed_failure', () async {
      h.adapter.on('POST', HttpCreditsRepository.redeemPath, (_) => FakeReply.problem(409, 'wallet_frozen'));
      expect(_failure(await repo.redeem(credits: 50, idempotencyKey: 'app-key-0000001')), isA<WalletFrozenFailure>());
    });

    test('maps the other refusals to typed failures', () async {
      final cases = <(int, String, Type)>[
        (409, 'customer_inactive', CustomerInactiveFailure),
        (409, 'insufficient_credits', InsufficientCreditsFailure),
        (409, 'redemption_limit_reached', RedemptionLimitReachedFailure),
        (422, 'pack_not_offered', PackNotOfferedFailure),
        (409, 'idempotency_in_progress', IdempotencyInProgressFailure),
      ];
      for (final (status, code, type) in cases) {
        h.adapter.on('POST', HttpCreditsRepository.redeemPath, (_) => FakeReply.problem(status, code));
        final failure = _failure(await repo.redeem(credits: 50, idempotencyKey: 'app-key-0000001'));
        expect(failure.runtimeType, type, reason: code);
      }
    });

    test('a pause is a typed failure that keeps the Retry-After hint', () async {
      h.adapter.on(
        'POST',
        HttpCreditsRepository.redeemPath,
        (_) => FakeReply.problem(503, 'credits_paused', headers: {'retry-after': ['300']}),
      );
      final failure = _failure(await repo.redeem(credits: 50, idempotencyKey: 'app-key-0000001'));
      expect(failure, isA<CreditsPausedFailure>());
      expect((failure! as CreditsPausedFailure).retryAfter, const Duration(seconds: 300));
    });

    test('an older server without the route maps to feature unavailable', () async {
      h.adapter.on('POST', HttpCreditsRepository.redeemPath, (_) => FakeReply.problem(404, 'not_found'));
      expect(_failure(await repo.redeem(credits: 50, idempotencyKey: 'app-key-0000001')), isA<CreditsNotAvailableFailure>());
    });
  });

  group('streak and check-in', () {
    test('reads the streak with the server day', () async {
      h.adapter.on('GET', HttpCreditsRepository.streakPath, (_) => FakeReply(200, fixture('credits_streak.json')));
      final streak = _ok(await repo.streak());
      expect(streak.day, '2026-11-25');
      expect(streak.claimedToday, isFalse);
      expect(streak.runDays, 6);
      expect(streak.rules.dailyCredits, 3);
      expect(streak.tier, CreditTier.silver);
    });

    test('the claim sends the Idempotency-Key and no body, and decodes a capped result', () async {
      h.adapter.on('POST', HttpCreditsRepository.claimPath, (_) => FakeReply(200, fixture('streak_claim_capped.json')));
      final result = _ok(await repo.claimToday(idempotencyKey: 'app-key-0000002'));
      expect(result.claimed, isTrue);
      expect(result.credits, 0);
      expect(result.cappedBy, 'overall_monthly');
      final request = h.adapter.requestsTo('POST', HttpCreditsRepository.claimPath).single;
      expect(request.headers['Idempotency-Key'], 'app-key-0000002');
      expect(request.data, isNull);
    });

    test('a second claim the same day answers claimed false with what the first one paid', () async {
      h.adapter.on('POST', HttpCreditsRepository.claimPath, (_) => FakeReply(200, fixture('streak_claim_repeat.json')));
      final result = _ok(await repo.claimToday(idempotencyKey: 'app-key-0000003'));
      expect(result.claimed, isFalse);
      expect(result.credits, 3);
    });

    test('a frozen wallet and a refused check-in are typed', () async {
      h.adapter.on('POST', HttpCreditsRepository.claimPath, (_) => FakeReply.problem(409, 'wallet_frozen'));
      expect(_failure(await repo.claimToday(idempotencyKey: 'app-key-0000004')), isA<WalletFrozenFailure>());
      h.adapter.on('POST', HttpCreditsRepository.claimPath, (_) => FakeReply.problem(409, 'earn_refused'));
      expect(_failure(await repo.claimToday(idempotencyKey: 'app-key-0000004')), isA<EarnRefusedFailure>());
    });
  });

  group('missions and badges', () {
    test('missions carry the server progress and status', () async {
      h.adapter.on('GET', HttpCreditsRepository.missionsPath, (_) => FakeReply(200, fixture('credits_missions.json')));
      final missions = _ok(await repo.missions());
      expect(missions.map((m) => m.status), [MissionStatus.completed, MissionStatus.inProgress, MissionStatus.ready]);
      expect(missions[1].progress, 12);
      expect(missions[1].target, 20);
    });

    test('badges decode earned and not earned', () async {
      h.adapter.on('GET', HttpCreditsRepository.badgesPath, (_) => FakeReply(200, fixture('credits_badges.json')));
      final badges = _ok(await repo.badges());
      expect(badges.map((b) => b.earned), [true, false]);
      expect(badges.first.awardedAt, DateTime.utc(2026, 11, 4, 7));
    });
  });
}
