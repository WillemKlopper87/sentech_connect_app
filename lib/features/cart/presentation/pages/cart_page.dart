import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/widgets/buy_now_sheet.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key, required this.onCheckout, this.buyInApp = true});

  final VoidCallback onCheckout;

  /// False when the provider collects its own money: the cart still lists
  /// what was chosen, but there is no checkout.
  final bool buyInApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.cartYourCart)),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return Center(
              child: Text(
                context.l10n.cartYourCartIsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = state.items[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.plan.name,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  context.l10n.cartPriceEach(
                                    context.l10n.priceInclVat(
                                      formatRands(item.plan.priceCents),
                                    ),
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _QtyStepper(
                            quantity: item.quantity,
                            onChanged: (q) => context
                                .read<CartCubit>()
                                .setQuantity(item.plan.id, q),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            context.l10n.cartTotal,
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            context.l10n.priceInclVat(
                              formatRands(state.totalCents),
                            ),
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (buyInApp)
                        ElevatedButton(
                          onPressed: onCheckout,
                          child: Text(context.l10n.cartCheckout),
                        )
                      else
                        BuyFromProviderNotice(
                          provider: providerContactOf(context),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Default IconButton size keeps the 48dp touch target (no compact density).
        IconButton(
          tooltip: context.l10n.a11yDecreaseQuantity,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => onChanged(quantity - 1),
        ),
        Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          tooltip: context.l10n.a11yIncreaseQuantity,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
