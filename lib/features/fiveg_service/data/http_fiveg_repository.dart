import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/fiveg_service/data/fiveg_json.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';

/// The customer's 5G data routes. Any 404 on them means the feature is not
/// available for this service (switched off, or not eligible), so it maps to
/// [FiveGNotAvailableFailure] and the screens hide the feature.
class HttpFiveGRepository implements FiveGRepository {
  HttpFiveGRepository(this._api);

  final ApiClient _api;

  static String _dataPath(String serviceId) => '/v1/me/subscriber/services/${Uri.encodeComponent(serviceId)}/data';

  static Failure _notAvailable(Failure failure) => failure is NotFoundFailure ? const FiveGNotAvailableFailure() : failure;

  @override
  Future<Either<Failure, FiveGUsage>> getUsage(String serviceId) async {
    final result = await _api.get<FiveGUsage>(
      _dataPath(serviceId),
      scope: await _api.captureScope(),
      decode: (data) => fiveGUsageFromJson(Map<String, Object?>.from(data! as Map)),
    );
    return result.mapLeft(_notAvailable);
  }

  @override
  Future<Either<Failure, Order>> createUnlockOrder(
    String serviceId, {
    required String productCode,
    required String idempotencyKey,
  }) async {
    final result = await _api.post<Order>(
      '${_dataPath(serviceId)}/unlock-orders',
      scope: await _api.captureScope(),
      idempotencyKey: idempotencyKey,
      body: {'product_code': productCode},
      decode: (data) => orderFromJson(Map<String, Object?>.from(data! as Map)),
    );
    return result.mapLeft(_notAvailable);
  }
}
