import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

/// `loading`: reading the plan; `ready`: the form; `submitting`; `done`: the
/// signup exists (see [SignupState.result]); `planMissing`: the plan is gone
/// from the list; `loadFailed`: the plan list could not be read.
enum SignupPhase { loading, ready, submitting, done, planMissing, loadFailed }

class SignupState extends Equatable {
  const SignupState({
    this.phase = SignupPhase.loading,
    this.plan,
    this.address = '',
    this.acceptTerms = false,
    this.showErrors = false,
    this.failure,
    this.result,
  });

  final SignupPhase phase;
  final SubscriberPlan? plan;
  final String address;
  final bool acceptTerms;

  /// Field problems appear only after the first submit attempt.
  final bool showErrors;

  /// The last submit (or the plan read) failed; the draft is kept for a retry.
  final Failure? failure;
  final SubscriberSignup? result;

  bool get busy => phase == SignupPhase.submitting;

  bool get needsAddress => plan?.kind == SubscriberPlanKind.fixedWireless;

  SignupState copyWith({
    SignupPhase? phase,
    SubscriberPlan? plan,
    String? address,
    bool? acceptTerms,
    bool? showErrors,
    Failure? failure,
    SubscriberSignup? result,
  }) => SignupState(
    phase: phase ?? this.phase,
    plan: plan ?? this.plan,
    address: address ?? this.address,
    acceptTerms: acceptTerms ?? this.acceptTerms,
    showErrors: showErrors ?? this.showErrors,
    failure: failure,
    result: result ?? this.result,
  );

  @override
  List<Object?> get props => [phase, plan, address, acceptTerms, showErrors, failure, result];

  // The address is personal data: never in logs.
  @override
  String toString() => 'SignupState(phase: $phase)';
}

/// Plan summary and confirmation for one plan. The install address is asked
/// (and required by the app) for fixed wireless only; the server does not
/// require it. One `Idempotency-Key` per draft: a retry of the same draft
/// reuses it (a double tap or a lost response never makes a second service),
/// any edit starts a new one.
class SignupCubit extends Cubit<SignupState> {
  SignupCubit(
    this._plans,
    this._repository,
    this.planId, {
    required this.termsVersion,
    String Function()? newKey,
  }) : _newKey = newKey ?? newIdempotencyKey,
       super(const SignupState()) {
    load();
  }

  final SubscriberPlansRepository _plans;
  final SubscriberRepository _repository;
  final String planId;

  /// `app-config.legal.terms`, or null while no config is loaded (submitting
  /// is then refused with a retryable failure).
  final String? Function() termsVersion;
  final String Function() _newKey;

  String? _key;

  Future<void> load() async {
    emit(const SignupState());
    final result = await _plans.list();
    if (isClosed) return;
    result.match((failure) => emit(SignupState(phase: SignupPhase.loadFailed, failure: failure)), (plans) {
      final plan = [for (final p in plans) if (p.id == planId) p];
      emit(
        plan.isEmpty
            ? const SignupState(phase: SignupPhase.planMissing)
            : SignupState(phase: SignupPhase.ready, plan: plan.first),
      );
    });
  }

  void setAddress(String value) {
    if (state.busy) return;
    _key = null;
    emit(state.copyWith(address: value));
  }

  void setAcceptTerms(bool value) {
    if (state.busy) return;
    _key = null;
    emit(state.copyWith(acceptTerms: value));
  }

  /// The address as it is sent: trimmed, `null` for plans that do not need one.
  String? get _address => state.needsAddress ? state.address.trim() : null;

  bool get addressValid => !state.needsAddress || _addressOk(state.address);

  static bool _addressOk(String raw) {
    final v = raw.trim();
    // Server: 1..2000 characters, no control characters.
    return v.isNotEmpty && v.length <= 2000 && !RegExp(r'[\x00-\x1f\x7f]').hasMatch(v);
  }

  Future<void> submit() async {
    if (state.busy || state.phase == SignupPhase.done || state.plan == null) return;
    if (!state.acceptTerms || !addressValid) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    final version = termsVersion();
    if (version == null) {
      emit(state.copyWith(showErrors: true, failure: const ConsentVersionOutdatedFailure()));
      return;
    }
    final key = _key ??= _newKey();
    emit(state.copyWith(phase: SignupPhase.submitting));
    final result = await _repository.signup(
      planId: state.plan!.id,
      termsVersion: version,
      idempotencyKey: key,
      installAddress: _address,
    );
    if (isClosed) return;
    result.match(
      (failure) {
        // The platform rolls a refused signup back, so the same key stays safe
        // to retry. A changed terms version changes the body, which a reused
        // key would refuse: start a new key for that one.
        if (failure is ConsentVersionOutdatedFailure) _key = null;
        // The plan is gone: the form cannot work again, send the customer back to the list.
        emit(
          failure is PlanUnavailableFailure
              ? SignupState(phase: SignupPhase.planMissing, failure: failure)
              : state.copyWith(phase: SignupPhase.ready, failure: failure),
        );
      },
      // The draft (address) leaves memory with the form.
      (signup) => emit(SignupState(phase: SignupPhase.done, plan: state.plan, result: signup)),
    );
  }
}
