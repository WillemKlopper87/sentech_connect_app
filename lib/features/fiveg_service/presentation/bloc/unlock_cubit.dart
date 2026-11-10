import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';

enum UnlockStatus {
  /// An offer is chosen; nothing has been sent yet.
  choosing,

  /// The unlock order is being created.
  creating,

  /// [UnlockState.orderId] is ready to pay: created now, or resumed.
  ready,
  failure,
}

class UnlockState extends Equatable {
  const UnlockState({this.status = UnlockStatus.choosing, this.offer, this.orderId, this.failure});

  final UnlockStatus status;
  final UnlockOffer? offer;

  /// The unpaid unlock order to hand to the shared payment screen.
  final String? orderId;
  final Failure? failure;

  @override
  List<Object?> get props => [status, offer, orderId, failure];
}

/// Buys one unlock: creates the order for the chosen offer and hands its id
/// to the payment screen. One idempotency key per offer and attempt: a retry
/// of the same offer reuses it, a different offer starts a new one. A 409
/// `unlock_order_open` resumes the order that is already waiting, instead of
/// creating a second one.
class UnlockCubit extends Cubit<UnlockState> {
  UnlockCubit(this._repository, this.serviceId, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey,
      super(const UnlockState());

  final FiveGRepository _repository;
  final String serviceId;
  final String Function() _newKey;

  String? _keyCode;
  String? _key;

  bool get _busy => state.status == UnlockStatus.creating || state.status == UnlockStatus.ready;

  void choose(UnlockOffer offer) {
    if (isClosed || _busy) return;
    emit(UnlockState(offer: offer));
  }

  Future<void> confirm() async {
    final offer = state.offer;
    if (isClosed || offer == null || _busy) return;
    if (_key == null || _keyCode != offer.code) {
      _keyCode = offer.code;
      _key = _newKey();
    }
    emit(UnlockState(status: UnlockStatus.creating, offer: offer));
    final result = await _repository.createUnlockOrder(serviceId, productCode: offer.code, idempotencyKey: _key!);
    if (isClosed) return;
    switch (result) {
      case Right(value: final order):
        emit(UnlockState(status: UnlockStatus.ready, offer: offer, orderId: order.id));
      case Left(value: final UnlockOrderOpenFailure failure):
        await _resume(offer, failure);
      case Left(value: final failure):
        emit(UnlockState(status: UnlockStatus.failure, offer: offer, failure: failure));
    }
  }

  /// Finds the unpaid order the server already holds for this service.
  Future<void> _resume(UnlockOffer offer, Failure refusal) async {
    final result = await _repository.getUsage(serviceId);
    if (isClosed) return;
    final pending = result.match((_) => null, (usage) => usage.pendingUnlock);
    if (pending == null) {
      emit(UnlockState(status: UnlockStatus.failure, offer: offer, failure: refusal));
      return;
    }
    emit(UnlockState(status: UnlockStatus.ready, offer: offer, orderId: pending.orderId));
  }
}
