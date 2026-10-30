import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/repositories/hotspot_login_repository.dart';

/// `POST /v1/me/hotspot/login-token` with an empty body: no `mac` (the app
/// cannot supply one), no `nas_id`, no `login_url`. The route takes no
/// Idempotency-Key (a retry just issues another short-lived login), so none is
/// sent. The response is `Cache-Control: no-store` and is never stored here.
class HttpHotspotLoginRepository implements HotspotLoginRepository {
  HttpHotspotLoginRepository(this._api);

  final ApiClient _api;

  /// The request body, exposed for the contract test.
  static const requestBody = <String, Object?>{};

  @override
  Future<Either<Failure, LoginToken>> createLoginToken() async =>
      _api.post<LoginToken>(
        '/v1/me/hotspot/login-token',
        scope: await _api.captureScope(),
        body: requestBody,
        decode: (data) =>
            loginTokenFromJson(Map<String, Object?>.from(data! as Map)),
      );
}

/// `LoginTokenOut` -> [LoginToken]; `handoff` is ignored on purpose.
LoginToken loginTokenFromJson(Map<String, Object?> json) => LoginToken(
  username: json['username']! as String,
  password: json['password']! as String,
  expiresAt: DateTime.parse(json['expires_at']! as String).toUtc(),
);
