import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_banner.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum ServicesStatus { loading, loaded, failure }

class ServicesState extends Equatable {
  const ServicesState({this.status = ServicesStatus.loading, this.services = const [], this.failure, this.kycStatus});

  final ServicesStatus status;

  /// As the API orders them (newest first).
  final List<SubscriberService> services;
  final Failure? failure;

  /// The ID check status, read only when a service's banner depends on it;
  /// null when not needed, not found or unreadable (generic banners then).
  final KycStatus? kycStatus;

  /// Everything but `cancelled`, API order.
  List<SubscriberService> get current => [for (final s in services) if (s.status != ServiceStatus.cancelled) s];

  List<SubscriberService> get past => [for (final s in services) if (s.status == ServiceStatus.cancelled) s];

  @override
  List<Object?> get props => [status, services, failure, kycStatus];
}

/// The customer's services. An account that never signed up is simply an
/// empty list (the repository folds `subscriber_not_found` into that).
class ServicesCubit extends Cubit<ServicesState> {
  ServicesCubit(this._repository, {this._kyc}) : super(const ServicesState()) {
    load();
  }

  final SubscriberRepository _repository;
  final KycRepository? _kyc;

  /// [keepVisible] keeps the current list on screen while refreshing (pull to
  /// refresh); a failed refresh then keeps the old list too.
  Future<void> load({bool keepVisible = false}) async {
    if (!keepVisible || state.status != ServicesStatus.loaded) {
      emit(const ServicesState());
    }
    final result = await _repository.listServices();
    if (isClosed) return;
    await result.match(
      (failure) async {
        if (keepVisible && state.status == ServicesStatus.loaded) return;
        emit(ServicesState(status: ServicesStatus.failure, failure: failure));
      },
      (services) async {
        emit(ServicesState(status: ServicesStatus.loaded, services: services, kycStatus: state.kycStatus));
        await _loadKyc(services);
      },
    );
  }

  /// Only reads the ID check when some service's banner depends on it. A
  /// failure keeps the generic banner (the status is a refinement, not data
  /// the screen needs).
  Future<void> _loadKyc(List<SubscriberService> services) async {
    final repository = _kyc;
    if (repository == null) return;
    if (!services.any(serviceBannerUsesKyc)) {
      if (state.kycStatus != null) emit(ServicesState(status: state.status, services: services));
      return;
    }
    final result = await repository.getStatus();
    if (isClosed) return;
    final status = result.match((_) => null, (record) => record?.status);
    emit(ServicesState(status: ServicesStatus.loaded, services: services, kycStatus: status));
  }
}
