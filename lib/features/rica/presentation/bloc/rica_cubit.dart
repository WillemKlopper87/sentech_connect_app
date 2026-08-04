import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';

enum RicaStatus { initial, verifying, verified, failure }

class RicaState extends Equatable {
  const RicaState({this.status = RicaStatus.initial, this.consentGiven = false});

  final RicaStatus status;
  final bool consentGiven;

  RicaState copyWith({RicaStatus? status, bool? consentGiven}) {
    return RicaState(
      status: status ?? this.status,
      consentGiven: consentGiven ?? this.consentGiven,
    );
  }

  @override
  List<Object?> get props => [status, consentGiven];
}

class RicaCubit extends Cubit<RicaState> {
  RicaCubit(this._repository) : super(const RicaState());

  final LivenessRepository _repository;

  void toggleConsent(bool value) => emit(state.copyWith(consentGiven: value));

  Future<void> verify() async {
    emit(state.copyWith(status: RicaStatus.verifying));
    final result = await _repository.verifyLiveness();
    result.match(
      (_) => emit(state.copyWith(status: RicaStatus.failure)),
      (_) => emit(state.copyWith(status: RicaStatus.verified)),
    );
  }
}
