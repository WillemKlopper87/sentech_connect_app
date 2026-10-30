import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_profile_edit.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_profile_repository.dart';

/// `ProfileOut` -> [LoginContact].
LoginContact loginContactFromJson(Map<String, Object?> json) => LoginContact(
  phoneE164: json['phone_e164']! as String,
  displayName: json['display_name'] as String?,
  email: json['email'] as String?,
);

/// `PATCH /v1/me/subscriber` (account contact details) and
/// `GET|PATCH /v1/me/profile` (sign-in profile). All calls need a session.
class HttpSubscriberProfileRepository implements SubscriberProfileRepository {
  HttpSubscriberProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<Either<Failure, SubscriberAccount>> patchProfile(SubscriberProfilePatch patch, {required String idempotencyKey}) async =>
      _api.patch<SubscriberAccount>(
        '/v1/me/subscriber',
        scope: await _api.captureScope(),
        idempotencyKey: idempotencyKey,
        body: patch.toBody(),
        decode: (data) => subscriberAccountFromJson(Map<String, Object?>.from(data! as Map)),
      );

  @override
  Future<Either<Failure, LoginContact>> getLoginContact() async => _api.get<LoginContact>(
    '/v1/me/profile',
    scope: await _api.captureScope(),
    decode: (data) => loginContactFromJson(Map<String, Object?>.from(data! as Map)),
  );

  @override
  Future<Either<Failure, LoginContact>> patchLoginContact({String? displayName, String? email, bool clearEmail = false}) async =>
      _api.patch<LoginContact>(
        '/v1/me/profile',
        scope: await _api.captureScope(),
        body: {'display_name': ?displayName, if (clearEmail) 'email': null else 'email': ?email},
        decode: (data) => loginContactFromJson(Map<String, Object?>.from(data! as Map)),
      );
}
