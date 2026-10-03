import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';

/// [scanning] is the only state in which the camera may deliver codes; every
/// other state means "paused until the result is dismissed", which is what
/// stops a QR that stays in frame from being re-submitted in a loop.
enum VoucherStatus { scanning, redeeming, result }

class VoucherState extends Equatable {
  const VoucherState({
    this.status = VoucherStatus.scanning,
    this.outcome,
    this.failure,
    this.maskedCode,
    this.dataMb,
    this.productName,
    this.inputProblem,
  });

  final VoucherStatus status;

  /// Server verdict, or [VoucherOutcome.invalid] for input that failed the
  /// local format check. Null when [failure] explains a transport error.
  final VoucherOutcome? outcome;
  final Failure? failure;

  /// Masked code safe to display; null for unparseable input (the raw
  /// payload is never kept, let alone shown).
  final String? maskedCode;
  final int? dataMb;
  final String? productName;

  /// Set when the input was refused on the device (no request was sent),
  /// so the result can say what to fix.
  final VoucherCodeProblem? inputProblem;

  @override
  List<Object?> get props => [status, outcome, failure, maskedCode, dataMb, productName, inputProblem];
}

class VoucherCubit extends Cubit<VoucherState> {
  VoucherCubit(this._repository, {this.allowDemoCodes = false}) : super(const VoucherState());

  final VoucherRepository _repository;

  /// Demo flavor only: also accept the mock's `SEN-XXXX-XXXX` codes. Prod
  /// accepts exactly what the server accepts.
  final bool allowDemoCodes;
  VoucherCode? _lastCode; // kept so "try again" after a network error needs no re-scan

  /// Entry point for both the camera and manual entry. Ignored unless
  /// scanning, so duplicate detections while a result is on screen are
  /// no-ops.
  Future<void> submit(String? raw) async {
    if (state.status != VoucherStatus.scanning) return;
    final code = VoucherCode.tryParse(raw, allowDemo: allowDemoCodes);
    if (code == null) {
      // The server would refuse it: no request, and say what to fix.
      emit(VoucherState(
        status: VoucherStatus.result,
        outcome: VoucherOutcome.invalid,
        inputProblem: VoucherCode.problemWith(raw, allowDemo: allowDemoCodes),
      ));
      return;
    }
    _lastCode = code;
    await _redeem(code);
  }

  /// Retries the last well-formed code after a transport failure.
  Future<void> retry() async {
    final code = _lastCode;
    if (code == null || state.status != VoucherStatus.result || state.failure == null) return;
    await _redeem(code);
  }

  Future<void> _redeem(VoucherCode code) async {
    emit(VoucherState(status: VoucherStatus.redeeming, maskedCode: code.masked));
    final result = await _repository.redeem(code);
    if (isClosed) return;
    result.match(
      (failure) => emit(VoucherState(status: VoucherStatus.result, failure: failure, maskedCode: code.masked)),
      (r) => emit(VoucherState(
        status: VoucherStatus.result,
        outcome: r.outcome,
        maskedCode: code.masked,
        dataMb: r.dataMb,
        productName: r.productName,
      )),
    );
  }

  /// Result dismissed: scanning may resume.
  void dismiss() {
    _lastCode = null;
    emit(const VoucherState());
  }
}
