import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoices_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/invoice_presentation.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// The customer's invoices: unpaid first, then earlier ones, each newest first
/// as the API orders them.
class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key, required this.onOpenInvoice});

  final void Function(SubscriberInvoice invoice) onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicesTitle)),
      body: BlocConsumer<InvoicesCubit, InvoicesState>(
        listenWhen: (previous, current) => current.status == InvoicesStatus.loaded && current.failure != null,
        listener: (context, state) {
          // A refresh failed: the list stays, the reason shows once.
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(_failureText(context, state.failure!))));
        },
        builder: (context, state) {
          final cubit = context.read<InvoicesCubit>();
          switch (state.status) {
            case InvoicesStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case InvoicesStatus.failed:
              return FailureView(failure: state.failure, onRetry: cubit.load);
            case InvoicesStatus.loaded:
              break;
          }
          if (state.invoices.isEmpty) {
            return RefreshIndicator(
              onRefresh: cubit.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(l10n.invoicesEmptyTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(l10n.invoicesEmptyBody, textAlign: TextAlign.center),
                ],
              ),
            );
          }
          final open = state.open;
          final earlier = state.earlier;
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (open.isNotEmpty) ...[
                  _Heading(l10n.invoicesOpenSection),
                  for (final invoice in open) _InvoiceCard(invoice: invoice, onTap: () => onOpenInvoice(invoice)),
                ],
                if (earlier.isNotEmpty) ...[
                  if (open.isNotEmpty) const SizedBox(height: 12),
                  _Heading(l10n.invoicesEarlierSection),
                  for (final invoice in earlier) _InvoiceCard(invoice: invoice, onTap: () => onOpenInvoice(invoice)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _failureText(BuildContext context, Failure failure) {
  final l10n = context.l10n;
  if (failure is NetworkFailure) return l10n.failureYouReOfflineCheckYourConnection;
  return typedFailureText(l10n, failure) ?? localizedFailureText(l10n, failure.message);
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 0.6)),
  );
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});

  final SubscriberInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dateLine = invoice.isOpen
        ? l10n.invoiceDueOn(formatInvoiceDate(context, invoice.dueDate))
        : l10n.invoiceIssuedOn(formatInvoiceDate(context, invoice.issueDate));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('invoice-${invoice.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoiceKindLabel(l10n, invoice.kind), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        invoice.invoiceNo,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(dateLine, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatRands(invoice.amountCents), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    InvoiceStatusChip(status: invoice.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
