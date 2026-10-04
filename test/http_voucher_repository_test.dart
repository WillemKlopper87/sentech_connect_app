import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/voucher_scanner/data/repositories/http_voucher_repository.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/bloc/voucher_cubit.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _path = '/v1/me/vouchers/redeem';

void main() {
  late ApiHarness h;
  late HttpVoucherRepository repo;
  final code = VoucherCode.tryParse('sen abcd-2345-efgq')!;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpVoucherRepository(h.api);
  });

  test(
    'posts the normalised payload with an idempotency key and maps RedeemOut',
    () async {
      h.adapter.on(
        'POST',
        _path,
        (_) => FakeReply(200, fixture('voucher_redeem_ok.json')),
      );

      final result = (await repo.redeem(
        code,
      )).getOrElse((f) => throw StateError(f.message));

      final sent = h.adapter.requests.single;
      expect(sent.data, {'code': 'ABCD2345EFGQ'});
      expect(sent.headers['Idempotency-Key'], isA<String>());
      expect(sent.headers['Authorization'], 'Bearer access-1');
      expect(result.outcome, VoucherOutcome.redeemed);
      expect(result.productName, 'Day Pass');
      expect(result.dataMb, 5120);
      expect(result.pass?.source, PassSource.voucher);
      expect(result.pass?.status, PassStatus.active);
    },
  );

  test(
    'the uniform 422 voucher_invalid (and any other 4xx refusal) is the invalid outcome',
    () async {
      for (final reply in [
        FakeReply.problem(
          422,
          'voucher_invalid',
          detail: 'This voucher code is not valid or not active yet.',
        ),
        FakeReply.problem(400, 'bad_request'),
        FakeReply.problem(409, 'conflict'),
        FakeReply.problem(404, 'not_found'),
      ]) {
        h.adapter.on('POST', _path, (_) => reply);
        final result = (await repo.redeem(
          code,
        )).getOrElse((f) => throw StateError(f.message));
        expect(
          result.outcome,
          VoucherOutcome.invalid,
          reason: '${reply.status}',
        );
      }
    },
  );

  test('429 stays a RateLimitedFailure with the server wait', () async {
    h.adapter.on(
      'POST',
      _path,
      (_) => FakeReply.problem(
        429,
        'rate_limited',
        headers: {
          'retry-after': ['120'],
        },
      ),
    );
    final failure = (await repo.redeem(code)).match((f) => f, (_) => null);
    expect(failure, isA<RateLimitedFailure>());
    expect(
      (failure! as RateLimitedFailure).retryAfter,
      const Duration(minutes: 2),
    );
  });

  test(
    'offline is a NetworkFailure; the retry reuses the idempotency key',
    () async {
      h.adapter.on(
        'POST',
        _path,
        (_) => const FakeReply.error(DioExceptionType.connectionError),
      );
      expect(
        (await repo.redeem(code)).match((f) => f, (_) => null),
        isA<NetworkFailure>(),
      );
      h.adapter.on(
        'POST',
        _path,
        (_) => FakeReply(200, fixture('voucher_redeem_ok.json')),
      );
      await repo.redeem(code);
      final keys = h.adapter.requests
          .map((r) => r.headers['Idempotency-Key'])
          .toSet();
      expect(keys, hasLength(1));
    },
  );

  test('a different code gets a fresh idempotency key', () async {
    h.adapter.on(
      'POST',
      _path,
      (_) => FakeReply(200, fixture('voucher_redeem_ok.json')),
    );
    await repo.redeem(code);
    await repo.redeem(VoucherCode.tryParse('23456789ABC7')!);
    final keys = h.adapter.requests
        .map((r) => r.headers['Idempotency-Key'])
        .toSet();
    expect(keys, hasLength(2));
  });

  test('503 is a ServerFailure, not an invalid voucher', () async {
    h.adapter.on('POST', _path, (_) => FakeReply.problem(503, 'unavailable'));
    expect(
      (await repo.redeem(code)).match((f) => f, (_) => null),
      isA<ServerFailure>(),
    );
  });

  group('the plaintext code does not linger in memory', () {
    for (final close in [false, true]) {
      test(
        'uncertain attempt clears on ${close ? 'cubit close' : 'terminal dismiss'}',
        () async {
          h.adapter.on(
            'POST',
            _path,
            (_) => const FakeReply.error(DioExceptionType.connectionError),
          );
          final cubit = VoucherCubit(repo);
          await cubit.submit(code.value);
          expect(repo.heldCodeForTest, code.value);
          final key = h.adapter.requests.single.headers['Idempotency-Key'];
          if (close) {
            await cubit.close();
          } else {
            cubit.dismiss();
            await cubit.close();
          }
          expect(repo.heldCodeForTest, isNull);
          await repo.redeem(code);
          expect(
            h.adapter.requests.last.headers['Idempotency-Key'],
            isNot(key),
          );
          repo.endRedemptionFlow();
        },
      );
    }

    test(
      'active retry retains its key and propagates the actual pass',
      () async {
        h.adapter.on(
          'POST',
          _path,
          (_) => const FakeReply.error(DioExceptionType.receiveTimeout),
        );
        final cubit = VoucherCubit(repo);
        await cubit.submit(code.value);
        final key = h.adapter.requests.single.headers['Idempotency-Key'];
        expect(repo.heldCodeForTest, code.value);
        h.adapter.on(
          'POST',
          _path,
          (_) => FakeReply(200, fixture('voucher_redeem_ok.json')),
        );
        await cubit.retry();
        expect(h.adapter.requests.last.headers['Idempotency-Key'], key);
        expect(cubit.state.pass?.productName, 'Day Pass');
        expect(cubit.state.pass?.durationMinutes, 1440);
        expect(repo.heldCodeForTest, isNull);
        await cubit.close();
      },
    );

    for (final network in [true, false]) {
      test(
        'late ${network ? 'network error' : 'success'} cannot revive a closed flow',
        () async {
          final reply = Completer<FakeReply>();
          h.adapter.on('POST', _path, (_) => reply.future);
          final cubit = VoucherCubit(repo);
          final pending = cubit.submit(code.value);
          // Wait until the adapter has received the request, without delays.
          while (h.adapter.requests.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          await cubit.close();
          expect(repo.heldCodeForTest, isNull);
          reply.complete(
            network
                ? const FakeReply.error(DioExceptionType.connectionError)
                : FakeReply(200, fixture('voucher_redeem_ok.json')),
          );
          await pending;
          expect(repo.heldCodeForTest, isNull);
          expect(cubit.state.status, VoucherStatus.redeeming);
        },
      );
    }

    for (final (name, reply) in [
      ('success', FakeReply(200, fixture('voucher_redeem_ok.json'))),
      ('refused', FakeReply.problem(422, 'voucher_invalid')),
      ('rate limited', FakeReply.problem(429, 'rate_limited')),
      ('server error', FakeReply.problem(503, 'unavailable')),
    ]) {
      test('cleared after $name', () async {
        h.adapter.on('POST', _path, (_) => reply);
        await repo.redeem(code);
        expect(repo.heldCodeForTest, isNull);
      });
    }

    test(
      'kept only across a network failure, so the retry reuses its key',
      () async {
        h.adapter.on(
          'POST',
          _path,
          (_) => const FakeReply.error(DioExceptionType.connectionError),
        );
        await repo.redeem(code);
        expect(repo.heldCodeForTest, isNotNull);
        h.adapter.on(
          'POST',
          _path,
          (_) => FakeReply(200, fixture('voucher_redeem_ok.json')),
        );
        await repo.redeem(code);
        expect(repo.heldCodeForTest, isNull);
      },
    );

    test('the same code after a completed attempt gets a fresh key', () async {
      h.adapter.on(
        'POST',
        _path,
        (_) => FakeReply.problem(422, 'voucher_invalid'),
      );
      await repo.redeem(code);
      await repo.redeem(code);
      expect(
        h.adapter.requests.map((r) => r.headers['Idempotency-Key']).toSet(),
        hasLength(2),
      );
    });
  });
}
