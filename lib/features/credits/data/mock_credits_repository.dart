import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/core/time/sast.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

/// Named demo states for the Rewards screens. The demo flavor uses [normal];
/// tests choose the others.
enum CreditsScenario {
  /// A believable wallet, a streak, three missions and two badges.
  normal,

  /// The wallet is frozen: nothing can be earned or used.
  frozen,

  /// Credits are paused: reads work, redeeming and checking in answer the pause.
  paused,

  /// The monthly earning limit is reached: a check-in pays nothing.
  capped,

  /// The feature is off for this provider (every route answers "not available").
  notAvailable,

  /// Every read fails with a server error.
  failure,
}

/// Demo and test stand-in for the credits routes, with the server's rules: one
/// idempotency key gives one answer (a repeat never spends or pays twice), a
/// second check-in the same Johannesburg day answers `claimed: false`, and the
/// rates, not constants in the screens, say which packs exist. It does not add
/// the redeemed pass to the demo passes list (the demo passes are fixed, as for
/// the voucher demo).
class MockCreditsRepository implements CreditsRepository {
  MockCreditsRepository({
    this.scenario = CreditsScenario.normal,
    DateTime Function()? now,
    this.latency = const Duration(milliseconds: 300),
  }) : _now = now ?? DateTime.now;

  final CreditsScenario scenario;
  final DateTime Function() _now;
  final Duration latency;

  static const _rates = CreditRates(mbPerCredit: 1, adCredits: 2, packSizes: [50, 100, 250], expiryDays: 90);
  static const _rules = StreakRules(
    dailyCredits: 3,
    shortMilestoneDays: 7,
    shortMilestoneBonus: 10,
    longMilestoneDays: 30,
    longMilestoneBonus: 50,
    freezeCap: 2,
    silverStreakDays: 7,
    goldStreakDays: 30,
    silverPurchases: 2,
    goldPurchases: 5,
    tierWindowDays: 90,
  );

  int _available = 150;
  final int _pending = 25;
  int _run = 6;
  int _best = 9;
  int _total = 21;
  String? _claimedDay;
  final _entries = <CreditEntry>[];
  final _redeemByKey = <String, Pass>{};
  final _claimByKey = <String, ClaimResult>{};
  var _nextEntryId = 1000;

  bool get _frozen => scenario == CreditsScenario.frozen;

  String get _today => formatApiDate(sastDay(_now()));

  Future<Either<Failure, T>> _read<T>(T Function() build) async {
    await Future<void>.delayed(latency);
    return switch (scenario) {
      CreditsScenario.notAvailable => const Left(CreditsNotAvailableFailure()),
      CreditsScenario.failure => const Left(ServerFailure()),
      _ => Right(build()),
    };
  }

  Failure? _writeRefusal() => switch (scenario) {
    CreditsScenario.notAvailable => const CreditsNotAvailableFailure(),
    CreditsScenario.paused => const CreditsPausedFailure(Duration(minutes: 5)),
    CreditsScenario.frozen => const WalletFrozenFailure(),
    CreditsScenario.failure => const ServerFailure(),
    _ => null,
  };

  List<CreditEntry> _history() {
    final now = _now().toUtc();
    return [
      ..._entries,
      CreditEntry(id: 412, kind: CreditEntryKind.earn, credits: 3, source: 'streak', createdAt: now.subtract(const Duration(days: 1))),
      CreditEntry(id: 411, kind: CreditEntryKind.spend, credits: -50, source: 'pack_redemption', createdAt: now.subtract(const Duration(days: 2))),
      CreditEntry(id: 398, kind: CreditEntryKind.earn, credits: 10, source: 'mission', createdAt: now.subtract(const Duration(days: 5))),
    ];
  }

  StreakState _streakNow() {
    final claimed = _claimedDay == _today;
    return StreakState(
      day: _today,
      claimedToday: claimed,
      runDays: _run,
      bestRunDays: _best,
      freezes: 1,
      totalDays: _total,
      tier: CreditTier.silver,
      nextMilestoneInDays: _rules.shortMilestoneDays - _run % _rules.shortMilestoneDays,
      rules: _rules,
    );
  }

  @override
  Future<Either<Failure, CreditsSummary>> summary() => _read(
    () => CreditsSummary(
      balance: _available + _pending,
      available: _available,
      pending: _pending,
      expiring30d: 30,
      frozen: _frozen,
      caps: CreditCaps(
        adToday: 0,
        adDailyMax: 5,
        adMonth: 0,
        adMonthlyCap: 100,
        overallMonth: scenario == CreditsScenario.capped ? 300 : 40,
        overallMonthlyCap: 300,
      ),
      rates: _rates,
      tier: CreditTier.silver,
      streak: _run,
    ),
  );

  @override
  Future<Either<Failure, LedgerPage>> ledger({String? cursor}) =>
      _read(() => LedgerPage(items: cursor == null ? _history() : const []));

  @override
  Future<Either<Failure, Pass>> redeem({required int credits, required String idempotencyKey}) async {
    await Future<void>.delayed(latency);
    final earlier = _redeemByKey[idempotencyKey];
    if (earlier != null) return Right(earlier);
    if (_writeRefusal() case final refusal?) return Left(refusal);
    if (!_rates.packSizes.contains(credits)) return const Left(PackNotOfferedFailure());
    if (credits > _available) return const Left(InsufficientCreditsFailure());
    final now = _now().toUtc();
    _available -= credits;
    _entries.insert(
      0,
      CreditEntry(id: _nextEntryId++, kind: CreditEntryKind.spend, credits: -credits, source: 'pack_redemption', createdAt: now),
    );
    final pass = Pass(
      id: 'pass_credits_${_redeemByKey.length + 1}',
      productName: 'Connect credits pack',
      source: PassSource.credits,
      status: PassStatus.active,
      startsAt: now,
      expiresAt: now.add(const Duration(minutes: 1440)),
      durationMinutes: 1440,
      dataMb: _rates.megabytesFor(credits),
      speedKbps: 10240,
      maxDevices: 1,
      origin: PassOrigin.credits,
    );
    _redeemByKey[idempotencyKey] = pass;
    return Right(pass);
  }

  @override
  Future<Either<Failure, StreakState>> streak() => _read(_streakNow);

  @override
  Future<Either<Failure, ClaimResult>> claimToday({required String idempotencyKey}) async {
    await Future<void>.delayed(latency);
    final earlier = _claimByKey[idempotencyKey];
    if (earlier != null) return Right(earlier);
    if (_writeRefusal() case final refusal?) return Left(refusal);
    final first = _claimedDay != _today;
    if (first) {
      _claimedDay = _today;
      _run += 1;
      _best = _run > _best ? _run : _best;
      _total += 1;
    }
    final capped = scenario == CreditsScenario.capped;
    final milestone = first && _run % _rules.shortMilestoneDays == 0;
    final paid = first && !capped ? _rules.dailyCredits : 0;
    final bonus = milestone && !capped ? _rules.shortMilestoneBonus : 0;
    _available += paid + bonus;
    if (paid + bonus > 0) {
      _entries.insert(
        0,
        CreditEntry(
          id: _nextEntryId++,
          kind: CreditEntryKind.earn,
          credits: paid + bonus,
          source: 'streak',
          createdAt: _now().toUtc(),
        ),
      );
    }
    final result = ClaimResult(
      claimed: first,
      credits: first ? paid : _rules.dailyCredits,
      bonusCredits: bonus,
      freezesUsed: 0,
      milestones: milestone ? [_rules.shortMilestoneDays] : const [],
      cappedBy: capped && first ? 'overall_monthly' : null,
      streak: _streakNow(),
    );
    _claimByKey[idempotencyKey] = result;
    return Right(result);
  }

  @override
  Future<Either<Failure, List<Mission>>> missions() => _read(
    () => [
      Mission(
        key: 'first_checkin',
        window: 'once',
        windowKey: 'all',
        target: 1,
        progress: 1,
        rewardCredits: 3,
        status: MissionStatus.completed,
        completedAt: _now().toUtc().subtract(const Duration(days: 20)),
      ),
      const Mission(
        key: 'checkins_20',
        window: 'monthly',
        windowKey: '2026-11',
        target: 20,
        progress: 12,
        rewardCredits: 10,
        status: MissionStatus.inProgress,
      ),
      const Mission(
        key: 'first_purchase',
        window: 'once',
        windowKey: 'all',
        target: 1,
        progress: 0,
        rewardCredits: 10,
        status: MissionStatus.inProgress,
      ),
    ],
  );

  @override
  Future<Either<Failure, List<CreditBadge>>> badges() => _read(
    () => [
      CreditBadge(
        key: 'first_checkin',
        target: 1,
        progress: 1,
        earned: true,
        awardedAt: _now().toUtc().subtract(const Duration(days: 20)),
      ),
      const CreditBadge(key: 'streak_7', target: 7, progress: 6, earned: false),
    ],
  );
}
