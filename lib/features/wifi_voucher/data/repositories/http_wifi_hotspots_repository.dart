import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

/// The tenant's publicly listed hotspot sites (`GET /v1/hotspots?tenant=`).
/// Public: no session is needed, so the map works before sign-in.
class HttpWifiHotspotsRepository implements WifiHotspotsRepository {
  HttpWifiHotspotsRepository(this._api, this._tenant);

  static const pageSize = 100;
  static const maxPages = 10;

  static const _incomplete = ServerFailure(
    'We could not load all hotspots. Please try again.',
  );

  final ApiClient _api;
  final TenantContext _tenant;

  @override
  Future<Either<Failure, List<WifiHotspot>>> getHotspots() async {
    final scope = await _api.captureScope();
    final hotspots = <WifiHotspot>[];
    final seen = <String>{};
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await _api.get<(List<WifiHotspot>, String?)>(
        '/v1/hotspots',
        scope: scope,
        authenticated: false,
        timeout: const Duration(seconds: 15),
        query: {'tenant': _tenant.slug, 'limit': pageSize, 'cursor': ?cursor},
        decode: _decodePage,
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: (final items, final next)):
          hotspots.addAll(items);
          cursor = next;
      }
      if (cursor == null) return Right(hotspots);
      if (!seen.add(cursor)) return const Left(_incomplete);
    }
    return const Left(_incomplete);
  }

  static (List<WifiHotspot>, String?) _decodePage(Object? data) {
    final map = data! as Map;
    return (
      [
        for (final item in map['items']! as List)
          hotspotFromJson(Map<String, Object?>.from(item as Map)),
      ],
      map['next_cursor'] as String?,
    );
  }
}

/// `HotspotPublicOut` -> [WifiHotspot]. An unknown status fails loudly rather
/// than showing a site as working when it may not be.
WifiHotspot hotspotFromJson(Map<String, Object?> json) {
  final status = switch (json['status']) {
    'live' => HotspotStatus.live,
    'maintenance' => HotspotStatus.maintenance,
    final other => throw FormatException('Unknown hotspot status $other'),
  };
  final address = (json['address_text'] as String?)?.trim();
  return WifiHotspot(
    id: json['id']! as String,
    name: json['name']! as String,
    latitude: (json['lat']! as num).toDouble(),
    longitude: (json['lon']! as num).toDouble(),
    status: status,
    address: address == null || address.isEmpty ? null : address,
  );
}
