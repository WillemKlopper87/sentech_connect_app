import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/http_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

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
  });

  testWidgets('My passes lists each pass with its status and expiry', (
    tester,
  ) async {
    final cubit = PassesCubit(
      MockPassesRepository(now: () => DateTime.utc(2026, 10, 1, 12)),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const MyPassesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My passes'), findsOneWidget);
    expect(find.text('Day Pass'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('Expires'), findsOneWidget);
  });
}
