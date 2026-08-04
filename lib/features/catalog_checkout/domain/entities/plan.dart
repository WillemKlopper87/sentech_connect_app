import 'package:equatable/equatable.dart';

enum ProductCategory { home5g, mifi, voucher }

extension ProductCategoryLabel on ProductCategory {
  String get label => switch (this) {
        ProductCategory.home5g => 'Home 5G',
        ProductCategory.mifi => 'MiFi',
        ProductCategory.voucher => 'Vouchers',
      };
}

class Plan extends Equatable {
  const Plan({
    required this.id,
    required this.name,
    required this.priceRands,
    required this.dataDescription,
    required this.speedMbps,
    required this.category,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final double priceRands;
  final String dataDescription;
  final int speedMbps;
  final ProductCategory category;
  final bool isFeatured;

  @override
  List<Object?> get props =>
      [id, name, priceRands, dataDescription, speedMbps, category, isFeatured];
}

enum PaymentMethod { card, ozow, payshap }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.card => 'Card',
        PaymentMethod.ozow => 'Instant EFT · Ozow',
        PaymentMethod.payshap => 'PayShap',
      };
}
