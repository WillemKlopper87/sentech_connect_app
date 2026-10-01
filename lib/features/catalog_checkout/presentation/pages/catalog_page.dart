import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/bloc/free_wifi_cubit.dart';
import 'package:sentech_connect_app/features/wifi_voucher/presentation/pages/free_wifi_card.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key, required this.onOpenCart, required this.onFindHotspots});

  final VoidCallback onOpenCart;
  final VoidCallback onFindHotspots;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FreeWifiCubit(locator()),
      child: _CatalogScaffold(onOpenCart: onOpenCart, onFindHotspots: onFindHotspots),
    );
  }
}

class _CatalogScaffold extends StatelessWidget {
  const _CatalogScaffold({required this.onOpenCart, required this.onFindHotspots});

  final VoidCallback onOpenCart;
  final VoidCallback onFindHotspots;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
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
                          decoration: const BoxDecoration(color: Color(0xFFED1C24), shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${cartState.itemCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
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
          if (state.status == CatalogStatus.loading || state.status == CatalogStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CatalogStatus.failure) {
            return FailureView(failure: state.failure, onRetry: () => context.read<CatalogCubit>().load());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _SegmentedRow(
                selected: state.selectedCategory,
                onSelect: (c) => context.read<CatalogCubit>().selectCategory(c),
              ),
              const SizedBox(height: 16),
              if (state.selectedCategory == ProductCategory.voucher) ...[
                FreeWifiCard(onFindHotspots: onFindHotspots),
                const SizedBox(height: 16),
              ],
              for (final plan in state.visibleProducts) ...[
                _PlanCard(
                  plan: plan,
                  onSelect: () {
                    context.read<CartCubit>().addItem(plan);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text('${plan.name} added to cart'), duration: const Duration(seconds: 3)),
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
  const _SegmentedRow({required this.selected, required this.onSelect});

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
                boxShadow: active ? [const BoxShadow(blurRadius: 4, color: Colors.black12)] : null,
              ),
              child: Text(
                category.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
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
      child: Row(children: ProductCategory.values.map(seg).toList()),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isFeatured ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: plan.isFeatured ? 1.6 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (plan.isFeatured)
            Positioned(
              top: -22,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFAA61A), borderRadius: BorderRadius.circular(999)),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF3A2400)),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(plan.name, style: theme.textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.titleMedium,
                      children: [
                        TextSpan(text: formatRands(plan.priceCents, wholeRands: true)),
                        TextSpan(
                          text: plan.category == ProductCategory.voucher ? '' : '/mo',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${plan.dataDescription} · up to ${plan.speedMbps} Mbps',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              plan.isFeatured
                  ? ElevatedButton(onPressed: onSelect, child: const Text('Add to cart'))
                  : OutlinedButton(onPressed: onSelect, child: const Text('Add to cart')),
            ],
          ),
        ],
      ),
    );
  }
}
