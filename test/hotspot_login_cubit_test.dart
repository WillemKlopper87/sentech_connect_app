import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/repositories/hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/bloc/hotspot_login_cubit.dart';

class FakeLoginRepo implements HotspotLoginRepository {
  FakeLoginRepo(this.clock, this.results);

  final DateTime Function() clock;
  final List<Either<Failure, LoginToken>> results;
  var calls = 0;

  /// Issues a login valid for 300 s from "now" when the queued result is null.
  static LoginToken fresh(DateTime now, int n) =>
      LoginToken(username: 'c.$n', password: 'pw$n', expiresAt: now.add(const Duration(seconds: 300)));

  @override
  Future<Either<Failure, LoginToken>> createLoginToken() async {
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    return r;
  }
}

void main() {
  var now = DateTime.utc(2026, 10, 30, 12);
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 10, 30, 12));

  HotspotLoginCubit make(List<Either<Failure, LoginToken>> results) =>
      HotspotLoginCubit(FakeLoginRepo(clock, results), now: clock, autoTick: false);

  test('starts idle and holds no login', () {
    final cubit = make([]);
    expect(cubit.state.status, HotspotLoginStatus.idle);
    expect(cubit.state.token, isNull);
  });

  test('request shows the login and the time left; ticks count down; expiry drops the password', () async {
    final cubit = make([Right(FakeLoginRepo.fresh(now, 1))]);
    await cubit.request();
    expect(cubit.state.status, HotspotLoginStatus.ready);
    expect(cubit.state.token?.username, 'c.1');
    expect(cubit.state.remaining, const Duration(seconds: 300));

    now = now.add(const Duration(seconds: 100));
    cubit.tick();
    expect(cubit.state.remaining, const Duration(seconds: 200));

    now = now.add(const Duration(seconds: 199));
    cubit.tick();
    expect(cubit.state.status, HotspotLoginStatus.ready);
    expect(cubit.state.remaining, const Duration(seconds: 1));

    now = now.add(const Duration(seconds: 1));
    cubit.tick();
    expect(cubit.state.status, HotspotLoginStatus.expired);
    expect(cubit.state.token, isNull);
    await cubit.close();
  });

  test('regenerate after expiry issues a new login and restarts the countdown', () async {
    final first = FakeLoginRepo.fresh(now, 1);
    final cubit = make([Right(first)]);
    await cubit.request();
    now = now.add(const Duration(seconds: 301));
    cubit.tick();
    expect(cubit.state.status, HotspotLoginStatus.expired);

    final repo = FakeLoginRepo(clock, [Right(FakeLoginRepo.fresh(now, 2))]);
    final again = HotspotLoginCubit(repo, now: clock, autoTick: false);
    await again.request();
    expect(again.state.token?.username, 'c.2');
    expect(again.state.remaining, const Duration(seconds: 300));
    await again.request();
    expect(repo.calls, 2);
    await cubit.close();
    await again.close();
  });

  test('regenerate while a login is showing replaces it', () async {
    final cubit = make([Right(FakeLoginRepo.fresh(now, 1)), Right(FakeLoginRepo.fresh(now, 2))]);
    await cubit.request();
    await cubit.request();
    expect(cubit.state.token?.username, 'c.2');
    await cubit.close();
  });

  test('a failure holds no login and can be retried', () async {
    final cubit = make([const Left(NoActiveEntitlementFailure()), Right(FakeLoginRepo.fresh(now, 1))]);
    await cubit.request();
    expect(cubit.state.status, HotspotLoginStatus.failure);
    expect(cubit.state.failure, isA<NoActiveEntitlementFailure>());
    expect(cubit.state.token, isNull);
    await cubit.request();
    expect(cubit.state.status, HotspotLoginStatus.ready);
    await cubit.close();
  });

  test('rate limit and offline surface as their own failures', () async {
    for (final failure in <Failure>[const RateLimitedFailure(), const NetworkFailure(), const ControllerNotSupportedFailure()]) {
      final cubit = make([Left(failure)]);
      await cubit.request();
      expect(cubit.state.failure, failure);
      await cubit.close();
    }
  });

  test('a login already past its end (clock skew) is shown as expired, never as ready', () async {
    final cubit = make([Right(LoginToken(username: 'c', password: 'p', expiresAt: now.subtract(const Duration(seconds: 1))))]);
    await cubit.request();
    expect(cubit.state.status, HotspotLoginStatus.expired);
    expect(cubit.state.token, isNull);
    await cubit.close();
  });

  test('the automatic ticker is cancelled on close', () async {
    final cubit = HotspotLoginCubit(FakeLoginRepo(clock, [Right(FakeLoginRepo.fresh(now, 1))]), now: clock);
    await cubit.request();
    await cubit.close();
    expect(cubit.isClosed, isTrue);
  });
}
