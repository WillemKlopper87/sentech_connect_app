import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';

enum PrivacyActionStatus { idle, working, exportRequested, deleted, failed }

class PrivacyActionsState extends Equatable {
  const PrivacyActionsState({this.status = PrivacyActionStatus.idle, this.receipt, this.failure});

  final PrivacyActionStatus status;
  final PrivacyRequestReceipt? receipt;

  /// Why the last action failed (set with [PrivacyActionStatus.failed]); the
  /// page maps it to a customer-facing message.
  final Failure? failure;

  @override
  List<Object?> get props => [status, receipt, failure];
}

/// Data-subject actions from the Account tab. [onAccountDeleted] runs only
/// after the server ACCEPTED the deletion, and performs the local wipe +
/// sign-out (wired to `AuthCubit.signOutAndWipeEverything` by the page).
class PrivacyActionsCubit extends Cubit<PrivacyActionsState> {
  PrivacyActionsCubit(this._repository, {required this.onAccountDeleted}) : super(const PrivacyActionsState());

  final PrivacyRepository _repository;
  final Future<void> Function() onAccountDeleted;

  Future<void> requestDataExport() async {
    if (state.status == PrivacyActionStatus.working) return;
    emit(const PrivacyActionsState(status: PrivacyActionStatus.working));
    final result = await _repository.requestDataExport();
    if (isClosed) return;
    emit(result.match(
      (failure) => PrivacyActionsState(status: PrivacyActionStatus.failed, failure: failure),
      (receipt) => PrivacyActionsState(status: PrivacyActionStatus.exportRequested, receipt: receipt),
    ));
  }

  Future<void> deleteAccount() async {
    if (state.status == PrivacyActionStatus.working) return;
    emit(const PrivacyActionsState(status: PrivacyActionStatus.working));
    final result = await _repository.requestAccountDeletion();
    final failure = result.match((f) => f, (_) => null);
    if (failure != null) {
      if (!isClosed) emit(PrivacyActionsState(status: PrivacyActionStatus.failed, failure: failure));
      return;
    }
    // Server accepted: now remove everything held on this device and sign out.
    await onAccountDeleted();
    if (!isClosed) emit(const PrivacyActionsState(status: PrivacyActionStatus.deleted));
  }
}
