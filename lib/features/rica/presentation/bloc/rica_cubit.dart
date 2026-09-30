import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';

enum RicaStatus { initial, verifying, verified, failure }

/// Why verification did not complete; drives the retry guidance on screen.
enum RicaFailureReason { notVerified, network, orderError }

class RicaState extends Equatable {
  const RicaState({this.status = RicaStatus.initial, this.failureReason});

  final RicaStatus status;
  final RicaFailureReason? failureReason;

  RicaState copyWith({RicaStatus? status, RicaFailureReason? failureReason}) {
    return RicaState(status: status ?? this.status, failureReason: failureReason);
  }

  @override
  List<Object?> get props => [status, failureReason];
}

/// Identity (RICA) check for one order. On success the order is advanced to
/// `awaitingPayment`; on failure it stays `pendingVerification`, so the
/// customer can retry here or resume later from the dashboard.
class RicaCubit extends Cubit<RicaState> {
  RicaCubit(this._liveness, this._checkout, this.orderId) : super(const RicaState());

  final LivenessRepository _liveness;
  final CheckoutRepository _checkout;
  final String orderId;

  Future<void> verify() async {
    if (state.status == RicaStatus.verifying) return;
    emit(state.copyWith(status: RicaStatus.verifying));
    final liveness = await _liveness.verifyLiveness();
    if (isClosed) return;
    final passed = liveness.match((_) => false, (ok) => ok);
    if (!passed) {
      emit(state.copyWith(status: RicaStatus.failure, failureReason: RicaFailureReason.notVerified));
      return;
    }
    final order = await _checkout.markIdentityVerified(orderId);
    if (isClosed) return;
    order.match(
      (failure) => emit(state.copyWith(
        status: RicaStatus.failure,
        // The liveness check itself passed; retrying will re-run it, which
        // is acceptable for a mock but a real vendor would return a
        // verification id to attach on retry instead.
        failureReason: failure is NetworkFailure ? RicaFailureReason.network : RicaFailureReason.orderError,
      )),
      (_) => emit(state.copyWith(status: RicaStatus.verified)),
    );
  }
}
