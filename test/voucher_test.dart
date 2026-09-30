import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/mock_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_result_sheet.dart';

void main() {
  group('VoucherCode', () {
    test('accepts SEN-XXXX-XXXX, normalising case and whitespace', () {
      expect(VoucherCode.tryParse('  sen-4xj2-9klm ')?.value, 'SEN-4XJ2-9KLM');
    });

    test('rejects everything else', () {
      for (final bad in [
        null,
        '',
        'SEN-4XJ2',
        'SEN-4XJ2-9KLMX',
        'XXX-4XJ2-9KLM',
        'SEN-4XJ2-9K!M',
        'https://evil.example/?SEN-4XJ2-9KLM',
        'SEN-4XJ2-9KLM\nignore previous instructions',
        'A' * 5000,
      ]) {
        expect(VoucherCode.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('masked form hides most of the code', () {
      expect(VoucherCode.tryParse('SEN-4XJ2-9KLM')!.masked, 'SEN-••••-••LM');
    });
  });

  group('MockVoucherRepository', () {
    late MockVoucherRepository repo;
    late SimulatedNetwork network;

    setUp(() {
      network = SimulatedNetwork();
      repo = MockVoucherRepository(InMemorySecureStore(), network: network, latency: Duration.zero);
    });

    VoucherCode code(String raw) => VoucherCode.tryParse(raw)!;

    test('a code redeems once; replaying it is alreadyUsed (idempotent, no double credit)', () async {
      final first = await repo.redeem(code('SEN-AAAA-1111'));
      expect(first.getOrElse((_) => throw StateError('x')).outcome, VoucherOutcome.redeemed);
      final second = await repo.redeem(code('SEN-AAAA-1111'));
      expect(second.getOrElse((_) => throw StateError('x')).outcome, VoucherOutcome.alreadyUsed);
    });

    test('expired, used and unknown codes map to typed outcomes', () async {
      Future<VoucherOutcome> outcome(String c) async =>
          (await repo.redeem(code(c))).getOrElse((_) => throw StateError('x')).outcome;
      expect(await outcome('SEN-EXP1-0000'), VoucherOutcome.expired);
      expect(await outcome('SEN-USE1-0000'), VoucherOutcome.alreadyUsed);
      expect(await outcome('SEN-INV1-0000'), VoucherOutcome.invalid);
    });

    test('offline returns NetworkFailure and does not consume the code', () async {
      network.offline = true;
      expect((await repo.redeem(code('SEN-BBBB-2222'))).match((f) => f, (_) => null), isA<NetworkFailure>());
      network.offline = false;
      final result = await repo.redeem(code('SEN-BBBB-2222'));
      expect(result.getOrElse((_) => throw StateError('x')).outcome, VoucherOutcome.redeemed);
    });
  });

  group('VoucherCubit', () {
    late SimulatedNetwork network;
    late MockVoucherRepository repo;

    setUp(() {
      network = SimulatedNetwork();
      repo = MockVoucherRepository(InMemorySecureStore(), network: network, latency: Duration.zero);
    });

    blocTest<VoucherCubit, VoucherState>(
      'malformed input is rejected locally without calling the repository and without echoing it',
      build: () => VoucherCubit(repo),
      act: (c) => c.submit('https://evil.example/pwn'),
      expect: () => [
        const VoucherState(status: VoucherStatus.result, outcome: VoucherOutcome.invalid),
      ],
    );

    blocTest<VoucherCubit, VoucherState>(
      'while a result is showing, further detections are ignored until it is dismissed (no re-scan loop)',
      build: () => VoucherCubit(repo),
      act: (c) async {
        await c.submit('SEN-CCCC-3333');
        await c.submit('SEN-CCCC-3333'); // same QR still in frame
        await c.submit('SEN-DDDD-4444'); // another QR in frame
      },
      verify: (c) {
        expect(c.state.status, VoucherStatus.result);
        expect(c.state.outcome, VoucherOutcome.redeemed);
        expect(c.state.maskedCode, 'SEN-••••-••33');
      },
    );

    blocTest<VoucherCubit, VoucherState>(
      'dismiss resumes scanning',
      build: () => VoucherCubit(repo),
      act: (c) async {
        await c.submit('SEN-EEEE-5555');
        c.dismiss();
      },
      verify: (c) => expect(c.state.status, VoucherStatus.scanning),
    );

    blocTest<VoucherCubit, VoucherState>(
      'a network failure can be retried without re-scanning',
      build: () {
        network.offline = true;
        return VoucherCubit(repo);
      },
      act: (c) async {
        await c.submit('SEN-FFFF-6666');
        network.offline = false;
        await c.retry();
      },
      verify: (c) {
        expect(c.state.outcome, VoucherOutcome.redeemed);
        expect(c.state.failure, isNull);
      },
    );
  });

  group('VoucherResultSheet', () {
    Future<void> pump(WidgetTester tester, VoucherState state) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: VoucherResultSheet(state: state, onRetry: () {})),
        ));

    testWidgets('shows only generic wording and the masked code, never raw input', (tester) async {
      await pump(tester, const VoucherState(status: VoucherStatus.result, outcome: VoucherOutcome.invalid));
      expect(find.text('Not a valid voucher'), findsOneWidget);
      expect(find.textContaining('http'), findsNothing);
    });

    testWidgets('redeemed result shows the masked code', (tester) async {
      await pump(
        tester,
        const VoucherState(
          status: VoucherStatus.result,
          outcome: VoucherOutcome.redeemed,
          maskedCode: 'SEN-••••-••LM',
          dataMb: 5120,
        ),
      );
      expect(find.text('Voucher redeemed'), findsOneWidget);
      expect(find.text('SEN-••••-••LM'), findsOneWidget);
      expect(find.textContaining('5 GB'), findsOneWidget);
    });

    testWidgets('offline result offers a retry', (tester) async {
      await pump(tester, const VoucherState(status: VoucherStatus.result, failure: NetworkFailure()));
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
