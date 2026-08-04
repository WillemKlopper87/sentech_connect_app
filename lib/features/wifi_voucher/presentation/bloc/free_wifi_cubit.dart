import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/free_wifi_session.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

enum FreeWifiStatus { loading, ready, watchingAd, failure }

class FreeWifiState extends Equatable {
  const FreeWifiState({
    this.status = FreeWifiStatus.loading,
    this.adsWatchedToday = 0,
    this.session,
    this.errorMessage,
  });

  final FreeWifiStatus status;
  final int adsWatchedToday;
  final FreeWifiSession? session;
  final String? errorMessage;

  int get adsRemainingToday => (FreeWifiRepository.maxAdsPerDay - adsWatchedToday).clamp(0, FreeWifiRepository.maxAdsPerDay);

  bool get hasActiveSession => session != null && !session!.isExpired;

  bool get canWatchAd => adsRemainingToday > 0 && !hasActiveSession;

  FreeWifiState copyWith({
    FreeWifiStatus? status,
    int? adsWatchedToday,
    FreeWifiSession? session,
    bool clearSession = false,
    String? errorMessage,
  }) {
    return FreeWifiState(
      status: status ?? this.status,
      adsWatchedToday: adsWatchedToday ?? this.adsWatchedToday,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, adsWatchedToday, session, errorMessage];
}

class FreeWifiCubit extends Cubit<FreeWifiState> {
  FreeWifiCubit(this._repository) : super(const FreeWifiState()) {
    _load();
  }

  final FreeWifiRepository _repository;

  Future<void> _load() async {
    final adsResult = await _repository.getAdsWatchedToday();
    final sessionResult = await _repository.getActiveSession();
    emit(state.copyWith(
      status: FreeWifiStatus.ready,
      adsWatchedToday: adsResult.getOrElse((_) => 0),
      session: sessionResult.getOrElse((_) => null),
    ));
  }

  void beginWatchingAd() => emit(state.copyWith(status: FreeWifiStatus.watchingAd));

  Future<void> completeAdAndClaim() async {
    final result = await _repository.recordAdWatchedAndGrantSession();
    result.match(
      (failure) => emit(state.copyWith(status: FreeWifiStatus.failure, errorMessage: failure.message)),
      (session) => emit(state.copyWith(
        status: FreeWifiStatus.ready,
        adsWatchedToday: state.adsWatchedToday + 1,
        session: session,
      )),
    );
  }

  void cancelWatchingAd() => emit(state.copyWith(status: FreeWifiStatus.ready));

  /// Called periodically by the UI (a simple ticking Timer, since the
  /// countdown itself is just wall-clock math and doesn't need a state
  /// change to redraw) — this only clears the session once it's actually
  /// expired, which is a real state transition.
  void checkExpiry() {
    if (state.session != null && state.session!.isExpired) {
      emit(state.copyWith(clearSession: true));
    }
  }
}
