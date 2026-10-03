import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Step 1 of checkout: review, then verify identity. The customer is only
/// charged after RICA succeeds (see `PaymentPage`), so this screen creates
/// the order and hands off to verification rather than taking payment.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({
    super.key,
    required this.onOrderCreated,
    this.requiresIdentityCheck = true,
  });

  final bool requiresIdentityCheck;

  final void Function(Order order) onOrderCreated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkoutCheckout)),
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
                        _SummaryCard(
                          items: state.items,
                          totalCents: state.totalCents,
                          dueLabel: requiresIdentityCheck
                              ? context.l10n.checkoutToPay
                              : context.l10n.checkoutTotalDue,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  requiresIdentityCheck
                                      ? context.l10n.checkoutIdentityNotice
                                      : context.l10n.checkoutPaymentNotice,
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
                            onRetry: () =>
                                context.read<CheckoutCubit>().createOrder(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: (creating || state.items.isEmpty)
                        ? null
                        : () => context.read<CheckoutCubit>().createOrder(),
                    child: creating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            requiresIdentityCheck
                                ? context.l10n.checkoutVerifyIdentityToContinue
                                : context.l10n.checkoutContinueToPayment,
                          ),
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
  const _SummaryCard({
    required this.items,
    required this.totalCents,
    required this.dueLabel,
  });

  final String dueLabel;

  final List<CartItem> items;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool total = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: total
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: total
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ),
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
              item.quantity > 1
                  ? '${item.plan.name} × ${item.quantity}'
                  : item.plan.name,
              context.l10n.priceInclVat(formatRands(item.lineTotalCents)),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          row(
            dueLabel,
            context.l10n.priceInclVat(formatRands(totalCents)),
            total: true,
          ),
        ],
      ),
    );
  }
}
