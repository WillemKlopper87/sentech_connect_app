import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

/// RICA (identity and face check) applies to products that come with a SIM
/// (Home 5G routers and MiFi devices). WiFi hotspot passes and WiFi vouchers
/// are sign-in-page access with no SIM, so they never need it.
///
/// The platform API exposes no product type or `requires_rica` field (its
/// catalogue is hotspot passes only), so the rule is derived from the
/// product kind the app already knows ([ProductCategory]).
extension ProductCategoryRica on ProductCategory {
  bool get requiresRica => switch (this) {
    ProductCategory.home5g || ProductCategory.mifi => true,
    ProductCategory.hotspotPass || ProductCategory.voucher => false,
  };
}

/// True when this order must pass the identity check before payment: the
/// tenant has RICA switched on AND the order contains a product that needs
/// it. The tenant flag alone never sends a WiFi pass buyer to the face check.
bool requiresIdentityCheck({
  required bool ricaFlag,
  required Iterable<CartItem> items,
}) => ricaFlag && items.any((i) => i.plan.category.requiresRica);
