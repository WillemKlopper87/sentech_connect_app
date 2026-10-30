import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';

enum CancelServiceStatus { idle, submitting, done }

class CancelServiceState extends Equatable {
  const CancelServiceState({this.status = CancelServiceStatus.idle, this.failure, this.reasonMissing = false, this.service});

  final CancelServiceStatus status;
  final Failure? failure;

  /// The customer pressed confirm without choosing a reason.
  final bool reasonMissing;

  /// The service as the platform has it after a successful cancel.
  final SubscriberService? service;

  @override
  List<Object?> get props => [status, failure, reasonMissing, service];
}

/// Schedules the end of one service. The `Idempotency-Key` belongs to the
/// reason text: retrying the same text (after offline, say) reuses it so the
/// platform can answer with the first agreed date; a changed reason is a new
/// attempt.
class CancelServiceCubit extends Cubit<CancelServiceState> {
  CancelServiceCubit(this._repository, this.service, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey,
      super(const CancelServiceState());

  final SubscriberRepository _repository;
  final SubscriberService service;
  final String Function() _newKey;
  String? _key;
  String? _keyReason;

  Future<void> submit(CancelReason? reason, [String? detail]) async {
    if (state.status == CancelServiceStatus.submitting) return;
    if (reason == null) {
      emit(const CancelServiceState(reasonMissing: true));
      return;
    }
    final text = cancelReasonText(reason, detail);
    if (_key == null || _keyReason != text) {
      _key = _newKey();
      _keyReason = text;
    }
    emit(const CancelServiceState(status: CancelServiceStatus.submitting));
    final result = await _repository.cancel(service.id, text, idempotencyKey: _key!);
    if (isClosed) return;
    result.match(
      (failure) => emit(CancelServiceState(failure: failure)),
      (updated) => emit(CancelServiceState(status: CancelServiceStatus.done, service: updated)),
    );
  }
}
