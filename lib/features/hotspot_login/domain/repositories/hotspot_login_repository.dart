import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';

abstract class HotspotLoginRepository {
  /// Asks the platform for a short-lived, single-use Wi-Fi login
  /// (`POST /v1/me/hotspot/login-token`). The app cannot read its own MAC
  /// address, so none is sent: the platform binds the login to the first
  /// device that signs in with it. Every call issues a new login.
  Future<Either<Failure, LoginToken>> createLoginToken();
}
