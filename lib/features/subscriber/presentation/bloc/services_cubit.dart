import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum ServicesStatus { loading, loaded, failure }

class ServicesState extends Equatable {
  const ServicesState({this.status = ServicesStatus.loading, this.services = const [], this.failure});

  final ServicesStatus status;

  /// As the API orders them (newest first).
  final List<SubscriberService> services;
  final Failure? failure;

  /// Everything but `cancelled`, API order.
  List<SubscriberService> get current => [for (final s in services) if (s.status != ServiceStatus.cancelled) s];

  List<SubscriberService> get past => [for (final s in services) if (s.status == ServiceStatus.cancelled) s];

  @override
  List<Object?> get props => [status, services, failure];
}

/// The customer's services. An account that never signed up is simply an
/// empty list (the repository folds `subscriber_not_found` into that).
class ServicesCubit extends Cubit<ServicesState> {
  ServicesCubit(this._repository) : super(const ServicesState()) {
    load();
  }

  final SubscriberRepository _repository;

  /// [keepVisible] keeps the current list on screen while refreshing (pull to
  /// refresh); a failed refresh then keeps the old list too.
  Future<void> load({bool keepVisible = false}) async {
    if (!keepVisible || state.status != ServicesStatus.loaded) {
      emit(const ServicesState());
    }
    final result = await _repository.listServices();
    if (isClosed) return;
    result.match(
      (failure) {
        if (keepVisible && state.status == ServicesStatus.loaded) return;
        emit(ServicesState(status: ServicesStatus.failure, failure: failure));
      },
      (services) => emit(ServicesState(status: ServicesStatus.loaded, services: services)),
    );
  }
}
