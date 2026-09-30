import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_result.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

enum CoverageStatus { initial, checking, checked, failure }

class CoverageState extends Equatable {
  const CoverageState({this.status = CoverageStatus.initial, this.result, this.errorMessage, this.failure});

  final CoverageStatus status;
  final CoverageResult? result;
  final String? errorMessage;
  final Failure? failure;

  CoverageState copyWith({CoverageStatus? status, CoverageResult? result, String? errorMessage, Failure? failure}) {
    return CoverageState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, result, errorMessage, failure];
}

class CoverageCubit extends Cubit<CoverageState> {
  CoverageCubit(this._repository) : super(const CoverageState());

  final CoverageRepository _repository;
  String? _lastAddress;

  /// Re-runs the last check after a failure (e.g. once back online).
  Future<void> retry() async {
    final address = _lastAddress;
    if (address != null) await checkAddress(address);
  }

  Future<void> checkAddress(String address) async {
    emit(state.copyWith(status: CoverageStatus.checking));
    _lastAddress = address;
    final result = await _repository.checkAddress(address);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: CoverageStatus.failure, errorMessage: failure.message, failure: failure)),
      (coverage) => emit(state.copyWith(status: CoverageStatus.checked, result: coverage)),
    );
  }

  void reset() => emit(const CoverageState());
}
