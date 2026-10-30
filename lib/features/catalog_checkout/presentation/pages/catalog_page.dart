import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/buy_now_sheet.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/monthly_plans_card.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/free_wifi_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/free_wifi_card.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({
    super.key,
    required this.onOpenCart,
    this.onFindHotspots,
    this.showFreeWifi = true,
    required this.onOrderCreated,
  });

  final VoidCallback onOpenCart;
  final void Function(Order) onOrderCreated;

  /// Opens the hotspot map (real). Null hides the entry.
  final VoidCallback? onFindHotspots;

  /// The rewarded-ad free Wi-Fi card (mock-backed; see `mock_feature_guard.dart`).
  /// When false the plain "Find hotspots" entry is shown instead.
  final bool showFreeWifi;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FreeWifiCubit(locator()),
      child: _CatalogScaffold(
        onOpenCart: onOpenCart,
        onFindHotspots: onFindHotspots,
        showFreeWifi: showFreeWifi,
        onOrderCreated: onOrderCreated,
      ),
    );
  }
}

class _CatalogScaffold extends StatelessWidget {
  const _CatalogScaffold({
    required this.onOpenCart,
    this.onFindHotspots,
    this.showFreeWifi = true,
    required this.onOrderCreated,
  });

  final VoidCallback onOpenCart;
  final void Function(Order) onOrderCreated;

  /// Opens the hotspot map (real). Null hides the entry.
  final VoidCallback? onFindHotspots;

  /// The rewarded-ad free Wi-Fi card (mock-backed; see `mock_feature_guard.dart`).
  /// When false the plain "Find hotspots" entry is shown instead.
  final bool showFreeWifi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.shopTitle),
        actions: [
          BlocBuilder<CartCubit, CartState>(
            builder: (context, cartState) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: context.l10n.a11yCart,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      onPressed: onOpenCart,
                    ),
                    if (cartState.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${cartState.itemCount}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, state) {
          if (state.status == CatalogStatus.loading ||
              state.status == CatalogStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CatalogStatus.failure) {
            return FailureView(
              failure: state.failure,
              onRetry: () => context.read<CatalogCubit>().load(),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const MonthlyPlansCard(),
              if (state.availableCategories.length > 1)
                _SegmentedRow(
                  categories: state.availableCategories,
                  selected: state.selectedCategory,
                  onSelect: (c) =>
                      context.read<CatalogCubit>().selectCategory(c),
                ),
              const SizedBox(height: 16),
              if (onFindHotspots != null &&
                  (state.selectedCategory == ProductCategory.voucher ||
                      (!showFreeWifi &&
                          state.selectedCategory ==
                              ProductCategory.hotspotPass))) ...[
                if (showFreeWifi)
                  FreeWifiCard(onFindHotspots: onFindHotspots!)
                else
                  OutlinedButton.icon(
                    key: const ValueKey('find-hotspots'),
                    onPressed: onFindHotspots,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(context.l10n.freeWifiFindHotspotsNearMe),
                  ),
                const SizedBox(height: 16),
              ],
              for (final plan in state.visibleProducts) ...[
                _PlanCard(
                  plan: plan,
                  onSelect: () {
                    if (plan.category == ProductCategory.hotspotPass ||
                        plan.category == ProductCategory.voucher) {
                      showBuyNowSheet(
                        context,
                        plan,
                        onOrderCreated: onOrderCreated,
                        buyInApp:
                            context
                                .read<TenantCubit?>()
                                ?.state
                                .config
                                ?.buyInApp ??
                            true,
                        showDemoMethods: locator<AppEnvironment>().isDemo,
                        showCashVoucher:
                            locator<AppEnvironment>().isDemo &&
                            state.availableCategories.contains(
                              ProductCategory.voucher,
                            ),
                      );
                      return;
                    }
                    context.read<CartCubit>().addItem(plan);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.shopAddedToCart(plan.name),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                  },
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<ProductCategory> categories;

  final ProductCategory selected;
  final void Function(ProductCategory) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget seg(ProductCategory category) {
      final active = category == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: InkWell(
            onTap: () => onSelect(category),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              // 48dp minimum touch target.
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.surface : null,
                borderRadius: BorderRadius.circular(9),
                boxShadow: active
                    ? [const BoxShadow(blurRadius: 4, color: Colors.black12)]
                    : null,
              ),
              child: Text(
                switch (category) {
                  ProductCategory.home5g => context.l10n.productCategoryHome5g,
                  ProductCategory.mifi => context.l10n.productCategoryMifi,
                  ProductCategory.voucher =>
                    context.l10n.productCategoryVoucher,
                  ProductCategory.hotspotPass =>
                    context.l10n.productCategoryHotspotPass,
                },
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: categories.map(seg).toList()),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onSelect});

  final Plan plan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: plan.isFeatured
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: plan.isFeatured ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (plan.isFeatured) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAA61A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Semantics(
                    label: context.l10n.planBadgeOurPickHint,
                    child: Text(
                      context.l10n.planBadgeOurPick,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF003A70),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (MediaQuery.textScalerOf(context).scale(16) > 24) ...[
              Text(plan.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _price(context),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(plan.name, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _price(context)),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              plan.speedMbps > 0
                  ? context.l10n.shopPlanSpeed(
                      plan.dataDescription,
                      plan.speedMbps.toString(),
                    )
                  : plan.dataDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            plan.isFeatured
                ? ElevatedButton(
                    onPressed: onSelect,
                    child: Text(_actionLabel(context)),
                  )
                : OutlinedButton(
                    onPressed: onSelect,
                    child: Text(_actionLabel(context)),
                  ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(BuildContext context) =>
      plan.category == ProductCategory.hotspotPass ||
          plan.category == ProductCategory.voucher
      ? context.l10n.buyNow
      : context.l10n.shopAddToCart;

  Widget _price(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: theme.textTheme.titleMedium,
        children: [
          TextSpan(
            text: context.l10n.priceInclVat(
              formatRands(plan.priceCents, wholeRands: true),
            ),
          ),
          if (plan.category == ProductCategory.home5g ||
              plan.category == ProductCategory.mifi)
            TextSpan(
              text: context.l10n.pricePerMonth,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
