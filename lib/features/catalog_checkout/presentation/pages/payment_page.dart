import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Step 3 of checkout: pay an order whose identity check has passed. Reached
/// from RICA success, or later from the dashboard "finish your order" banner
/// — a failed payment leaves the order intact so the customer can retry.
class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key, required this.onPaid, required this.onNeedsVerification});

  final void Function(Order order) onPaid;
  final void Function(Order order) onNeedsVerification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          final order = state.order;
          if (order == null) return;
          if (state.status == PaymentStatus.paid) onPaid(order);
          if (state.status == PaymentStatus.needsVerification) onNeedsVerification(order);
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          if (state.status == PaymentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == PaymentStatus.loadFailed) {
            return FailureView(failure: state.failure, onRetry: () => context.read<PaymentCubit>().load());
          }
          final order = state.order;
          if (order == null) return const SizedBox.shrink();
          final paying = state.status == PaymentStatus.paying;
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrderCard(order: order),
                        const SizedBox(height: 22),
                        Text('PAYMENT METHOD', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
                        const SizedBox(height: 10),
                        for (final method in PaymentMethod.values) ...[
                          _PayTile(
                            method: method,
                            selected: state.method == method,
                            onTap: () => context.read<PaymentCubit>().selectMethod(method),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (state.status == PaymentStatus.payFailed) ...[
                          const SizedBox(height: 8),
                          FailureView(failure: state.failure, compact: true, onRetry: () => context.read<PaymentCubit>().pay()),
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
                        onPressed: paying ? null : () => context.read<PaymentCubit>().pay(),
                        child: paying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Pay R${order.totalRands.toStringAsFixed(2)} securely'),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.verified, size: 18, color: const Color(0xFF6F9126)),
              const SizedBox(width: 8),
              Expanded(child: Text('Identity verified', style: theme.textTheme.bodyMedium)),
              Text('#${order.orderNumber}', style: theme.textTheme.bodyMedium),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(order.planName, style: theme.textTheme.titleMedium)),
              Text('R${order.totalRands.toStringAsFixed(2)}', style: theme.textTheme.titleMedium),
            ],
          ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: method.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
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
      ),
    );
  }
}
