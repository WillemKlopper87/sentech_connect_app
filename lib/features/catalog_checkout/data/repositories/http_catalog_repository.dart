import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';

/// The tenant's active hotspot passes (`GET /v1/products?tenant=`), public.
class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._api, this._tenant);

  static const pageSize = 50;
  static const maxPages = 10;

  final ApiClient _api;
  final TenantContext _tenant;

  @override
  Future<Either<Failure, List<Plan>>> getProducts() async {
    final scope = await _api.captureScope();
    final plans = <Plan>[];
    String? cursor;
    final seen = <String>{};
    final tenant = _tenant.slug;
    for (var page = 0; page < maxPages; page++) {
      final result = await _api.get<(List<Plan>, String?)>(
        '/v1/products',
        scope: scope,
        authenticated: false,
        timeout: const Duration(seconds: 15),
        query: {'tenant': tenant, 'limit': pageSize, 'cursor': ?cursor},
        decode: _decodePage,
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: (final items, final next)):
          plans.addAll(items);
          cursor = next;
      }
      if (cursor == null) return Right(plans);
      if (!seen.add(cursor)) {
        return const Left(
          ServerFailure(
            'We could not load the complete catalogue. Please try again.',
          ),
        );
      }
    }
    return const Left(
      ServerFailure(
        'We could not load the complete catalogue. Please try again.',
      ),
    );
  }

  static (List<Plan>, String?) _decodePage(Object? data) {
    final map = data! as Map;
    final items = map['items']! as List;
    return (
      [
        for (final item in items)
          planFromProductJson(Map<String, Object?>.from(item as Map)),
      ],
      map['next_cursor'] as String?,
    );
  }
}

/// M1 `ProductOut` -> [Plan]. Rejects anything but ZAR.
Plan planFromProductJson(Map<String, Object?> json) {
  final price = json['price']! as Map;
  if (price['currency'] != 'ZAR') {
    throw FormatException('Unsupported currency ${price['currency']}');
  }
  final speedKbps = json['speed_kbps'] as int?;
  return Plan(
    id: json['id']! as String,
    name: json['name']! as String,
    priceCents: price['amount_cents']! as int,
    dataDescription: describePass(
      durationMinutes: json['duration_minutes']! as int,
      dataMb: json['data_mb'] as int?,
    ),
    speedMbps: speedKbps == null ? 0 : speedKbps ~/ 1000,
    category: ProductCategory.hotspotPass,
  );
}

/// "1 GB · 1 hour", "Unlimited data · 7 days".
String describePass({required int durationMinutes, int? dataMb}) {
  final String data;
  if (dataMb == null) {
    data = 'Unlimited data';
  } else if (dataMb % 1024 == 0) {
    data = '${dataMb ~/ 1024} GB';
  } else if (dataMb >= 1024) {
    data = '${(dataMb / 1024).toStringAsFixed(1)} GB';
  } else {
    data = '$dataMb MB';
  }
  final String duration;
  if (durationMinutes % 1440 == 0) {
    final days = durationMinutes ~/ 1440;
    duration = days == 1 ? '1 day' : '$days days';
  } else if (durationMinutes % 60 == 0) {
    final hours = durationMinutes ~/ 60;
    duration = hours == 1 ? '1 hour' : '$hours hours';
  } else {
    duration = '$durationMinutes min';
  }
  return '$data · $duration';
}
