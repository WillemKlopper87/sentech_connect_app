import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/coverage/domain/device_location.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geo_point.dart';

enum LocationStatus { idle, locating, located, serviceOff, denied, deniedForever, failed }

class LocationState extends Equatable {
  const LocationState({this.status = LocationStatus.idle, this.point});

  final LocationStatus status;

  /// The position read, in memory only and printed redacted; the page hands it to the check and calls [LocationCubit.reset].
  final GeoPoint? point;

  @override
  List<Object?> get props => [status, point];
}

/// "Use my location": one read behind the OS permission prompt, with a state
/// for every way it can fail. A failure never blocks address search or the map.
class LocationCubit extends Cubit<LocationState> {
  LocationCubit(this._service) : super(const LocationState());

  final DeviceLocationService _service;

  Future<void> locate() async {
    if (isClosed || state.status == LocationStatus.locating) return;
    emit(const LocationState(status: LocationStatus.locating));
    final result = await _service.current();
    if (isClosed) return;
    emit(switch (result) {
      LocationFound(:final lat, :final lon) => LocationState(status: LocationStatus.located, point: GeoPoint(lat, lon)),
      LocationServiceOff() => const LocationState(status: LocationStatus.serviceOff),
      LocationDenied() => const LocationState(status: LocationStatus.denied),
      LocationDeniedForever() => const LocationState(status: LocationStatus.deniedForever),
      LocationFailed() => const LocationState(status: LocationStatus.failed),
    });
  }

  void reset() {
    if (!isClosed) emit(const LocationState());
  }
}
