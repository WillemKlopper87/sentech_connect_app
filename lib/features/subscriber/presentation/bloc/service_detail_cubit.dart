import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum ServiceDetailStatus { loading, loaded, failure }

class ServiceDetailState extends Equatable {
  const ServiceDetailState({this.status = ServiceDetailStatus.loading, this.service, this.failure});

  final ServiceDetailStatus status;
  final SubscriberService? service;
  final Failure? failure;

  @override
  List<Object?> get props => [status, service, failure];
}

class ServiceDetailCubit extends Cubit<ServiceDetailState> {
  ServiceDetailCubit(this._repository, this.serviceId) : super(const ServiceDetailState()) {
    load();
  }

  final SubscriberRepository _repository;
  final String serviceId;

  /// For the actions (change plan, cancel) opened from the detail page.
  SubscriberRepository get repository => _repository;

  /// Shows [service] (a platform answer to an action) before the refresh lands.
  void applyService(SubscriberService service) {
    if (isClosed) return;
    emit(ServiceDetailState(status: ServiceDetailStatus.loaded, service: service));
  }

  Future<void> load({bool keepVisible = false}) async {
    if (!keepVisible || state.service == null) emit(const ServiceDetailState());
    final result = await _repository.getService(serviceId);
    if (isClosed) return;
    result.match((failure) {
      if (keepVisible && state.service != null) return;
      emit(ServiceDetailState(status: ServiceDetailStatus.failure, failure: failure));
    }, (service) => emit(ServiceDetailState(status: ServiceDetailStatus.loaded, service: service)));
  }
}
