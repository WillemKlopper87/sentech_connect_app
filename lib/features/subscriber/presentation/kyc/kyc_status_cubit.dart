import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';

enum KycStatusLoad { loading, loaded, failure }

class KycStatusState extends Equatable {
  const KycStatusState({this.load = KycStatusLoad.loading, this.record, this.failure});

  final KycStatusLoad load;

  /// Null when there is no check yet (or it was erased).
  final KycRecord? record;
  final Failure? failure;

  /// The customer has no subscriber account, so there is nothing to check yet.
  bool get noAccount => failure is SubscriberNotFoundFailure;

  @override
  List<Object?> get props => [load, record, failure];
}

class KycStatusCubit extends Cubit<KycStatusState> {
  KycStatusCubit(this._repository) : super(const KycStatusState()) {
    load();
  }

  final KycRepository _repository;

  Future<void> load() async {
    // Keep what is on screen while refreshing; only the first load shows a spinner.
    if (state.load == KycStatusLoad.failure) emit(const KycStatusState());
    final result = await _repository.getStatus();
    if (isClosed) return;
    result.match(
      (failure) => emit(KycStatusState(load: KycStatusLoad.failure, failure: failure)),
      (record) => emit(KycStatusState(load: KycStatusLoad.loaded, record: record)),
    );
  }
}
