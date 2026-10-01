import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sentech_connect_app/core/utils/reverse_geocode.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

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
    this.acceptedTerms = false,
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

  /// Terms of Service + Privacy notice accepted (required).
  final bool acceptedTerms;

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
    bool? acceptedTerms,
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
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
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
        acceptedTerms,
      ];
}

class RegistrationCubit extends Cubit<RegistrationState> {
  RegistrationCubit(this._repository, {this._consents, String initialMobile = ''})
      : super(RegistrationState(mobileNumber: initialMobile));

  final RegistrationRepository _repository;
  final ConsentRepository? _consents;

  void setAcceptedTerms(bool v) => emit(state.copyWith(acceptedTerms: v));

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

  /// Records the legal consents FIRST, then saves the profile: a profile
  /// (a named customer) must never exist without the terms having been
  /// recorded, or a later biometric unlock / cold start would skip them.
  /// A retry is safe: consents already in the ledger are not written again.
  /// Nothing is submitted without the terms being accepted.
  Future<void> submit() async {
    if (!state.acceptedTerms || state.submitStatus == SubmitStatus.submitting) return;
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final consents = _consents;
    if (consents != null) {
      for (final purpose in [
        ConsentPurpose.terms,
        ConsentPurpose.privacy,
        if (state.marketingSms) ConsentPurpose.marketingSms,
      ]) {
        final granted = await consents.grant(purpose);
        if (isClosed) return;
        if (granted.isLeft()) {
          emit(state.copyWith(submitStatus: SubmitStatus.failed));
          return;
        }
      }
    }
    final saved = await _repository.save(state.toDetails());
    if (isClosed) return;
    emit(state.copyWith(submitStatus: saved.isLeft() ? SubmitStatus.failed : SubmitStatus.submitted));
  }
}
