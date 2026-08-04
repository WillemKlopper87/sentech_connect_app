import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/repositories/account_repository.dart';

enum AccountStatus { loading, loaded, failure }

class AccountState extends Equatable {
  const AccountState({this.status = AccountStatus.loading, this.summary});

  final AccountStatus status;
  final AccountSummary? summary;

  AccountState copyWith({AccountStatus? status, AccountSummary? summary}) {
    return AccountState(status: status ?? this.status, summary: summary ?? this.summary);
  }

  @override
  List<Object?> get props => [status, summary];
}

class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._repository) : super(const AccountState()) {
    _load();
  }

  final AccountRepository _repository;

  Future<void> _load() async {
    final result = await _repository.getSummary();
    result.match(
      (_) => emit(state.copyWith(status: AccountStatus.failure)),
      (summary) => emit(state.copyWith(status: AccountStatus.loaded, summary: summary)),
    );
  }
}
