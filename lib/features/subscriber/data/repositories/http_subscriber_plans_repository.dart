import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';

/// The tenant's active monthly plans (`GET /v1/subscriber-plans?tenant=`).
/// Public: no session, so plans can be browsed before sign-in. The API
/// defaults `tenant` to `sentech`, so the slug is always sent.
class HttpSubscriberPlansRepository implements SubscriberPlansRepository {
  HttpSubscriberPlansRepository(this._api, this._tenant);

  final ApiClient _api;
  final TenantContext _tenant;

  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async => fetchAllPages(
    _api,
    path: '/v1/subscriber-plans',
    cursorParam: 'cursor',
    item: subscriberPlanFromJson,
    scope: await _api.captureScope(),
    authenticated: false,
    query: {'tenant': _tenant.slug},
  );
}
