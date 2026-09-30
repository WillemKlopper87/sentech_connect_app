import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/repositories/account_repository.dart';

enum AccountStatus { loading, loaded, failure }

class AccountState extends Equatable {
  const AccountState({this.status = AccountStatus.loading, this.summary, this.failure});

  final AccountStatus status;
  final AccountSummary? summary;
  final Failure? failure;

  AccountState copyWith({AccountStatus? status, AccountSummary? summary, Failure? failure}) {
    return AccountState(status: status ?? this.status, summary: summary ?? this.summary, failure: failure);
  }

  @override
  List<Object?> get props => [status, summary, failure];
}

class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._repository) : super(const AccountState()) {
    load();
  }

  final AccountRepository _repository;

  /// Also the retry entry point after a failed load.
  Future<void> load() async {
    emit(state.copyWith(status: AccountStatus.loading));
    final result = await _repository.getSummary();
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: AccountStatus.failure, failure: failure)),
      (summary) => emit(state.copyWith(status: AccountStatus.loaded, summary: summary)),
    );
  }
}
