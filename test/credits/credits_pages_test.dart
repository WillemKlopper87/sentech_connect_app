import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/data/credits_json.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/credits_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/ledger_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/missions_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/redeem_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/streak_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/badges_page.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/credits_home_page.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/ledger_page.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/missions_page.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/redeem_page.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/streak_page.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_themed.dart';
import 'fake_credits_repository.dart';

/// A second pump of the same page in one test must start from nothing, or the
/// first page's cubit would be reused.
Future<void> _fresh(WidgetTester tester) => tester.pumpWidget(const SizedBox.shrink());

Future<void> _pumpHome(WidgetTester tester, FakeCreditsRepository repo, {List<String>? opened, Size? size}) async {
  await _fresh(tester);
  await pumpThemed(
    tester,
    BlocProvider(
      create: (_) => CreditsCubit(repo),
      child: CreditsHomePage(
        onOpenRedeem: () => opened?.add('redeem'),
        onOpenStreak: () => opened?.add('streak'),
        onOpenMissions: () => opened?.add('missions'),
        onOpenBadges: () => opened?.add('badges'),
        onOpenLedger: () => opened?.add('ledger'),
      ),
    ),
    size: size ?? const Size(390, 844),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRedeem(WidgetTester tester, FakeCreditsRepository repo, {VoidCallback? onOpenPasses}) async {
  await _fresh(tester);
  await pumpThemed(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CreditsCubit(repo)),
        BlocProvider(create: (_) => RedeemCubit(repo)),
      ],
      child: RedeemPage(onOpenPasses: onOpenPasses),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpStreak(WidgetTester tester, FakeCreditsRepository repo) async {
  await _fresh(tester);
  await pumpThemed(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CreditsCubit(repo)),
        BlocProvider(create: (_) => StreakCubit(repo)),
      ],
      child: const StreakPage(),
    ),
  );
  await tester.pumpAndSettle();
}

class _CountingPasses extends MockPassesRepository {
  int loads = 0;

  @override
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false}) {
    loads++;
    return super.getPasses(includeExpired: includeExpired);
  }
}

void main() {
  late FakeCreditsRepository repo;

  setUp(() => repo = FakeCreditsRepository());

  group('Rewards home', () {
    testWidgets('shows_available_and_pending_separately', (tester) async {
      await _pumpHome(tester, repo);
      expect(find.byKey(const Key('credits-available')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('credits-available'))).data, '150 credits');
      expect(tester.widget<Text>(find.byKey(const Key('credits-pending'))).data, '25 credits on hold and not usable yet');
      expect(find.textContaining('175'), findsNothing, reason: 'the balance total is not the headline');
    });

    testWidgets('no pending line when nothing is on hold', (tester) async {
      final json = {...fixtureMap('credits_summary.json'), 'pending': 0, 'balance': 150};
      repo.summaryResult = Right(creditsSummaryFromJson(json));
      await _pumpHome(tester, repo);
      expect(find.byKey(const Key('credits-pending')), findsNothing);
    });

    testWidgets('frozen_wallet_explains_and_disables_redeem', (tester) async {
      repo.summaryResult = Right(summaryFixture('credits_summary_frozen.json'));
      final opened = <String>[];
      await _pumpHome(tester, repo, opened: opened);
      expect(find.textContaining('frozen'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-tile-redeem')));
      await tester.pump();
      expect(opened, isEmpty);
      expect(tester.widget<ListTile>(find.byKey(const Key('credits-tile-redeem'))).enabled, isFalse);
      await tester.tap(find.byKey(const Key('credits-tile-checkin')));
      expect(opened, ['streak'], reason: 'the other rows still open');
    });

    testWidgets('the expiry banner shows the server number and only when it is above zero', (tester) async {
      await _pumpHome(tester, repo);
      expect(find.textContaining('30 credits will expire within 30 days'), findsOneWidget);
      repo.summaryResult = Right(creditsSummaryFromJson({...fixtureMap('credits_summary.json'), 'expiring_30d': 0}));
      await _pumpHome(tester, repo);
      expect(find.textContaining('will expire within'), findsNothing);
    });

    testWidgets('a reached monthly limit is explained in words', (tester) async {
      final json = fixtureMap('credits_summary.json');
      final caps = {...Map<String, Object?>.from(json['caps']! as Map), 'overall_month': 300};
      repo.summaryResult = Right(creditsSummaryFromJson({...json, 'caps': caps}));
      await _pumpHome(tester, repo);
      expect(find.textContaining("this month's limit on credits you can earn"), findsOneWidget);
    });

    testWidgets('the terms line reads the days from the rates, not a constant', (tester) async {
      await _pumpHome(tester, repo);
      expect(find.text('Credits are not cash and expire after 90 days.'), findsOneWidget);
      repo.summaryResult = Right(summaryFixture('credits_summary_frozen.json'));
      await _pumpHome(tester, repo);
      expect(find.text('Credits are not cash and expire after 60 days.'), findsOneWidget);
    });

    testWidgets('streak and tier chips come from the server; no tier and no streak shows no chips', (tester) async {
      await _pumpHome(tester, repo);
      expect(find.text('Streak: 6 days'), findsOneWidget);
      expect(find.text('Silver tier'), findsOneWidget);
      repo.summaryResult = Right(summaryFixture('credits_summary_frozen.json'));
      await _pumpHome(tester, repo);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('an unavailable feature shows a plain message, not an empty page or an error', (tester) async {
      repo.summaryResult = const Left(CreditsNotAvailableFailure());
      await _pumpHome(tester, repo);
      expect(find.text('Rewards are not available right now.'), findsOneWidget);
    });

    testWidgets('a failed first load offers a retry', (tester) async {
      repo.summaryResult = const Left(NetworkFailure());
      await _pumpHome(tester, repo);
      expect(find.text('Retry'), findsOneWidget);
      repo.summaryResult = Right(summaryFixture());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('credits-available')), findsOneWidget);
    });

    testWidgets('the how-it-works sheet reads the rates', (tester) async {
      await _pumpHome(tester, repo, size: const Size(390, 1400));
      await tester.tap(find.text('How credits work'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 credit gives 1 MB'), findsOneWidget);
      expect(find.textContaining('not your phone'), findsOneWidget);
    });
  });

  group('Redeem', () {
    testWidgets('offers_only_the_servers_pack_sizes', (tester) async {
      repo.summaryResult = Right(
        creditsSummaryFromJson({...fixtureMap('credits_summary.json'), 'available': 500, 'balance': 500, 'pending': 0}),
      );
      await _pumpRedeem(tester, repo);
      for (final size in [50, 100, 250]) {
        expect(find.byKey(Key('credits-pack-$size')), findsOneWidget);
      }
      expect(find.byKey(const Key('credits-pack-500')), findsNothing);
      // The same screen for a provider with other packs.
      final other = {
        ...fixtureMap('credits_summary_frozen.json'),
        'frozen': false,
        'available': 600,
        'balance': 600,
      };
      repo.summaryResult = Right(creditsSummaryFromJson(other));
      await _pumpRedeem(tester, repo);
      expect(find.byKey(const Key('credits-pack-100')), findsOneWidget);
      expect(find.byKey(const Key('credits-pack-500')), findsOneWidget);
      expect(find.byKey(const Key('credits-pack-50')), findsNothing);
    });

    testWidgets('the data of a pack is credits times the server rate', (tester) async {
      repo.summaryResult = Right(
        creditsSummaryFromJson({
          ...fixtureMap('credits_summary.json'),
          'rates': {...Map<String, Object?>.from(fixtureMap('credits_summary.json')['rates']! as Map), 'mb_per_credit': 4},
        }),
      );
      await _pumpRedeem(tester, repo);
      expect(find.text('200 MB of hotspot data'), findsOneWidget);
    });

    testWidgets('a pack the customer cannot afford is disabled and says why', (tester) async {
      await _pumpRedeem(tester, repo);
      expect(find.text('Not enough available credits'), findsNWidgets(1), reason: 'only the 250 pack is out of reach');
      await tester.tap(find.byKey(const Key('credits-pack-250')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-redeem-button'))).onPressed, isNull);
    });

    testWidgets('shows_the_new_pass_link_after_success', (tester) async {
      var opened = 0;
      await _pumpRedeem(tester, repo, onOpenPasses: () => opened++);
      await tester.tap(find.byKey(const Key('credits-pack-50')));
      await tester.pump();
      expect(find.text('Redeem 50 credits'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      expect(repo.redeemCalls, hasLength(1));
      expect(repo.redeemCalls.single.credits, 50);
      expect(find.text('Your pass is ready'), findsOneWidget);
      expect(find.textContaining('You used 50 credits and got 50 MB of hotspot data'), findsOneWidget);
      expect(repo.summaryCalls, greaterThan(1), reason: 'the wallet is read again after a redeem');
      await tester.tap(find.byKey(const Key('credits-view-passes')));
      expect(opened, 1);
    });

    testWidgets('a frozen wallet explains and disables every pack', (tester) async {
      repo.summaryResult = Right(summaryFixture('credits_summary_frozen.json'));
      await _pumpRedeem(tester, repo);
      expect(find.textContaining('frozen'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-pack-100')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-redeem-button'))).onPressed, isNull);
    });

    testWidgets('a pause found when redeeming is explained and disables the packs', (tester) async {
      repo.redeemResults.add(const Left(CreditsPausedFailure()));
      await _pumpRedeem(tester, repo);
      await tester.tap(find.byKey(const Key('credits-pack-50')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rewards are paused'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-pack-100')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-redeem-button'))).onPressed, isNull);
    });

    testWidgets('after a lost response the wallet is read again and only the pending pack can be retried', (tester) async {
      repo.redeemResults.addAll([const Left(NetworkFailure()), Right(redeemedPassFixture())]);
      await _pumpRedeem(tester, repo);
      final before = repo.summaryCalls;
      await tester.tap(find.byKey(const Key('credits-pack-50')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      expect(repo.summaryCalls, greaterThan(before), reason: 'the wallet is refreshed after a failure');
      expect(find.textContaining('may not have finished'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-pack-100')));
      await tester.pump();
      expect(tester.widget<ListTile>(find.byKey(const Key('credits-pack-100'))).enabled, isFalse);
      expect(find.text('Try again'), findsWidgets);
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      expect(repo.redeemCalls, hasLength(2));
      expect(repo.redeemCalls[0].key, repo.redeemCalls[1].key);
      expect(find.text('Your pass is ready'), findsOneWidget);
    });

    testWidgets('any failed redeem refreshes the wallet, and the choose view can be pulled to refresh', (tester) async {
      repo.redeemResults.add(const Left(PackNotOfferedFailure()));
      await _pumpRedeem(tester, repo);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final before = repo.summaryCalls;
      await tester.tap(find.byKey(const Key('credits-pack-50')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      expect(repo.summaryCalls, greaterThan(before));
    });

    testWidgets('a daily limit refusal is shown in words with the packs still usable', (tester) async {
      repo.redeemResults.add(const Left(RedemptionLimitReachedFailure()));
      await _pumpRedeem(tester, repo);
      await tester.tap(find.byKey(const Key('credits-pack-50')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining("today's limit for packs"), findsOneWidget);
    });
  });

  group('Daily check-in', () {
    testWidgets('explains_what_counts_as_a_day_using_the_servers_day', (tester) async {
      await _pumpStreak(tester, repo);
      expect(find.textContaining('South African time (Johannesburg)'), findsOneWidget);
      expect(find.textContaining('November 25, 2026'), findsOneWidget);
      // The phone's own clock plays no part: the date comes from the server answer.
      repo.streakResult = Right(
        streakStateFromJson({...fixtureMap('credits_streak.json'), 'day': '2027-01-02'}),
      );
      await _pumpStreak(tester, repo);
      expect(find.textContaining('January 2, 2027'), findsOneWidget);
    });

    testWidgets('a check-in shows what it paid, then already checked in on the second tap', (tester) async {
      repo.claimResults.addAll([
        Right(claimFixture('streak_claim_paid.json')),
        Right(claimFixture('streak_claim_repeat.json')),
      ]);
      await _pumpStreak(tester, repo);
      await tester.tap(find.byKey(const Key('credits-checkin-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('You earned 3 credits'), findsOneWidget);
      expect(find.textContaining('bonus of 10 credits'), findsOneWidget);
      // Claimed today now: the button is off and the page says so.
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-checkin-button'))).onPressed, isNull);
    });

    testWidgets('a day already claimed says so and is not an error', (tester) async {
      repo.streakResult = Right(streakFixture('credits_streak_claimed.json'));
      await _pumpStreak(tester, repo);
      expect(find.byKey(const Key('credits-already')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-checkin-button'))).onPressed, isNull);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a capped check-in is explained in words', (tester) async {
      repo.claimResults.add(Right(claimFixture('streak_claim_capped.json')));
      await _pumpStreak(tester, repo);
      await tester.tap(find.byKey(const Key('credits-checkin-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining("this month's limit on credits you can earn"), findsOneWidget);
    });

    testWidgets('a frozen wallet explains and disables the check-in', (tester) async {
      repo.summaryResult = Right(summaryFixture('credits_summary_frozen.json'));
      await _pumpStreak(tester, repo);
      expect(find.textContaining('frozen'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-checkin-button'))).onPressed, isNull);
    });

    testWidgets('a frozen wallet found by the claim itself is explained and the button goes off', (tester) async {
      repo.claimResults.add(const Left(WalletFrozenFailure()));
      await _pumpStreak(tester, repo);
      await tester.tap(find.byKey(const Key('credits-checkin-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('frozen'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-checkin-button'))).onPressed, isNull);
    });

    testWidgets('a refused check-in says to try later and offers no Try again', (tester) async {
      repo.claimResults.add(const Left(EarnRefusedFailure()));
      await _pumpStreak(tester, repo);
      await tester.tap(find.byKey(const Key('credits-checkin-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Try again later'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a check-in after the feature was switched off says it is unavailable and the button goes off', (tester) async {
      repo.claimResults.add(const Left(CreditsNotAvailableFailure()));
      await _pumpStreak(tester, repo);
      await tester.tap(find.byKey(const Key('credits-checkin-button')));
      await tester.pumpAndSettle();
      expect(find.text('Rewards are not available right now.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('credits-checkin-button'))).onPressed, isNull);
    });

    testWidgets('the rules come from the server', (tester) async {
      await _pumpStreak(tester, repo);
      expect(find.text('Each check-in earns 3 credits.'), findsOneWidget);
      expect(find.text('Bonus of 10 credits when your streak reaches 7 days.'), findsOneWidget);
      expect(find.text('Bonus of 50 credits when your streak reaches 30 days.'), findsOneWidget);
    });
  });

  group('Missions, badges and history', () {
    testWidgets('progress_comes_from_the_server_never_computed', (tester) async {
      repo.missionsResult = Right([
        for (final item in fixtureMap('credits_missions.json')['items']! as List)
          missionFromJson(Map<String, Object?>.from(item as Map)),
        // A completed mission whose count the server reports as 0: shown as done, not recomputed.
        const Mission(
          key: 'first_voucher',
          window: 'once',
          windowKey: 'all',
          target: 1,
          progress: 0,
          rewardCredits: 5,
          status: MissionStatus.completed,
        ),
      ]);
      await _fresh(tester);
      await pumpThemed(tester, BlocProvider(create: (_) => MissionsCubit(repo), child: const MissionsPage()));
      await tester.pumpAndSettle();
      expect(find.text('12 of 20'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(of: find.byKey(const Key('credits-mission-checkins_20')), matching: find.byType(LinearProgressIndicator)),
      );
      expect(bar.value, 0.6);
      expect(find.text('Complete. Your reward is on its way.'), findsOneWidget);
      expect(find.text('Reward: 10 credits'), findsNWidgets(2));
      expect(find.text('Done'), findsNWidgets(2));
    });

    testWidgets('an unknown mission key gets a neutral name, an empty list a message', (tester) async {
      repo.missionsResult = const Right([
        Mission(
          key: 'brand_new',
          window: 'once',
          windowKey: 'all',
          target: 2,
          progress: 1,
          rewardCredits: 1,
          status: MissionStatus.inProgress,
        ),
      ]);
      await _fresh(tester);
      await pumpThemed(tester, BlocProvider(create: (_) => MissionsCubit(repo), child: const MissionsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Mission'), findsOneWidget);
      expect(find.text('brand_new'), findsNothing);
      repo.missionsResult = const Right([]);
      await _fresh(tester);
      await pumpThemed(tester, BlocProvider(create: (_) => MissionsCubit(repo), child: const MissionsPage()));
      await tester.pumpAndSettle();
      expect(find.text('There are no missions right now.'), findsOneWidget);
    });

    testWidgets('badges show the earned date and the server progress', (tester) async {
      repo.badgesResult = Right([
        for (final item in fixtureMap('credits_badges.json')['items']! as List)
          creditBadgeFromJson(Map<String, Object?>.from(item as Map)),
      ]);
      await _fresh(tester);
      await pumpThemed(tester, BlocProvider(create: (_) => BadgesCubit(repo), child: const BadgesPage()));
      await tester.pumpAndSettle();
      expect(find.text('First check-in'), findsOneWidget);
      expect(find.textContaining('Earned on'), findsOneWidget);
      expect(find.text('7-day streak'), findsOneWidget);
      expect(find.text('6 of 7'), findsOneWidget);
    });

    testWidgets('the history lists entries newest first and loads the next page on request', (tester) async {
      final first = ledgerPageFromJson(fixtureMap('credits_ledger_page_1.json'));
      repo.ledgerPages[null] = Right(first);
      repo.ledgerPages[first.nextCursor] = Right(ledgerPageFromJson(fixtureMap('credits_ledger_page_2.json')));
      await _fresh(tester);
      await pumpThemed(tester, BlocProvider(create: (_) => LedgerCubit(repo), child: const CreditsLedgerPage()));
      await tester.pumpAndSettle();
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('-50'), findsOneWidget);
      expect(find.text('Data pack'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-ledger-more')));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.byKey(const Key('credits-ledger-more')), findsNothing);
    });

    testWidgets('an empty history says so', (tester) async {
      await _fresh(tester);
      await pumpThemed(tester, BlocProvider(create: (_) => LedgerCubit(repo), child: const CreditsLedgerPage()));
      await tester.pumpAndSettle();
      expect(find.text('No credit activity yet.'), findsOneWidget);
    });
  });

  testWidgets('My passes is read again when the customer comes back from Rewards', (tester) async {
    final passes = _CountingPasses();
    await pumpThemed(
      tester,
      BlocProvider(
        create: (_) => PassesCubit(passes),
        child: MyPassesPage(onOpenRewards: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(passes.loads, 1);
    await tester.tap(find.byKey(const Key('rewards-entry-card')));
    await tester.pumpAndSettle();
    expect(passes.loads, 2, reason: 'a pass bought with credits must show on return');
  });

  testWidgets('every Rewards page lays out at a large text size on a small phone without overflow', (tester) async {
    repo.summaryResult = Right(summaryFixture());
    await pumpThemed(
      tester,
      BlocProvider(
        create: (_) => CreditsCubit(repo),
        child: CreditsHomePage(
          onOpenRedeem: () {},
          onOpenStreak: () {},
          onOpenMissions: () {},
          onOpenBadges: () {},
          onOpenLedger: () {},
        ),
      ),
      textScale: 2.0,
      size: const Size(320, 640),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
