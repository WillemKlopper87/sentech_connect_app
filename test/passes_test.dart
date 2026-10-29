import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/http_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_format.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';

/// Repository whose responses the test completes by hand.
class _ManualRepo extends PassesRepository {
  final calls = <(bool, Completer<Either<Failure, List<Pass>>>)>[];

  @override
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false}) {
    final c = Completer<Either<Failure, List<Pass>>>();
    calls.add((includeExpired, c));
    return c.future;
  }
}

class _LoadedRepo extends PassesRepository {
  _LoadedRepo(this.load);
  final PassLoad load;
  @override
  Future<Either<Failure, List<Pass>>> getPasses({
    bool includeExpired = false,
  }) async => Right(load.passes);
  @override
  Future<Either<Failure, PassLoad>> getPassLoad({
    bool includeExpired = false,
  }) async => Right(load);
}

Pass _pass(
  String id, {
  int? dataMb = 1024,
  int used = 0,
  PassStatus status = PassStatus.active,
  String name = 'Day Pass',
}) => Pass(
  id: id,
  orderId: 'o',
  productName: name,
  status: status,
  startsAt: DateTime.utc(2026, 10, 1, 10),
  expiresAt: DateTime.utc(2026, 10, 1, 12),
  durationMinutes: 120,
  dataMb: dataMb,
  maxDevices: 1,
  usedBytes: used,
);

void main() {
  group('HttpPassesRepository', () {
    late ApiHarness h;

    setUp(() async {
      h = ApiHarness();
      await h.signIn();
    });

    test('loads current entitlements for the signed-in customer', () async {
      h.adapter.on(
        'GET',
        '/v1/me/entitlements',
        (_) => FakeReply(200, fixture('entitlements_page.json')),
      );
      final passes = (await HttpPassesRepository(
        h.api,
      ).getPasses()).getOrElse((f) => throw StateError(f.message));
      expect(passes, hasLength(2));
      expect(passes.first.status, PassStatus.active);
      expect(passes.first.isCurrent, isTrue);
      expect(passes.first.dataUsedFraction, closeTo(0.25, 0.0001));
      expect(passes.first.expiresAt, DateTime.utc(2026, 10, 1, 11, 5));
      expect(
        h.adapter.requests.single.uri.queryParameters['status'],
        'current',
      );
      expect(
        h.adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('status=current returns a suspended pass past its expiry and keeps it suspended', () async {
      h.adapter.on(
        'GET',
        '/v1/me/entitlements',
        (_) => FakeReply(200, fixture('entitlements_current_suspended.json')),
      );
      final passes = (await HttpPassesRepository(
        h.api,
      ).getPasses()).getOrElse((f) => throw StateError(f.message));
      expect(h.adapter.requests.single.uri.queryParameters['status'], 'current');
      expect(passes.map((p) => p.status), [PassStatus.active, PassStatus.suspended]);
      final suspended = passes.last;
      expect(suspended.isCurrent, isFalse);
      expect(suspended.expiresAt.isBefore(DateTime.utc(2026, 10, 29)), isTrue);
    });

    test('"show expired" asks for all entitlements', () async {
      h.adapter.on(
        'GET',
        '/v1/me/entitlements',
        (_) => const FakeReply(200, {'items': <Object>[], 'next_cursor': null}),
      );
      await HttpPassesRepository(h.api).getPasses(includeExpired: true);
      expect(h.adapter.requests.single.uri.queryParameters['status'], 'all');
    });

    test('an unknown status is refused rather than shown as valid', () {
      final item = Map<String, Object?>.from(
        (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
      )..['status'] = 'paused';
      expect(() => passFromJson(item), throwsFormatException);
    });

    test('follows next_cursor across pages', () async {
      var calls = 0;
      h.adapter.on('GET', '/v1/me/entitlements', (req) {
        calls++;
        if (req.uri.queryParameters['cursor'] == 'c2') {
          return FakeReply(200, {
            'items': [
              (fixtureMap('entitlements_page.json')['items']! as List).last,
            ],
            'next_cursor': null,
          });
        }
        return FakeReply(200, {
          'items': [
            (fixtureMap('entitlements_page.json')['items']! as List).first,
          ],
          'next_cursor': 'c2',
        });
      });
      final passes = (await HttpPassesRepository(
        h.api,
      ).getPasses()).getOrElse((f) => throw StateError(f.message));
      expect(calls, 2);
      expect(passes.map((p) => p.status), [
        PassStatus.active,
        PassStatus.scheduled,
      ]);
    });

    test('a voucher pass has no order: null order_id and source voucher', () {
      final base = Map<String, Object?>.from(
        (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
      );
      final pass = passFromJson({
        ...base,
        'order_id': null,
        'source': 'voucher',
      });
      expect(pass.orderId, isNull);
      expect(pass.source, PassSource.voucher);
      expect(pass.isCurrent, isTrue);
    });

    test(
      'a missing source reads as an order pass, an unknown one as unknown',
      () {
        final base = Map<String, Object?>.from(
          (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
        )..remove('source');
        expect(passFromJson(base).source, PassSource.order);
        expect(
          passFromJson({...base, 'source': 'gift'}).source,
          PassSource.unknown,
        );
        expect(
          passFromJson({...base, 'order_id': null}).orderId,
          isNull,
          reason: 'order_id may be absent without a source too',
        );
      },
    );

    test('exhausted, expired and revoked are not current', () {
      final base = Map<String, Object?>.from(
        (fixtureMap('entitlements_page.json')['items']! as List).first as Map,
      );
      for (final status in ['exhausted', 'expired', 'revoked']) {
        expect(
          passFromJson({...base, 'status': status}).isCurrent,
          isFalse,
          reason: status,
        );
      }
    });
  });

  group('HttpPassesRepository pagination safety', () {
    late ApiHarness h;

    setUp(() async {
      h = ApiHarness();
      await h.signIn();
    });

    test(
      'a session switch between pages fails the load: no stale items, no request with the new credentials',
      () async {
        final item =
            (fixtureMap('entitlements_page.json')['items']! as List).first;
        h.adapter.on('GET', '/v1/me/entitlements', (req) async {
          if (req.uri.queryParameters['cursor'] == null) {
            // Customer B signs in right after page 1 is served.
            await h.tokens.write(
              AuthTokens(
                accessToken: 'B-access',
                refreshToken: 'B-refresh',
                accessExpiresAt: h.now.add(const Duration(minutes: 15)),
                customerId: 'customer-B',
                tenantSlug: 'sentech',
              ),
            );
            return FakeReply(200, {
              'items': [item],
              'next_cursor': 'c2',
            });
          }
          return FakeReply(200, {
            'items': [item],
            'next_cursor': null,
          });
        });
        final result = await HttpPassesRepository(h.api).getPasses();
        expect(result.isLeft(), isTrue);
        expect(
          h.adapter.requests.any(
            (r) => r.headers['Authorization'] == 'Bearer B-access',
          ),
          isFalse,
        );
      },
    );

    test('a repeated cursor fails instead of looping', () async {
      h.adapter.on(
        'GET',
        '/v1/me/entitlements',
        (_) =>
            const FakeReply(200, {'items': <Object>[], 'next_cursor': 'same'}),
      );
      expect((await HttpPassesRepository(h.api).getPasses()).isLeft(), isTrue);
      expect(h.adapter.requests.length, lessThanOrEqualTo(3));
    });

    test(
      'hitting the page cap is a failure, not a silently short list',
      () async {
        var n = 0;
        h.adapter.on(
          'GET',
          '/v1/me/entitlements',
          (_) =>
              FakeReply(200, {'items': <Object>[], 'next_cursor': 'c${n++}'}),
        );
        expect(
          (await HttpPassesRepository(h.api).getPasses()).isLeft(),
          isTrue,
        );
        expect(h.adapter.requests.length, HttpPassesRepository.maxPages);
      },
    );
  });

  group('PassesCubit', () {
    test('offline shows a retryable failure, then loads', () async {
      final network = SimulatedNetwork()..offline = true;
      final cubit = PassesCubit(MockPassesRepository(network: network));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, PassesStatus.failure);
      expect(cubit.state.failure, isA<NetworkFailure>());
      network.offline = false;
      await cubit.load();
      expect(cubit.state.status, PassesStatus.loaded);
      expect(cubit.state.passes, isNotEmpty);
      await cubit.close();
    });

    test('showing expired passes reloads with them included', () async {
      final cubit = PassesCubit(MockPassesRepository());
      await Future<void>.delayed(Duration.zero);
      final current = cubit.state.passes.length;
      await cubit.setIncludeExpired(true);
      expect(cubit.state.includeExpired, isTrue);
      expect(cubit.state.passes.length, greaterThan(current));
      await cubit.close();
    });

    test(
      'out-of-order responses are dropped: the newest request wins',
      () async {
        final repo = _ManualRepo();
        final cubit = PassesCubit(repo);
        addTearDown(cubit.close);
        final toggled = cubit.setIncludeExpired(true); // call 2
        final back = cubit.setIncludeExpired(false); // call 3
        expect(repo.calls, hasLength(3));
        repo.calls[2].$2.complete(Right([_pass('new')]));
        await back;
        repo.calls[1].$2.complete(Right([_pass('stale')]));
        repo.calls[0].$2.complete(Right([_pass('initial')]));
        await toggled;
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.passes.single.id, 'new');
        expect(cubit.state.includeExpired, isFalse);
      },
    );

    test(
      'a refresh with passes on screen does not drop to the loading state',
      () async {
        final repo = _ManualRepo();
        final cubit = PassesCubit(repo);
        addTearDown(cubit.close);
        repo.calls[0].$2.complete(Right([_pass('a')]));
        await Future<void>.delayed(Duration.zero);
        final states = <PassesStatus>[];
        final sub = cubit.stream.listen((s) => states.add(s.status));
        final refresh = cubit.load();
        expect(cubit.state.passes, isNotEmpty);
        repo.calls[1].$2.complete(Right([_pass('a')]));
        await refresh;
        await sub.cancel();
        expect(states, isNot(contains(PassesStatus.loading)));
      },
    );
  });

  group('My passes page', () {
    testWidgets(
      'idle clock reveals age, updates countdown, then ends the active badge',
      (tester) async {
        var now = DateTime.utc(2026, 10, 1, 11, 53);
        final cubit = PassesCubit(
          _LoadedRepo(
            PassLoad(passes: [_pass('idle', dataMb: null)], loadedAt: now),
          ),
        );
        addTearDown(cubit.close);
        await pumpThemed(
          tester,
          BlocProvider.value(
            value: cubit,
            child: MyPassesPage(now: () => now),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('7m left'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.textContaining('Updated'), findsNothing);
        now = now.add(const Duration(minutes: 6));
        await tester.pump(const Duration(minutes: 6));
        expect(find.text('Updated 6m ago'), findsOneWidget);
        expect(find.text('1m left'), findsOneWidget);
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 2));
        expect(find.text('Pass ended'), findsOneWidget);
        expect(find.text('Expired'), findsOneWidget);
        expect(find.text('Active'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
    Future<void> pumpPage(
      WidgetTester tester,
      PassesCubit cubit, {
      VoidCallback? onBuy,
    }) => pumpThemed(
      tester,
      BlocProvider.value(
        value: cubit,
        child: MyPassesPage(
          onBuyPass: onBuy,
          now: () => DateTime.utc(2026, 10, 1, 11),
        ),
      ),
    );

    testWidgets(
      'pull-to-refresh works on an empty list and the list stays visible while refreshing',
      (tester) async {
        final repo = _ManualRepo();
        final cubit = PassesCubit(repo);
        addTearDown(cubit.close);
        await pumpPage(tester, cubit);
        repo.calls[0].$2.complete(const Right(<Pass>[]));
        await tester.pumpAndSettle();
        expect(find.textContaining('no active passes'), findsOneWidget);
        expect(find.textContaining('Just paid?'), findsOneWidget);
        await tester.drag(
          find.byType(ListView),
          const Offset(0, 400),
          warnIfMissed: true,
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repo.calls, hasLength(2));
        repo.calls[1].$2.complete(Right([_pass('a')]));
        await tester.pumpAndSettle();
        expect(find.text('Day Pass'), findsOneWidget);
        // Refresh again: the card stays on screen, no full-page spinner.
        await tester.drag(
          find.byType(ListView),
          const Offset(0, 400),
          warnIfMissed: true,
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(repo.calls, hasLength(3));
        expect(find.text('Day Pass'), findsOneWidget);
        repo.calls[2].$2.complete(Right([_pass('a')]));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('the empty state offers a Buy a pass button', (tester) async {
      var bought = 0;
      final repo = _ManualRepo();
      final cubit = PassesCubit(repo);
      addTearDown(cubit.close);
      repo.calls[0].$2.complete(const Right(<Pass>[]));
      await pumpPage(tester, cubit, onBuy: () => bought++);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy a pass'));
      expect(bought, 1);
    });

    testWidgets('status-specific wording and data left', (tester) async {
      final repo = _ManualRepo();
      final cubit = PassesCubit(repo);
      addTearDown(cubit.close);
      await pumpPage(tester, cubit);
      repo.calls[0].$2.complete(
        Right([
          _pass(
            'a',
            dataMb: 1024,
            used: 2 * 1024 * 1024 * 1024,
          ), // over the cap
          _pass('b', status: PassStatus.expired, name: 'Old Pass'),
          _pass('c', status: PassStatus.exhausted, name: 'Full Pass'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^Expired \w')), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Ended \w')), findsOneWidget);
      expect(find.textContaining('ends '), findsOneWidget);
      expect(find.text('0 MB left'), findsOneWidget);
      expect(find.text('of 1 GB'), findsWidgets);
    });

    testWidgets('My passes labels a suspended pass and explains it', (tester) async {
      final repo = _ManualRepo();
      final cubit = PassesCubit(repo);
      addTearDown(cubit.close);
      await pumpPage(tester, cubit);
      repo.calls[0].$2.complete(
        Right([_pass('s', status: PassStatus.suspended, name: 'Fibre 50')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fibre 50'), findsOneWidget);
      expect(find.text('Service suspended'), findsWidgets);
      expect(find.textContaining('Your provider has paused this service'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('suspended pass past its expiry', () {
    testWidgets('My passes shows it as suspended, not expired, and offers no usage bar', (tester) async {
      final repo = _ManualRepo();
      final cubit = PassesCubit(repo);
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          // Two days after the pass's expires_at (12:00 on 1 Oct).
          child: MyPassesPage(now: () => DateTime.utc(2026, 10, 3, 12)),
        ),
      );
      repo.calls[0].$2.complete(
        Right([_pass('s', status: PassStatus.suspended, name: 'Fibre 50')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fibre 50'), findsOneWidget);
      expect(find.text('Service suspended'), findsWidgets);
      expect(find.textContaining('Your provider has paused this service'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Expired \w')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('formatting', () {
    late AppLocalizations l10n;

    setUp(
      () async =>
          l10n = await AppLocalizations.delegate.load(const Locale('en')),
    );

    test('time left is clamped at zero and localised', () {
      expect(formatTimeLeft(l10n, const Duration(minutes: -5)), '0m');
      expect(formatTimeLeft(l10n, const Duration(minutes: 35)), '35m');
      expect(
        formatTimeLeft(l10n, const Duration(hours: 2, minutes: 5)),
        '2h 5m',
      );
      expect(formatTimeLeft(l10n, const Duration(days: 3, hours: 4)), '3d 4h');
    });

    test(
      'data left never goes negative and uncapped passes have no data text',
      () {
        expect(
          dataLeftText(
            l10n,
            _pass('a', dataMb: 1024, used: 5 * 1024 * 1024 * 1024),
          ),
          '0 MB of 1 GB left',
        );
        expect(dataLeftText(l10n, _pass('a', dataMb: 0)), '0 MB of 0 MB left');
        expect(dataLeftText(l10n, _pass('a', dataMb: null)), isNull);
        expect(
          dataLeftText(l10n, _pass('a', dataMb: 5120, used: 1288490188)),
          '3.8 GB of 5 GB left',
        );
      },
    );
  });

  testWidgets('My passes lists each pass with its status and expiry', (
    tester,
  ) async {
    final cubit = PassesCubit(
      MockPassesRepository(now: () => DateTime.utc(2026, 10, 1, 12)),
    );
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      BlocProvider.value(
        value: cubit,
        child: MyPassesPage(now: () => DateTime.utc(2026, 10, 1, 12)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My passes'), findsOneWidget);
    expect(find.text('Day Pass'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('ends '), findsOneWidget);
  });
}
