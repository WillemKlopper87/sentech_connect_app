import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';

enum CatalogStatus { initial, loading, loaded, failure }

class CatalogState extends Equatable {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.allProducts = const [],
    this.selectedCategory = ProductCategory.home5g,
    this.failure,
  });

  final CatalogStatus status;
  final List<Plan> allProducts;
  final ProductCategory selectedCategory;
  final Failure? failure;

  List<Plan> get visibleProducts =>
      allProducts.where((p) => p.category == selectedCategory).toList();

  CatalogState copyWith({
    CatalogStatus? status,
    List<Plan>? allProducts,
    ProductCategory? selectedCategory,
    Failure? failure,
  }) {
    return CatalogState(
      status: status ?? this.status,
      allProducts: allProducts ?? this.allProducts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, allProducts, selectedCategory, failure];
}

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogState()) {
    load();
  }

  final CatalogRepository _repository;

  /// Also the retry entry point after a failed load.
  Future<void> load() async {
    emit(state.copyWith(status: CatalogStatus.loading));
    final result = await _repository.getProducts();
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: CatalogStatus.failure, failure: failure)),
      (products) => emit(state.copyWith(status: CatalogStatus.loaded, allProducts: products)),
    );
  }

  void selectCategory(ProductCategory category) => emit(state.copyWith(selectedCategory: category));
}
