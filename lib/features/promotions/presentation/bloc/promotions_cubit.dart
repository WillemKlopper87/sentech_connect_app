import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';

import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';

/// Expiry is exclusive: an offer expiring exactly now still shows.
List<Promotion> visiblePromotions(
  List<Promotion> all, {
  required DateTime now,
  required Set<ProductCategory> sold,
}) => all
    .where(
      (p) =>
          (p.expiresAt == null || !p.expiresAt!.isBefore(now)) &&
          (p.appliesTo == null || sold.contains(p.appliesTo)),
    )
    .toList();

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
  PromotionsCubit(
    this._repository, {
    DateTime Function()? now,
    this.catalog,
    this.showPoints = false,
  }) : _now = now ?? DateTime.now,
       super(const PromotionsState()) {
    _load();
  }

  final PromotionsRepository _repository;
  final DateTime Function() _now;
  final CatalogRepository? catalog;
  final bool showPoints;

  Future<void> _load() async {
    final promosResult = await _repository.getActivePromotions();
    final catalogResult = await catalog?.getProducts();
    // A failed/missing catalogue is unknown inventory, never an empty set.
    final sold = catalogResult?.match<Set<ProductCategory>?>(
      (_) => null,
      (products) => products.map((p) => p.category).toSet(),
    );
    final now = _now();
    final promos = promosResult.getOrElse((_) => const []);
    final visible = sold == null
        ? promos
              .where((p) => p.expiresAt == null || !p.expiresAt!.isBefore(now))
              .toList()
        : visiblePromotions(promos, now: now, sold: sold);
    final points = showPoints
        ? (await _repository.getLoyaltyPoints()).getOrElse((_) => 0)
        : 0;
    if (isClosed) return;
    emit(
      state.copyWith(
        status: promosResult.isLeft()
            ? PromotionsStatus.failure
            : PromotionsStatus.loaded,
        promotions: visible,
        loyaltyPoints: points,
      ),
    );
  }
}
