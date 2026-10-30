import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/invoice_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

/// `SubscriberSignupOut` -> [SubscriberSignup].
SubscriberSignup subscriberSignupFromJson(Map<String, Object?> json) => SubscriberSignup(
  service: subscriberServiceFromJson(Map<String, Object?>.from(json['service']! as Map)),
  invoice: subscriberInvoiceFromJson(Map<String, Object?>.from(json['invoice']! as Map)),
);

/// The `SubscriberSignupIn` body: `plan_id` and `accept_terms_version`
/// always; `install_address` only when given; `term_months` never (month to
/// month, plan doc Q8).
Map<String, Object?> subscriberSignupBody({
  required String planId,
  required String termsVersion,
  String? installAddress,
}) => {
  'plan_id': planId,
  'accept_terms_version': termsVersion,
  'install_address': ?installAddress,
};

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

  @override
  Future<Either<Failure, PlanChange>> changePlan(String serviceId, String newPlanId, {required String idempotencyKey}) async =>
      _api.post<PlanChange>(
        '/v1/me/subscriber/services/${Uri.encodeComponent(serviceId)}/change-plan',
        scope: await _api.captureScope(),
        idempotencyKey: idempotencyKey,
        body: {'new_plan_id': newPlanId},
        decode: (data) => planChangeFromJson(Map<String, Object?>.from(data! as Map)),
      );

  @override
  Future<Either<Failure, SubscriberService>> cancel(String serviceId, String reason, {required String idempotencyKey}) async =>
      _api.post<SubscriberService>(
        '/v1/me/subscriber/services/${Uri.encodeComponent(serviceId)}/cancel',
        scope: await _api.captureScope(),
        idempotencyKey: idempotencyKey,
        body: {'reason': reason},
        decode: (data) => subscriberServiceFromJson(Map<String, Object?>.from(data! as Map)),
      );
  /// The body carries `plan_id` and `accept_terms_version` always;
  /// `install_address` only when given; `term_months` never (month to month).
  /// No human check: the route has none.
  @override
  Future<Either<Failure, SubscriberSignup>> signup({
    required String planId,
    required String termsVersion,
    required String idempotencyKey,
    String? installAddress,
  }) async => _api.post<SubscriberSignup>(
    '/v1/me/subscriber/signup',
    scope: await _api.captureScope(),
    idempotencyKey: idempotencyKey,
    timeout: const Duration(seconds: 30),
    body: subscriberSignupBody(planId: planId, termsVersion: termsVersion, installAddress: installAddress),
    decode: (data) => subscriberSignupFromJson(Map<String, Object?>.from(data! as Map)),
  );
}
