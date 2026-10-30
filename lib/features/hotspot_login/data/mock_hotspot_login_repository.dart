import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/repositories/hotspot_login_repository.dart';

/// Demo stand-in: a fresh fake login valid for five minutes.
class MockHotspotLoginRepository implements HotspotLoginRepository {
  MockHotspotLoginRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  var _n = 0;

  @override
  Future<Either<Failure, LoginToken>> createLoginToken() async {
    _n++;
    return Right(
      LoginToken(
        username: 'c.demo${_n.toString().padLeft(4, '0')}',
        password: 'demo-pass-$_n',
        expiresAt: _now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
  }
}
