import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_banner.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum ServiceDetailStatus { loading, loaded, failure }

class ServiceDetailState extends Equatable {
  const ServiceDetailState({this.status = ServiceDetailStatus.loading, this.service, this.failure, this.kycStatus});

  final ServiceDetailStatus status;
  final SubscriberService? service;
  final Failure? failure;

  /// The ID check status, read only when the banner depends on it (see
  /// `serviceBannerUsesKyc`); null otherwise or when unreadable.
  final KycStatus? kycStatus;

  @override
  List<Object?> get props => [status, service, failure, kycStatus];
}

class ServiceDetailCubit extends Cubit<ServiceDetailState> {
  ServiceDetailCubit(this._repository, this.serviceId, {this._kyc}) : super(const ServiceDetailState()) {
    load();
  }

  final SubscriberRepository _repository;
  final String serviceId;
  final KycRepository? _kyc;

  /// For the actions (change plan, cancel) opened from the detail page.
  SubscriberRepository get repository => _repository;

  /// Shows [service] (a platform answer to an action) before the refresh lands.
  void applyService(SubscriberService service) {
    if (isClosed) return;
    emit(ServiceDetailState(status: ServiceDetailStatus.loaded, service: service, kycStatus: state.kycStatus));
  }

  Future<void> load({bool keepVisible = false}) async {
    if (!keepVisible || state.service == null) emit(const ServiceDetailState());
    final result = await _repository.getService(serviceId);
    if (isClosed) return;
    result.match((failure) {
      if (keepVisible && state.service != null) return;
      emit(ServiceDetailState(status: ServiceDetailStatus.failure, failure: failure));
    }, (service) => emit(ServiceDetailState(status: ServiceDetailStatus.loaded, service: service, kycStatus: state.kycStatus)));
    final loaded = state.service;
    if (loaded != null && state.status == ServiceDetailStatus.loaded) await _loadKyc(loaded);
  }

  /// Only reads the ID check when the banner depends on it; a failure keeps
  /// the generic banner.
  Future<void> _loadKyc(SubscriberService service) async {
    final repository = _kyc;
    if (repository == null) return;
    if (!serviceBannerUsesKyc(service)) {
      if (state.kycStatus != null) emit(ServiceDetailState(status: state.status, service: service));
      return;
    }
    final result = await repository.getStatus();
    if (isClosed) return;
    final status = result.match((_) => null, (record) => record?.status);
    emit(ServiceDetailState(status: ServiceDetailStatus.loaded, service: state.service ?? service, kycStatus: status));
  }
}
