import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

enum CoverageStatus { initial, checking, checked, failure }

class CoverageState extends Equatable {
  const CoverageState({this.status = CoverageStatus.initial, this.result, this.errorMessage});

  final CoverageStatus status;
  final CoverageResult? result;
  final String? errorMessage;

  CoverageState copyWith({CoverageStatus? status, CoverageResult? result, String? errorMessage}) {
    return CoverageState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, result, errorMessage];
}

class CoverageCubit extends Cubit<CoverageState> {
  CoverageCubit(this._repository) : super(const CoverageState());

  final CoverageRepository _repository;

  Future<void> checkAddress(String address) async {
    emit(state.copyWith(status: CoverageStatus.checking));
    final result = await _repository.checkAddress(address);
    result.match(
      (failure) => emit(state.copyWith(status: CoverageStatus.failure, errorMessage: failure.message)),
      (coverage) => emit(state.copyWith(status: CoverageStatus.checked, result: coverage)),
    );
  }

  void reset() => emit(const CoverageState());
}
