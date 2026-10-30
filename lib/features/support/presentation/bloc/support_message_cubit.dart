import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/support/domain/entities/support_message.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';

enum SupportSendStatus { editing, sending, sent }

class SupportMessageState extends Equatable {
  const SupportMessageState({
    this.status = SupportSendStatus.editing,
    this.failure,
    this.issue,
    this.receipt,
  });

  final SupportSendStatus status;

  /// The last send failed (the draft is kept so the customer can retry).
  final Failure? failure;

  /// The draft was refused on the device before anything was sent.
  final SupportDraftIssue? issue;
  final SupportReceipt? receipt;

  @override
  List<Object?> get props => [status, failure, issue, receipt];
}

class SupportMessageCubit extends Cubit<SupportMessageState> {
  SupportMessageCubit(this._repository, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey,
      super(const SupportMessageState());

  final SupportMessageRepository _repository;
  final String Function() _newKey;

  // One key per submission. A retry of the SAME draft reuses it (the server
  // then returns the stored reference instead of a second message); a changed
  // draft is a new submission with a new key (the server refuses a key reused
  // with another body: 422 idempotency_key_reused).
  SupportMessageDraft? _attempted;
  String? _key;

  Future<void> send(SupportMessageDraft draft) async {
    if (state.status == SupportSendStatus.sending) return; // double-tap guard
    final issue = draft.issue;
    if (issue != null) {
      emit(SupportMessageState(issue: issue));
      return;
    }
    if (_attempted != draft || _key == null) {
      _attempted = draft;
      _key = _newKey();
    }
    emit(const SupportMessageState(status: SupportSendStatus.sending));
    final result = await _repository.send(draft, idempotencyKey: _key!);
    if (isClosed) return;
    result.match(
      // The customer closed the human check: back to the form, no error.
      (failure) => emit(
        failure is HumanCheckCancelledFailure
            ? const SupportMessageState()
            : SupportMessageState(failure: failure),
      ),
      (receipt) {
        _attempted = null;
        _key = null;
        emit(
          SupportMessageState(status: SupportSendStatus.sent, receipt: receipt),
        );
      },
    );
  }
}
