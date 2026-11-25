import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

/// There is deliberately no "removed" status: the app only STARTS leaving the
/// list. The platform sends a one-time link to the contact, and the contact is
/// removed only when that link is opened and confirmed on the website.
enum WithdrawalStatus { idle, submitting, requested, failed }

class WithdrawalState extends Equatable {
  const WithdrawalState({this.status = WithdrawalStatus.idle, this.failure});

  final WithdrawalStatus status;
  final Failure? failure;

  @override
  List<Object?> get props => [status, failure];
}

/// Asks the platform to send the leave-the-list link. The contact is passed in
/// and never kept. A double tap sends one request.
class WithdrawalCubit extends Cubit<WithdrawalState> {
  WithdrawalCubit(this._repository) : super(const WithdrawalState());

  final CoverageRepository _repository;

  Future<void> request(WithdrawalRequest request) async {
    if (isClosed || state.status == WithdrawalStatus.submitting) return;
    emit(const WithdrawalState(status: WithdrawalStatus.submitting));
    final result = await _repository.requestWithdrawal(request);
    if (isClosed) return;
    switch (result) {
      case Right():
        emit(const WithdrawalState(status: WithdrawalStatus.requested));
      case Left(value: final failure):
        emit(WithdrawalState(status: WithdrawalStatus.failed, failure: failure));
    }
  }

  void dismiss() {
    if (!isClosed && state.status != WithdrawalStatus.submitting) emit(const WithdrawalState());
  }
}
