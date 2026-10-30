import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

/// The signed-in customer's subscriber account and services
/// (`/v1/me/subscriber*`). All calls need a session.
class HttpSubscriberRepository implements SubscriberRepository {
  HttpSubscriberRepository(this._api);

  /// An account has few services; 5 pages of 50 is far more than it can hold.
  static const pageSize = 50;
  static const maxPages = 5;

  final ApiClient _api;

  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async {
    final result = await _api.get<SubscriberAccount>(
      '/v1/me/subscriber',
      scope: await _api.captureScope(),
      decode: (data) => subscriberAccountFromJson(Map<String, Object?>.from(data! as Map)),
    );
    return result.match(
      (failure) => failure is SubscriberNotFoundFailure ? const Right(null) : Left(failure),
      Right.new,
    );
  }

  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async {
    final result = await fetchAllPages<SubscriberService>(
      _api,
      path: '/v1/me/subscriber/services',
      cursorParam: 'after',
      item: subscriberServiceFromJson,
      scope: await _api.captureScope(),
      authenticated: true,
      pageSize: pageSize,
      maxPages: maxPages,
    );
    return result.match(
      (failure) => failure is SubscriberNotFoundFailure ? const Right([]) : Left(failure),
      Right.new,
    );
  }

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async => _api.get<SubscriberService>(
    '/v1/me/subscriber/services/${Uri.encodeComponent(id)}',
    scope: await _api.captureScope(),
    decode: (data) => subscriberServiceFromJson(Map<String, Object?>.from(data! as Map)),
  );
}
