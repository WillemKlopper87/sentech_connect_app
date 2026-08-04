import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.onPaid});

  final void Function(Order order) onPaid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: BlocConsumer<CheckoutCubit, CheckoutState>(
        listener: (context, state) {
          if (state.status == CheckoutStatus.paid && state.order != null) {
            onPaid(state.order!);
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          final paying = state.status == CheckoutStatus.paying;
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
                        const SizedBox(height: 22),
                        Text('PAYMENT METHOD', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                        const SizedBox(height: 10),
                        for (final method in PaymentMethod.values) ...[
                          _PayTile(
                            method: method,
                            selected: state.method == method,
                            onTap: () => context.read<CheckoutCubit>().selectMethod(method),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Payments are tokenised and PCI-compliant — Sentech never stores your card details.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: paying ? null : () => context.read<CheckoutCubit>().pay(),
                        child: paying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Pay R${state.total.toStringAsFixed(2)} securely'),
                      ),
                    ],
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
          row('Due today', 'R${total.toStringAsFixed(2)}', total: true),
        ],
      ),
    );
  }
}

class _PayTile extends StatelessWidget {
  const _PayTile({required this.method, required this.selected, required this.onTap});

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (method) {
        PaymentMethod.card => Icons.credit_card,
        PaymentMethod.ozow => Icons.account_balance_outlined,
        PaymentMethod.payshap => Icons.qr_code_2,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Icon(_icon, size: 19, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(method.label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700))),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: 1.5),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
