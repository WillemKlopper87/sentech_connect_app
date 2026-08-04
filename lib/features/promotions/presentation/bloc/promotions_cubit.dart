import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';

enum PromotionsStatus { loading, loaded, failure }

class PromotionsState extends Equatable {
  const PromotionsState({
    this.status = PromotionsStatus.loading,
    this.promotions = const [],
    this.loyaltyPoints = 0,
  });

  final PromotionsStatus status;
  final List<Promotion> promotions;
  final int loyaltyPoints;

  PromotionsState copyWith({
    PromotionsStatus? status,
    List<Promotion>? promotions,
    int? loyaltyPoints,
  }) {
    return PromotionsState(
      status: status ?? this.status,
      promotions: promotions ?? this.promotions,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
    );
  }

  @override
  List<Object?> get props => [status, promotions, loyaltyPoints];
}

class PromotionsCubit extends Cubit<PromotionsState> {
  PromotionsCubit(this._repository) : super(const PromotionsState()) {
    _load();
  }

  final PromotionsRepository _repository;

  Future<void> _load() async {
    final promosResult = await _repository.getActivePromotions();
    final pointsResult = await _repository.getLoyaltyPoints();
    final promos = promosResult.getOrElse((_) => const []);
    final points = pointsResult.getOrElse((_) => 0);
    emit(state.copyWith(status: PromotionsStatus.loaded, promotions: promos, loyaltyPoints: points));
  }
}
