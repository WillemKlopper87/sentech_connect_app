import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';

enum ListStatus { loading, ready, unavailable, error }

class MissionsState extends Equatable {
  const MissionsState({this.status = ListStatus.loading, this.missions = const [], this.failure});

  final ListStatus status;
  final List<Mission> missions;
  final Failure? failure;

  @override
  List<Object?> get props => [status, missions, failure];
}

/// Missions as the server evaluated them. Progress is never computed here.
class MissionsCubit extends Cubit<MissionsState> {
  MissionsCubit(this._repository) : super(const MissionsState()) {
    load();
  }

  final CreditsRepository _repository;
  int _generation = 0;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    if (!keepVisible || state.status != ListStatus.ready) emit(const MissionsState());
    final result = await _repository.missions();
    if (isClosed || generation != _generation) return;
    result.match((failure) {
      if (failure is CreditsNotAvailableFailure) {
        emit(MissionsState(status: ListStatus.unavailable, failure: failure));
      } else if (!(keepVisible && state.status == ListStatus.ready)) {
        emit(MissionsState(status: ListStatus.error, failure: failure));
      }
    }, (missions) => emit(MissionsState(status: ListStatus.ready, missions: missions)));
  }

  Future<void> refresh() => load(keepVisible: true);
}

class BadgesState extends Equatable {
  const BadgesState({this.status = ListStatus.loading, this.badges = const [], this.failure});

  final ListStatus status;
  final List<CreditBadge> badges;
  final Failure? failure;

  @override
  List<Object?> get props => [status, badges, failure];
}

/// Badges as the server awarded them.
class BadgesCubit extends Cubit<BadgesState> {
  BadgesCubit(this._repository) : super(const BadgesState()) {
    load();
  }

  final CreditsRepository _repository;
  int _generation = 0;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    if (!keepVisible || state.status != ListStatus.ready) emit(const BadgesState());
    final Either<Failure, List<CreditBadge>> result = await _repository.badges();
    if (isClosed || generation != _generation) return;
    result.match((failure) {
      if (failure is CreditsNotAvailableFailure) {
        emit(BadgesState(status: ListStatus.unavailable, failure: failure));
      } else if (!(keepVisible && state.status == ListStatus.ready)) {
        emit(BadgesState(status: ListStatus.error, failure: failure));
      }
    }, (badges) => emit(BadgesState(status: ListStatus.ready, badges: badges)));
  }

  Future<void> refresh() => load(keepVisible: true);
}
