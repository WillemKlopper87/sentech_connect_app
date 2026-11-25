import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

/// [off]: the platform's address step is not available here (the field is disabled; the location button and the map still work).
enum AddressSearchStatus { idle, searching, results, none, unavailable, rateLimited, error, off }

/// The state never holds the typed text: only the platform's matches (personal
/// data, in memory, printed redacted) and how the search went.
class AddressSearchState extends Equatable {
  const AddressSearchState({this.status = AddressSearchStatus.idle, this.matches = const [], this.matched, this.failure, this.retryAt});

  final AddressSearchStatus status;
  final List<GeocodeMatch> matches;

  /// The step of the platform's ladder that matched (`street` or `area` mean the house number was not found).
  final MatchPrecision? matched;
  final Failure? failure;
  final DateTime? retryAt;

  @override
  List<Object?> get props => [status, matches, matched, failure, retryAt];

  @override
  String toString() => 'AddressSearchState(${status.name}, ${matches.length} matches)';
}

/// Searches the platform for an address as the customer types. Debounced, so one
/// request leaves per settled query; fewer than three characters ask nothing; an
/// older response never replaces a newer one. The address goes to the customer's
/// own provider only (the phone's geocoder is not used).
class AddressSearchCubit extends Cubit<AddressSearchState> {
  AddressSearchCubit(this._repository, {this.debounce = const Duration(milliseconds: 450), DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const AddressSearchState());

  final CoverageRepository _repository;
  final Duration debounce;
  final DateTime Function() _now;

  static const minLength = 3;
  static const maxLength = 200;
  static const defaultRetryAfter = Duration(seconds: 30);

  int _generation = 0;
  Timer? _timer;
  String? _lastQuery;

  /// Asks the platform whether the address step is on. A network failure is "unknown", not "off".
  Future<void> load() async {
    final result = await _repository.addressLookupAvailable();
    if (isClosed) return;
    result.match((_) {}, (available) {
      if (!available) {
        _timer?.cancel();
        _generation++;
        emit(const AddressSearchState(status: AddressSearchStatus.off));
      } else if (state.status == AddressSearchStatus.off) {
        emit(const AddressSearchState());
      }
    });
  }

  void queryChanged(String raw) {
    if (isClosed || state.status == AddressSearchStatus.off) return;
    final query = _tidy(raw);
    _timer?.cancel();
    if (query.runes.length < minLength) {
      _generation++;
      _lastQuery = null;
      if (state.status != AddressSearchStatus.idle || state.matches.isNotEmpty) emit(const AddressSearchState());
      return;
    }
    if (query == _lastQuery) return;
    final generation = ++_generation;
    _timer = Timer(debounce, () => _search(generation, query));
  }

  /// Forgets the list and any pending search (a place was picked, or the field was emptied).
  void clear() {
    _timer?.cancel();
    _generation++;
    _lastQuery = null;
    if (!isClosed && (state.status != AddressSearchStatus.idle || state.matches.isNotEmpty)) emit(const AddressSearchState());
  }

  /// Spaces collapsed, at most [maxLength] characters (the server refuses more).
  static String _tidy(String raw) {
    final collapsed = raw.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');
    final runes = collapsed.runes.toList();
    return runes.length <= maxLength ? collapsed : String.fromCharCodes(runes.take(maxLength));
  }

  Future<void> _search(int generation, String query) async {
    if (isClosed || generation != _generation) return;
    _lastQuery = query;
    emit(AddressSearchState(status: AddressSearchStatus.searching, matches: state.matches));
    final result = await _repository.search(query);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Right(value: final found):
        emit(
          found.matches.isEmpty
              ? const AddressSearchState(status: AddressSearchStatus.none)
              : AddressSearchState(status: AddressSearchStatus.results, matches: found.matches, matched: found.matched),
        );
      case Left(value: final failure):
        // A failed query is asked again on the next keystroke or after a retry.
        _lastQuery = null;
        emit(switch (failure) {
          AddressSearchUnavailableFailure() => AddressSearchState(status: AddressSearchStatus.unavailable, failure: failure),
          RateLimitedFailure(:final retryAfter) => AddressSearchState(
            status: AddressSearchStatus.rateLimited,
            failure: failure,
            retryAt: _now().add(retryAfter == null || retryAfter <= Duration.zero ? defaultRetryAfter : retryAfter),
          ),
          _ => AddressSearchState(status: AddressSearchStatus.error, failure: failure),
        });
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
