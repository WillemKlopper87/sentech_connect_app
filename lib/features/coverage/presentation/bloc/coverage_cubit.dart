import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geo_point.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

enum CoverageStatus {
  /// Nothing asked yet.
  idle,

  /// A check is in flight (or about to be): no answer is shown.
  loading,

  /// The server's answer for [CoverageState.point].
  ready,

  /// An older server, or a provider with no active coverage data.
  unavailable,

  /// Too many checks: wait until [CoverageState.retryAt].
  rateLimited,

  /// The point is outside the service area (decided from the meta bounds without a request, or by the server).
  outside,

  /// Network, timeout or a server fault: retry.
  error,
}

class CoverageState extends Equatable {
  const CoverageState({this.status = CoverageStatus.idle, this.point, this.check, this.meta, this.failure, this.retryAt});

  final CoverageStatus status;

  /// The place being checked (in memory only; prints redacted).
  final GeoPoint? point;

  /// The server's answer, only while [status] is `ready`: never an answer for another point.
  final CoverageCheck? check;
  final CoverageMeta? meta;
  final Failure? failure;
  final DateTime? retryAt;

  @override
  List<Object?> get props => [status, point, check, meta, failure, retryAt];
}

/// Asks the platform what coverage there is at a point.
///
/// Races: every new point (a pin, a picked address, the phone's location)
/// starts a new generation, and an answer for an older generation is dropped,
/// so the screen only ever shows the answer for the latest point and never
/// flickers back to an older one. A new point clears the old answer at once.
/// Map taps are debounced so a flurry of taps sends one request.
class CoverageCubit extends Cubit<CoverageState> {
  CoverageCubit(this._repository, {this.debounce = const Duration(milliseconds: 350), DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const CoverageState());

  final CoverageRepository _repository;
  final Duration debounce;
  final DateTime Function() _now;

  /// The clock the rate-limit wait is measured with (the screen counts down against the same one).
  DateTime now() => _now();

  /// Without a `Retry-After` hint the customer waits this long.
  static const defaultRetryAfter = Duration(seconds: 30);

  int _generation = 0;
  Timer? _timer;

  /// While set (and in the future) no check is sent: the platform's `Retry-After`.
  DateTime? _blockedUntil;

  /// Reads the provider's coverage meta (service area, consent versions, dataset version).
  /// A missing route or no active dataset is `unavailable`; a network blip is ignored here
  /// (the first check shows it).
  Future<void> load({bool refresh = false}) async {
    final result = await _repository.meta(refresh: refresh);
    if (isClosed) return;
    switch (result) {
      case Right(value: final meta):
        if (meta.datasetVersion == null) {
          emit(CoverageState(status: CoverageStatus.unavailable, meta: meta, failure: const CoverageUnavailableFailure()));
        } else {
          emit(
            CoverageState(
              status: state.status == CoverageStatus.unavailable ? CoverageStatus.idle : state.status,
              point: state.point,
              check: state.check,
              meta: meta,
              failure: state.status == CoverageStatus.unavailable ? null : state.failure,
              retryAt: state.retryAt,
            ),
          );
        }
      case Left(value: final failure):
        if (failure is CoverageUnavailableFailure && state.status == CoverageStatus.idle) {
          emit(CoverageState(status: CoverageStatus.unavailable, failure: failure));
        }
    }
  }

  /// Reads the meta again (the consent text changed, or the dataset moved on) and keeps the screen as it is.
  Future<void> refreshMeta() async {
    final result = await _repository.meta(refresh: true);
    if (isClosed) return;
    result.match(
      (_) {},
      (meta) => emit(CoverageState(status: state.status, point: state.point, check: state.check, meta: meta, failure: state.failure, retryAt: state.retryAt)),
    );
  }

  /// Checks [lat], [lon] now (a picked address or the phone's location).
  Future<void> checkAt(double lat, double lon) async {
    final generation = _begin(lat, lon);
    if (generation == null) return;
    await _run(generation, GeoPoint(lat, lon));
  }

  /// A map tap: the pin moves at once, the request waits for the taps to settle.
  void pinDropped(double lat, double lon) {
    final generation = _begin(lat, lon);
    if (generation == null) return;
    final point = GeoPoint(lat, lon);
    _timer = Timer(debounce, () {
      if (!isClosed && generation == _generation) _run(generation, point);
    });
  }

  /// Asks again for the last point (after an error or a rate limit that has run out), or
  /// reads the meta again when no point was chosen.
  Future<void> retry() async {
    final until = state.retryAt;
    if (state.status == CoverageStatus.rateLimited && until != null && _now().isBefore(until)) return;
    final point = state.point;
    if (point != null) return checkAt(point.lat, point.lon);
    return load(refresh: true);
  }

  void reset() {
    _timer?.cancel();
    _generation++;
    emit(CoverageState(meta: state.meta));
  }

  /// Starts a generation for the point; null when the point is outside the service area
  /// (explained at once, no request).
  int? _begin(double lat, double lon) {
    if (isClosed) return null;
    _timer?.cancel();
    final generation = ++_generation;
    final point = GeoPoint(lat, lon);
    final bounds = state.meta?.bounds;
    if (!lat.isFinite || !lon.isFinite || (bounds != null && !bounds.contains(lat: lat, lon: lon))) {
      emit(CoverageState(status: CoverageStatus.outside, point: point, meta: state.meta));
      return null;
    }
    final until = _blockedUntil;
    if (until != null && _now().isBefore(until)) {
      // Held: the pin stays where the customer put it and nothing is sent before the wait is over.
      emit(
        CoverageState(
          status: CoverageStatus.rateLimited,
          point: point,
          meta: state.meta,
          failure: const RateLimitedFailure(),
          retryAt: until,
        ),
      );
      return null;
    }
    emit(CoverageState(status: CoverageStatus.loading, point: point, meta: state.meta));
    return generation;
  }

  Future<void> _run(int generation, GeoPoint point) async {
    final result = await _repository.check(lat: point.lat, lon: point.lon);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Right(value: final check):
        // `dataset_version` null with nothing found means no dataset is active: that is
        // "not available", not "no coverage here".
        if (check.datasetVersion == null && check.options.isEmpty) {
          emit(
            CoverageState(
              status: CoverageStatus.unavailable,
              point: point,
              meta: state.meta,
              failure: const CoverageUnavailableFailure(),
            ),
          );
          return;
        }
        emit(CoverageState(status: CoverageStatus.ready, point: point, check: check, meta: state.meta));
        if (state.meta?.datasetVersion != check.datasetVersion) unawaited(_refreshMeta(generation));
      case Left(value: final failure):
        emit(_failed(failure, point));
    }
  }

  CoverageState _failed(Failure failure, GeoPoint point) => switch (failure) {
    CoverageUnavailableFailure() => CoverageState(status: CoverageStatus.unavailable, point: point, meta: state.meta, failure: failure),
    RateLimitedFailure(:final retryAfter) => _limited(failure, point, retryAfter),
    OutsideServiceAreaFailure() => CoverageState(status: CoverageStatus.outside, point: point, meta: state.meta, failure: failure),
    _ => CoverageState(status: CoverageStatus.error, point: point, meta: state.meta, failure: failure),
  };

  CoverageState _limited(Failure failure, GeoPoint point, Duration? retryAfter) {
    final until = _now().add(retryAfter == null || retryAfter <= Duration.zero ? defaultRetryAfter : retryAfter);
    _blockedUntil = until;
    return CoverageState(status: CoverageStatus.rateLimited, point: point, meta: state.meta, failure: failure, retryAt: until);
  }

  /// The answer came from another dataset version than the meta read earlier: read it again
  /// (consent versions and attribution may have changed with it).
  Future<void> _refreshMeta(int generation) async {
    final result = await _repository.meta(refresh: true);
    if (isClosed || generation != _generation) return;
    result.match((_) {}, (meta) => emit(CoverageState(status: state.status, point: state.point, check: state.check, meta: meta)));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
