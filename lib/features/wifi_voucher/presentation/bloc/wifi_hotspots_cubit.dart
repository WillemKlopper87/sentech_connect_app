import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

enum WifiHotspotsStatus { loading, loaded, failure }

class HotspotDistance extends Equatable {
  const HotspotDistance({required this.hotspot, required this.distanceMeters});

  final WifiHotspot hotspot;
  final double? distanceMeters; // null if the device location isn't known

  String get distanceLabel {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return AppLocalizationsEn().hotspotMetersAway(
        distanceMeters!.round().toString(),
      );
    }
    return AppLocalizationsEn().hotspotKilometersAway(
      (distanceMeters! / 1000).toStringAsFixed(1),
    );
  }

  @override
  List<Object?> get props => [hotspot, distanceMeters];
}

class WifiHotspotsState extends Equatable {
  const WifiHotspotsState({
    this.status = WifiHotspotsStatus.loading,
    this.hotspots = const [],
    this.userLatitude,
    this.userLongitude,
    this.failure,
  });

  final WifiHotspotsStatus status;
  final List<HotspotDistance> hotspots;
  final double? userLatitude;
  final double? userLongitude;

  /// Set when [status] is [WifiHotspotsStatus.failure] (offline, server error).
  final Failure? failure;

  bool get hasUserLocation => userLatitude != null && userLongitude != null;

  @override
  List<Object?> get props => [
    status,
    hotspots,
    userLatitude,
    userLongitude,
    failure,
  ];
}

class WifiHotspotsCubit extends Cubit<WifiHotspotsState> {
  /// [locate] is the device-position lookup; tests pass a fake.
  WifiHotspotsCubit(this._repository, {Future<Position?> Function()? locate})
    : _locate = locate ?? _deviceLocation,
      super(const WifiHotspotsState()) {
    _load();
  }

  final WifiHotspotsRepository _repository;
  final Future<Position?> Function() _locate;

  static Future<Position?> _deviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final hasPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (serviceEnabled && hasPermission) {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
      }
    } catch (_) {
      // Fall through with sorting disabled — the list still renders.
    }
    return null;
  }

  /// Loads (or reloads, for the retry button) the hotspots.
  Future<void> load() async {
    if (state.status != WifiHotspotsStatus.loading) {
      emit(const WifiHotspotsState());
    }
    await _load();
  }

  Future<void> _load() async {
    final result = await _repository.getHotspots();
    if (isClosed) return;
    final failure = result.match((f) => f, (_) => null);
    if (failure != null) {
      emit(
        WifiHotspotsState(status: WifiHotspotsStatus.failure, failure: failure),
      );
      return;
    }
    final hotspots = result.getOrElse((_) => const []);

    final position = await _locate();

    final withDistance =
        hotspots.map((h) {
          final distance = position == null
              ? null
              : Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  h.latitude,
                  h.longitude,
                );
          return HotspotDistance(hotspot: h, distanceMeters: distance);
        }).toList()..sort((a, b) {
          if (a.distanceMeters == null || b.distanceMeters == null) return 0;
          return a.distanceMeters!.compareTo(b.distanceMeters!);
        });

    if (isClosed) return;
    emit(
      WifiHotspotsState(
        status: WifiHotspotsStatus.loaded,
        hotspots: withDistance,
        userLatitude: position?.latitude,
        userLongitude: position?.longitude,
      ),
    );
  }
}
