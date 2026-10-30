import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/repositories/hotspot_login_repository.dart';

enum HotspotLoginStatus { idle, requesting, ready, expired, failure }

class HotspotLoginState extends Equatable {
  const HotspotLoginState({
    this.status = HotspotLoginStatus.idle,
    this.token,
    this.remaining = Duration.zero,
    this.failure,
  });

  final HotspotLoginStatus status;

  /// Only while [status] is `ready`: an expired or failed state holds no secret.
  final LoginToken? token;
  final Duration remaining;
  final Failure? failure;

  @override
  List<Object?> get props => [status, token, remaining, failure];
}

/// Holds one Wi-Fi login in memory (never persisted) and counts down to its
/// expiry. Each [request] asks the platform for a new login. The countdown
/// uses [now] (an injectable clock, so tests need no real time).
class HotspotLoginCubit extends Cubit<HotspotLoginState> {
  HotspotLoginCubit(
    this._repository, {
    DateTime Function()? now,
    bool autoTick = true,
  }) : _now = now ?? DateTime.now,
       _autoTick = autoTick, // ignore: prefer_initializing_formals
       super(const HotspotLoginState());

  final HotspotLoginRepository _repository;
  final DateTime Function() _now;
  final bool _autoTick;
  Timer? _ticker;

  Future<void> request() async {
    if (state.status == HotspotLoginStatus.requesting) return;
    _ticker?.cancel();
    emit(const HotspotLoginState(status: HotspotLoginStatus.requesting));
    final result = await _repository.createLoginToken();
    if (isClosed) return;
    result.match(
      (failure) => emit(
        HotspotLoginState(status: HotspotLoginStatus.failure, failure: failure),
      ),
      (token) {
        final remaining = token.expiresAt.difference(_now());
        if (remaining <= Duration.zero) {
          // Already past: the device clock and the platform disagree.
          emit(const HotspotLoginState(status: HotspotLoginStatus.expired));
          return;
        }
        emit(
          HotspotLoginState(
            status: HotspotLoginStatus.ready,
            token: token,
            remaining: remaining,
          ),
        );
        if (_autoTick) {
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
        }
      },
    );
  }

  /// Recomputes the time left; at zero the login (and its password) is dropped.
  void tick() {
    final token = state.token;
    if (isClosed || state.status != HotspotLoginStatus.ready || token == null) {
      return;
    }
    final remaining = token.expiresAt.difference(_now());
    if (remaining <= Duration.zero) {
      _ticker?.cancel();
      emit(const HotspotLoginState(status: HotspotLoginStatus.expired));
    } else {
      emit(
        HotspotLoginState(
          status: HotspotLoginStatus.ready,
          token: token,
          remaining: remaining,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
