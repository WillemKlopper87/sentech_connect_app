import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sentech_connect_app/core/utils/reverse_geocode.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';

enum LocationFetchStatus { idle, fetching, fetched, denied, failed }

enum SubmitStatus { idle, submitting, submitted, failed }

class RegistrationState extends Equatable {
  const RegistrationState({
    this.fullName = '',
    this.email = '',
    this.mobileNumber = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.marketingEmail = false,
    this.marketingSms = false,
    this.marketingPush = false,
    this.preferredContactMethod = ContactMethod.email,
    this.locationStatus = LocationFetchStatus.idle,
    this.submitStatus = SubmitStatus.idle,
  });

  final String fullName;
  final String email;
  final String mobileNumber;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool marketingEmail;
  final bool marketingSms;
  final bool marketingPush;
  final ContactMethod preferredContactMethod;
  final LocationFetchStatus locationStatus;
  final SubmitStatus submitStatus;

  bool get hasLocation => latitude != null && longitude != null;

  RegistrationDetails toDetails() => RegistrationDetails(
        fullName: fullName,
        email: email,
        mobileNumber: mobileNumber,
        address: address,
        latitude: latitude,
        longitude: longitude,
        marketingEmail: marketingEmail,
        marketingSms: marketingSms,
        marketingPush: marketingPush,
        preferredContactMethod: preferredContactMethod,
      );

  RegistrationState copyWith({
    String? fullName,
    String? email,
    String? mobileNumber,
    String? address,
    double? latitude,
    double? longitude,
    bool? marketingEmail,
    bool? marketingSms,
    bool? marketingPush,
    ContactMethod? preferredContactMethod,
    LocationFetchStatus? locationStatus,
    SubmitStatus? submitStatus,
  }) {
    return RegistrationState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      marketingEmail: marketingEmail ?? this.marketingEmail,
      marketingSms: marketingSms ?? this.marketingSms,
      marketingPush: marketingPush ?? this.marketingPush,
      preferredContactMethod: preferredContactMethod ?? this.preferredContactMethod,
      locationStatus: locationStatus ?? this.locationStatus,
      submitStatus: submitStatus ?? this.submitStatus,
    );
  }

  @override
  List<Object?> get props => [
        fullName,
        email,
        mobileNumber,
        address,
        latitude,
        longitude,
        marketingEmail,
        marketingSms,
        marketingPush,
        preferredContactMethod,
        locationStatus,
        submitStatus,
      ];
}

class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit(this._repository) : super(const RegistrationState());

  final RegistrationRepository _repository;

  void setFullName(String v) => emit(state.copyWith(fullName: v));
  void setEmail(String v) => emit(state.copyWith(email: v));
  void setMobileNumber(String v) => emit(state.copyWith(mobileNumber: v));
  void setAddress(String v) => emit(state.copyWith(address: v));
  void setMarketingEmail(bool v) => emit(state.copyWith(marketingEmail: v));
  void setMarketingSms(bool v) => emit(state.copyWith(marketingSms: v));
  void setMarketingPush(bool v) => emit(state.copyWith(marketingPush: v));
  void setPreferredContactMethod(ContactMethod v) => emit(state.copyWith(preferredContactMethod: v));

  /// Narrows the address down using the device's actual GPS location,
  /// per the request for registration to be able to use real device
  /// location rather than typed address alone.
  Future<void> useDeviceLocation() async {
    emit(state.copyWith(locationStatus: LocationFetchStatus.fetching));
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(state.copyWith(locationStatus: LocationFetchStatus.failed));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        emit(state.copyWith(locationStatus: LocationFetchStatus.denied));
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final address = await reverseGeocode(position.latitude, position.longitude);
      emit(state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address ?? state.address,
        locationStatus: LocationFetchStatus.fetched,
      ));
    } catch (_) {
      emit(state.copyWith(locationStatus: LocationFetchStatus.failed));
    }
  }

  Future<void> submit() async {
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final result = await _repository.save(state.toDetails());
    result.match(
      (_) => emit(state.copyWith(submitStatus: SubmitStatus.failed)),
      (_) => emit(state.copyWith(submitStatus: SubmitStatus.submitted)),
    );
  }
}
