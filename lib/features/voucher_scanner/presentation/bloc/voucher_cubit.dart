import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_code.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/entities/voucher_redemption.dart';
import 'package:sentech_connect_app/features/voucher_scanner/domain/repositories/voucher_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

/// [scanning] is the only state in which the camera may deliver codes; every
/// other state means "paused until the result is dismissed", which is what
/// stops a QR that stays in frame from being re-submitted in a loop.
enum VoucherStatus { scanning, entering, redeeming, result }

class VoucherState extends Equatable {
  const VoucherState({
    this.status = VoucherStatus.scanning,
    this.outcome,
    this.failure,
    this.maskedCode,
    this.dataMb,
    this.productName,
    this.inputProblem,
    this.pass,
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
  final Pass? pass;

  /// Set when the input was refused on the device (no request was sent),
  /// so the result can say what to fix.
  final VoucherCodeProblem? inputProblem;

  @override
  List<Object?> get props => [
    status,
    outcome,
    failure,
    maskedCode,
    dataMb,
    productName,
    inputProblem,
    pass,
  ];
}

class VoucherCubit extends Cubit<VoucherState> {
  VoucherCubit(this._repository, {this.allowDemoCodes = false})
    : super(const VoucherState());

  final VoucherRepository _repository;

  /// Demo flavor only: also accept the mock's `SEN-XXXX-XXXX` codes. Prod
  /// accepts exactly what the server accepts.
  final bool allowDemoCodes;
  // Held only during this result flow so an uncertain retry needs no re-scan.
  VoucherCode? _lastCode;
  int _flow = 0;

  /// Pause scanning throughout entry, including a correction after refusal.
  bool beginEntry() {
    if (state.status != VoucherStatus.scanning &&
        state.status != VoucherStatus.result) {
      return false;
    }
    _clearRetry();
    emit(const VoucherState(status: VoucherStatus.entering));
    return true;
  }

  /// Entry point for the camera (scanning) and the manual sheet (entering).
  /// The page ignores camera detections during entry; further submissions
  /// during redemption or results are no-ops.
  Future<void> submit(String? raw) async {
    if (state.status != VoucherStatus.scanning &&
        state.status != VoucherStatus.entering) {
      return;
    }
    final code = VoucherCode.tryParse(raw, allowDemo: allowDemoCodes);
    if (code == null) {
      // The server would refuse it: no request, and say what to fix.
      emit(
        VoucherState(
          status: VoucherStatus.result,
          outcome: VoucherOutcome.invalid,
          inputProblem: VoucherCode.problemWith(raw, allowDemo: allowDemoCodes),
        ),
      );
      return;
    }
    _lastCode = code;
    await _redeem(code);
  }

  /// Retries the last well-formed code after a transport failure.
  Future<void> retry() async {
    final code = _lastCode;
    if (code == null ||
        state.status != VoucherStatus.result ||
        state.failure == null) {
      return;
    }
    await _redeem(code);
  }

  Future<void> _redeem(VoucherCode code) async {
    final flow = _flow;
    emit(
      VoucherState(status: VoucherStatus.redeeming, maskedCode: code.masked),
    );
    final result = await _repository.redeem(code);
    if (isClosed || flow != _flow) return;
    result.match(
      (failure) => emit(
        VoucherState(
          status: VoucherStatus.result,
          failure: failure,
          maskedCode: code.masked,
        ),
      ),
      (r) => emit(
        VoucherState(
          status: VoucherStatus.result,
          outcome: r.outcome,
          maskedCode: code.masked,
          dataMb: r.dataMb,
          productName: r.productName,
          pass: r.pass,
        ),
      ),
    );
  }

  /// Result dismissed: scanning may resume.
  void dismiss() {
    _clearRetry();
    emit(const VoucherState());
  }

  void _clearRetry() {
    _flow++;
    _lastCode = null;
    _repository.endRedemptionFlow();
  }

  @override
  Future<void> close() {
    _clearRetry();
    return super.close();
  }
}
