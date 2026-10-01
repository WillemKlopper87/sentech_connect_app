import 'package:equatable/equatable.dart';

/// Declaration order is the Shop tab order: hotspot passes lead; the physical
/// (Home 5G / MiFi) products sit in the later tabs.
enum ProductCategory { hotspotPass, voucher, home5g, mifi }

extension ProductCategoryLabel on ProductCategory {
  String get label => switch (this) {
    ProductCategory.home5g => 'Home 5G',
    ProductCategory.mifi => 'MiFi',
    ProductCategory.voucher => 'Vouchers',
    ProductCategory.hotspotPass => 'Wi-Fi passes',
  };
}

class Plan extends Equatable {
  const Plan({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.dataDescription,
    required this.speedMbps,
    required this.category,
    this.isFeatured = false,
  });

  final String id;
  final String name;

  /// Price in integer cents (ZAR). The server is the authority for prices.
  final int priceCents;
  final String dataDescription;
  final int speedMbps;
  final ProductCategory category;
  final bool isFeatured;

  @override
  List<Object?> get props => [
    id,
    name,
    priceCents,
    dataDescription,
    speedMbps,
    category,
    isFeatured,
  ];
}
