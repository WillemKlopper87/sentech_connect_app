import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Step 1 of checkout: review, then verify identity. The customer is only
/// charged after RICA succeeds (see `PaymentPage`), so this screen creates
/// the order and hands off to verification rather than taking payment.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.onOrderCreated});

  final void Function(Order order) onOrderCreated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: BlocConsumer<CheckoutCubit, CheckoutState>(
        listener: (context, state) {
          if (state.status == CheckoutStatus.created && state.order != null) {
            onOrderCreated(state.order!);
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          final creating = state.status == CheckoutStatus.creating;
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(items: state.items, total: state.total),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Next we verify your identity (required by RICA). You are only charged after that succeeds.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.status == CheckoutStatus.failure) ...[
                          const SizedBox(height: 18),
                          FailureView(
                            failure: state.failure,
                            compact: true,
                            onRetry: () => context.read<CheckoutCubit>().createOrder(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: (creating || state.items.isEmpty) ? null : () => context.read<CheckoutCubit>().createOrder(),
                    child: creating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify identity to continue'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.items, required this.total});

  final List<CartItem> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool total = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: total ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium),
              ),
              Text(value, style: total ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final item in items)
            row(
              item.quantity > 1 ? '${item.plan.name} × ${item.quantity}' : item.plan.name,
              'R${item.lineTotal.toStringAsFixed(2)}',
            ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
          row('Due after verification', 'R${total.toStringAsFixed(2)}', total: true),
        ],
      ),
    );
  }
}
